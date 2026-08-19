import { Injectable, Logger, ServiceUnavailableException } from "@nestjs/common";

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
    // gemini-2.5-flash 등 버전 고정 이름은 신규 프로젝트에 막히는 경우가 있어
    // 별칭(latest)을 기본으로 둔다. 특정 버전이 필요하면 .env로 덮어쓴다.
    return process.env.GEMINI_MODEL ?? "gemini-flash-latest";
  }

  get isConfigured(): boolean {
    return Boolean(this.apiKey);
  }

  async generate(systemInstruction: string, userContent: string): Promise<string> {
    const key = this.apiKey;
    if (!key) {
      throw new ServiceUnavailableException("GEMINI_API_KEY가 설정되지 않았습니다.");
    }

    const url =
      `https://generativelanguage.googleapis.com/v1beta/models/${this.model}:generateContent`;

    // 최신 모델은 '생각' 단계 때문에 10초 이상 걸리는 일이 흔하다.
    // 15초로 두면 정상 응답도 잘려 나가므로 넉넉히 잡는다.
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 40_000);

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
        this.logger.warn(`Gemini 응답 실패 ${response.status}: ${body.slice(0, 300)}`);
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
      if (error instanceof ServiceUnavailableException) throw error;
      this.logger.warn(`Gemini 호출 오류: ${String(error)}`);
      throw new ServiceUnavailableException("AI 설명 생성에 실패했습니다.");
    } finally {
      clearTimeout(timeout);
    }
  }
}
