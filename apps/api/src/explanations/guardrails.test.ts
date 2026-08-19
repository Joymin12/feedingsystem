import assert from "node:assert/strict";
import { test } from "node:test";

import type { CreateExplanationDto } from "./explanations.dto.js";
import { checkExplanation } from "./guardrails.js";

const payload: CreateExplanationDto = {
  stage: "육성기",
  formulaName: "육성기 기본 배합",
  totalAsFedKg: 36,
  judgements: [
    { key: "TDN", label: "에너지(TDN)", value: 74.7, bandMin: 68, bandMax: 72, status: "excess" },
    { key: "CP", label: "단백질(CP)", value: 12.6, bandMin: 14, bandMax: 18, status: "deficient" },
    { key: "EE", label: "지방(EE)", value: 3.4, bandMin: 0, bandMax: 5, status: "adequate" },
  ],
  actions: [
    { name: "루핀씨드", fromKg: 3, toKg: 7.0, deltaKg: 4.0 },
    { name: "볏짚(사일리지)", fromKg: 5, toKg: 15.8, deltaKg: 10.8 },
  ],
};

test("엔진 값만 인용한 설명은 통과한다", () => {
  const text = `1) 핵심 문제
에너지(TDN)가 74.7%로 기준 68~72%를 넘었습니다.
2) 1차 조정과 이유
루핀씨드를 3kg에서 7.0kg으로 늘립니다.
5) 기대 결과와 주의점
2~3주에 걸쳐 나누어 적용하세요.`;
  assert.deepEqual(checkExplanation(text, payload), []);
});

test("페이로드에 없는 숫자를 지어내면 걸러낸다", () => {
  const text = "조정하면 일당증체량이 0.95kg까지 올라갑니다.";
  const violations = checkExplanation(text, payload);
  assert.ok(violations.some((v) => v.kind === "invented_number"));
});

test("판정을 뒤집으면 걸러낸다", () => {
  const text = "단백질(CP)은 현재 적정 수준입니다.";
  const violations = checkExplanation(text, payload);
  assert.ok(violations.some((v) => v.kind === "reversed_judgement"));
});

test("배합에 없는 원료의 투입량을 제시하면 걸러낸다", () => {
  const text = "석회석을 2.0kg 추가하세요.";
  const violations = checkExplanation(text, payload);
  assert.ok(violations.some((v) => v.kind === "unknown_ingredient"));
});

test("적정 항목을 적정이라 말하는 것은 통과한다", () => {
  const text = "지방(EE)은 3.4%로 적정합니다.";
  assert.deepEqual(checkExplanation(text, payload), []);
});
