import { Inject, Injectable, Logger, ServiceUnavailableException } from "@nestjs/common";

import type { CreateExplanationDto } from "./explanations.dto.js";
import { GeminiClient } from "./gemini.client.js";
import { checkExplanation, type GuardrailViolation } from "./guardrails.js";

const SYSTEM_INSTRUCTION = `너는 한우 사료 배합 앱의 설명 도우미다.
입력으로 받는 JSON의 수치와 판정은 앱 계산 엔진이 이미 확정한 최종값이다.

반드시 지켜야 할 규칙:
- 수치를 새로 계산하거나 추정하지 마라.
- JSON에 없는 숫자를 쓰지 마라. 숫자는 JSON 값을 그대로 인용만 한다.
- 부족 / 주의 / 적정 / 과잉 판정을 번복하지 마라.
- 배합에 없는 원료의 투입량(kg)을 제시하지 마라.
- 표나 마크다운 기호, 번호, 제목을 쓰지 마라.
- 영양소 이름은 입력에 적힌 표기(CP, TDN, ADF 등)를 그대로 쓰고,
  풀어 쓸 때는 단백질, 에너지, 섬유소, 칼슘처럼 농가가 쓰는 말만 써라.
  전문 용어를 새로 지어내거나 바꿔 부르지 마라.

농가가 바쁜 축사에서 30초 안에 읽는 글이다. 짧게 써라.
전체 4문장을 넘기지 말고, 아래 순서로 이어지는 한 문단으로 쓴다.

첫 문장: 지금 무엇이 기준을 벗어났는지.
둘째 문장: 어떤 원료를 왜 늘렸는지. 그 원료의 어떤 성분이 부족한 항목을 채우는지 밝힌다.
셋째 문장: 어떤 원료를 왜 줄였는지. 그 원료의 어떤 성분이 과잉 항목을 올리고 있었는지 밝힌다.
넷째 문장: 사료를 한 번에 크게 바꾸면 반추위가 적응하지 못하므로 2~3주에 걸쳐 나누어 적용하라는 안내.

늘리고 줄인 원료가 여러 개면 가장 변화가 큰 것만 언급한다.
"왜 이렇게 바꿨는가"에만 답하고, 배경 설명이나 일반론은 쓰지 마라.

원료에 note가 붙어 있으면 그 내용은 국가 기관이 제시한 사양 기준이다.
언급하는 원료에 note가 있으면 그 근거를 한 구절로 덧붙여라.
예: "쌀겨는 비육기 10퍼센트 이내 권장이라 그 안에서 조정했습니다".
note에 없는 내용을 지어내지 말고, note가 없으면 덧붙이지 마라.`;

@Injectable()
export class ExplanationsService {
  private readonly logger = new Logger(ExplanationsService.name);

  constructor(@Inject(GeminiClient) private readonly gemini: GeminiClient) {}

  async explain(payload: CreateExplanationDto): Promise<{
    text: string;
    model: string;
    guardrail: { passed: true };
  }> {
    if (!this.gemini.isConfigured) {
      // 키가 없으면 조용히 실패시킨다. 앱은 내장 설명으로 폴백한다.
      throw new ServiceUnavailableException("AI 설명이 설정되지 않았습니다.");
    }

    const text = await this.gemini.generate(
      SYSTEM_INSTRUCTION,
      this.buildUserContent(payload),
    );

    const violations = checkExplanation(text, payload);
    if (violations.length > 0) {
      this.logViolations(violations);
      throw new ServiceUnavailableException(
        "AI 설명이 검증을 통과하지 못했습니다.",
      );
    }

    return {
      text,
      model: process.env.GEMINI_MODEL ?? "gemini-2.5-flash",
      guardrail: { passed: true },
    };
  }

  /**
   * AI에게 넘길 입력. 엔진 결과만 담고, 앱 내부 식별자나 사용자 정보는 넣지 않는다.
   */
  private buildUserContent(payload: CreateExplanationDto): string {
    return JSON.stringify(
      {
        stage: payload.stage,
        formulaName: payload.formulaName,
        totalAsFedKg: payload.totalAsFedKg,
        judgements: payload.judgements.map((j) => ({
          nutrient: j.label,
          value: j.value,
          band: [j.bandMin, j.bandMax],
          status: j.status,
        })),
        actions: payload.actions.map((a) => ({
          ingredient: a.name,
          fromKg: a.fromKg,
          toKg: a.toKg,
          deltaKg: a.deltaKg,
          note: a.note,
        })),
        limitationNote: payload.limitationNote,
        engineSummary: payload.engineSummary,
      },
      null,
      2,
    );
  }

  private logViolations(violations: GuardrailViolation[]): void {
    for (const v of violations) {
      this.logger.warn(`가드레일 위반 [${v.kind}] ${v.detail}`);
    }
  }
}
