import { Injectable, Logger, ServiceUnavailableException } from "@nestjs/common";

/// 잠시 뒤 다시 시도하면 풀릴 수 있는 상류 오류.
class TransientUpstreamError extends Error {}

/**
 * Gemini 호출부.
 *
 * SDK 대신 REST를 직접 부른다. 의존성이 하나 줄고, 모델·엔드포인트 교체가
 * 이 파일 안에서 끝난다. 다른 AI 제공자로 바꿀 때도 이 클래스만 갈아끼우면 된다.
 */
@Injectable()
export class GeminiClient {
  private readonly logger = new Logger(GeminiClient.name);

  private get apiKey(): string | undefined {
    return process.env.GEMINI_API_KEY;
  }

  private get model(): string {
    // 2026-08 기준: gemini-2.0/2.5-flash는 퇴역(404), 별칭 gemini-flash-latest는
    // 과부하로 503이 잦다. 실제로 응답하는 모델을 기본으로 둔다.
    // 모델이 또 바뀌면 .env의 GEMINI_MODEL로 덮어쓴다.
    return process.env.GEMINI_MODEL ?? "gemini-3.6-flash";
  }

  get isConfigured(): boolean {
    return Boolean(this.apiKey);
  }

  /**
   * 모델이 몰릴 때 구글은 503(UNAVAILABLE)이나 429(할당량)를 돌려준다.
   * 대개 몇 초 뒤면 풀리므로, 한 번 실패했다고 바로 폴백으로 떨어뜨리지 않고
   * 간격을 늘려가며 몇 번 더 시도한다. 그 외 오류는 재시도해도 같은 결과라 바로 포기한다.
   */
  async generate(systemInstruction: string, userContent: string): Promise<string> {
    const key = this.apiKey;
    if (!key) {
      throw new ServiceUnavailableException("GEMINI_API_KEY가 설정되지 않았습니다.");
    }

    // 앱은 50초에 포기한다. 서버가 그보다 오래 재시도하면
    // 성공해도 받아줄 상대가 없으므로, 전체 예산을 45초로 못박는다.
    // 503은 수 초 안에 돌아오므로 예산 안에서 서너 번 시도할 수 있고,
    // 타임아웃(40초)이 한 번 나면 남은 예산이 없어 자연히 끝난다.
    const deadline = Date.now() + 45_000;
    const backoffMs = [700, 1800, 3500];
    for (let attempt = 0; ; attempt += 1) {
      try {
        return await this.requestOnce(key, systemInstruction, userContent, deadline);
      } catch (error) {
        const retriable = error instanceof TransientUpstreamError;
        const wait = backoffMs[attempt];
        const hasBudget =
          wait !== undefined && Date.now() + wait + 5_000 < deadline;
        if (!retriable || !hasBudget) {
          if (retriable) {
            this.logger.warn(`Gemini 과부하로 ${attempt + 1}회 시도 후 포기했습니다.`);
          }
          throw new ServiceUnavailableException("AI 설명 생성에 실패했습니다.");
        }
        await new Promise((resolve) => setTimeout(resolve, wait));
      }
    }
  }

  private async requestOnce(
    key: string,
    systemInstruction: string,
    userContent: string,
    deadline: number,
  ): Promise<string> {

    const url =
      `https://generativelanguage.googleapis.com/v1beta/models/${this.model}:generateContent`;

    // 최신 모델은 '생각' 단계 때문에 10초 이상 걸리는 일이 흔하다.
    // 시도별 한도는 40초, 단 전체 예산(deadline)을 넘기지 않는다.
    const controller = new AbortController();
    const timeout = setTimeout(
      () => controller.abort(),
      Math.max(1_000, Math.min(40_000, deadline - Date.now())),
    );

    try {
      const response = await fetch(url, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-goog-api-key": key,
        },
        body: JSON.stringify({
          systemInstruction: { parts: [{ text: systemInstruction }] },
          contents: [{ role: "user", parts: [{ text: userContent }] }],
          // 생성 하이퍼파라미터.
          // 이 기능은 창의적인 글이 아니라 정해진 형식의 설명을 뽑는 용도이므로
          // 후보 분포를 좁혀 답변이 호출마다 크게 흔들리지 않게 한다.
          generationConfig: {
            temperature: 0.3,   // 낮을수록 확률 높은 토큰에 집중
            topP: 0.8,          // 누적 확률 상위 80%까지만 후보로
            topK: 20,           // 후보 토큰 수 상한
            seed: 42,           // 재현 시도. 다만 완전 동일 응답은 보장되지 않는다
            // 최신 모델은 '생각' 토큰을 쓰고 그 소비량이 출력 예산에 포함된다.
            // 1024로는 생각에 다 쓰여 답변이 중간에 잘리므로 넉넉히 잡는다.
            // (thinkingConfig로 끄는 것은 이 모델에서 400을 반환한다.)
            maxOutputTokens: 4096,
          },
        }),
        signal: controller.signal,
      });

      if (!response.ok) {
        const body = await response.text();
        this.logger.warn(`Gemini 응답 실패 ${response.status}: ${body.slice(0, 200)}`);
        // 과부하와 할당량 초과는 잠시 뒤 풀리는 경우가 많다.
        if (response.status === 503 || response.status === 429 || response.status >= 500) {
          throw new TransientUpstreamError();
        }
        throw new ServiceUnavailableException("AI 설명 생성에 실패했습니다.");
      }

      const json = (await response.json()) as {
        candidates?: { content?: { parts?: { text?: string }[] } }[];
      };
      const text = json.candidates?.[0]?.content?.parts
        ?.map((p) => p.text ?? "")
        .join("")
        .trim();

      if (!text) {
        throw new ServiceUnavailableException("AI 설명이 비어 있습니다.");
      }
      return text;
    } catch (error) {
      if (error instanceof TransientUpstreamError) throw error;
      if (error instanceof ServiceUnavailableException) throw error;
      // 타임아웃과 네트워크 오류도 다시 시도해볼 가치가 있다.
      this.logger.warn(`Gemini 호출 오류: ${String(error)}`);
      throw new TransientUpstreamError();
    } finally {
      clearTimeout(timeout);
    }
  }
}
