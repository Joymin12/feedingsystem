import type { CreateExplanationDto } from "./explanations.dto.js";

/**
 * AI 응답 가드레일.
 *
 * 생성형 AI는 그럴듯한 숫자를 지어내거나 판정을 뒤집을 수 있다.
 * 이 앱에서 숫자와 판정은 계산 엔진이 확정한 값이 유일한 정답이므로,
 * 응답을 화면에 보여주기 전에 아래 세 가지를 기계적으로 검사한다.
 *
 *   1. 수치 창작 — 응답에 등장하는 숫자가 엔진 페이로드에 없는 값인가
 *   2. 판정 번복 — 엔진이 부족/과잉이라 한 항목을 적정이라 말했는가
 *   3. 원료 창작 — 배합에 없는 원료의 투입량을 제시했는가
 *
 * 하나라도 걸리면 응답을 폐기하고 앱이 내장 설명으로 폴백한다.
 */

export interface GuardrailViolation {
  kind: "invented_number" | "reversed_judgement" | "unknown_ingredient";
  detail: string;
}

/** 설명 문장에서 자연스럽게 쓰이는 작은 정수는 창작으로 보지 않는다. */
const FREE_INTEGER_MAX = 12;

/** 엔진 판정과 어긋나는지 볼 때 쓰는 표현들. */
const ADEQUATE_WORDS = ["적정", "충분", "알맞"] as const;
const OFF_BAND_WORDS = ["부족", "과잉", "초과", "미달"] as const;

function round1(n: number): number {
  return Math.round(n * 10) / 10;
}

/** 페이로드에서 AI가 인용해도 되는 숫자를 모은다. */
function allowedNumbers(payload: CreateExplanationDto): Set<number> {
  const set = new Set<number>();
  const add = (n: number | undefined) => {
    if (n === undefined || Number.isNaN(n)) return;
    set.add(round1(n));
    set.add(round1(Math.abs(n)));
    set.add(Math.round(n));
    set.add(Math.round(Math.abs(n)));
  };

  add(payload.totalAsFedKg);
  for (const j of payload.judgements) {
    add(j.value);
    add(j.bandMin);
    add(j.bandMax);
  }
  for (const a of payload.actions) {
    add(a.fromKg);
    add(a.toKg);
    add(a.deltaKg);
  }
  return set;
}

/** 응답 문자열에서 숫자 토큰을 뽑는다. */
function extractNumbers(text: string): number[] {
  const matches = text.match(/\d+(?:\.\d+)?/g) ?? [];
  return matches.map(Number).filter((n) => !Number.isNaN(n));
}

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

export function checkExplanation(
  text: string,
  payload: CreateExplanationDto,
): GuardrailViolation[] {
  const violations: GuardrailViolation[] = [];

  // 1. 수치 창작
  const allowed = allowedNumbers(payload);
  for (const n of extractNumbers(text)) {
    if (Number.isInteger(n) && n <= FREE_INTEGER_MAX) continue;
    if (allowed.has(round1(n)) || allowed.has(Math.round(n))) continue;
    violations.push({
      kind: "invented_number",
      detail: `엔진 결과에 없는 숫자 ${n} 이(가) 설명에 등장했습니다.`,
    });
  }

  // 2. 판정 번복
  for (const j of payload.judgements) {
    const label = escapeRegExp(j.label);
    const key = escapeRegExp(j.key);
    const near = `(?:${label}|${key})[^.!?\\n]{0,24}`;

    // 적정인 항목을 부족/과잉이라 하거나, 그 반대인 경우만 잡는다.
    // 주의(caution)는 표현 폭이 넓어 오탐이 많으므로 검사에서 뺀다.
    if (j.status === "caution") continue;
    const conflicting: readonly string[] =
      j.status === "adequate" ? OFF_BAND_WORDS : ADEQUATE_WORDS;

    for (const word of conflicting) {
      const re = new RegExp(`${near}${escapeRegExp(word)}`);
      if (re.test(text)) {
        violations.push({
          kind: "reversed_judgement",
          detail: `${j.label}은(는) 엔진 판정이 '${j.status}'인데 설명에서 '${word}'로 언급되었습니다.`,
        });
        break;
      }
    }
  }

  // 3. 원료 창작 — kg 수치 앞에 배합에 있는 원료명이 있는지
  //
  // "루핀씨드를 3kg에서 7.0kg으로" 처럼 한 원료에 kg이 여러 번 붙으므로,
  // kg 토큰마다 앞 구간을 훑어 아는 원료명이 하나라도 있으면 통과시킨다.
  const knownNames = payload.actions.map((a) => a.name).filter((n) => n.length >= 2);
  const LOOKBEHIND = 40;
  const kgPattern = /[+\-−]?\d+(?:\.\d+)?\s*kg/g;
  let match: RegExpExecArray | null;
  while ((match = kgPattern.exec(text)) !== null) {
    const window = text.slice(Math.max(0, match.index - LOOKBEHIND), match.index);
    if (knownNames.some((name) => window.includes(name))) continue;
    violations.push({
      kind: "unknown_ingredient",
      detail: `'${match[0].trim()}' 앞에 배합에 있는 원료명이 없습니다: "…${window.trim()}"`,
    });
  }

  return violations;
}
