# 데이터 모델 (DATA_MODEL)

정의 위치: `DomainModels.swift`, `Repositories.swift`. 모든 영속 모델은 Codable.

## 핵심 타입

| 타입 | 역할 | 주요 필드 |
| --- | --- | --- |
| FarmStage | 성장단계 | growing / fatteningEarly / fatteningLate |
| StageCriteria | 단계별 기준표 | 축별 RangeThreshold(min/max/cautionMin/cautionMax), EE 상한형, 수분 하드맥스 |
| IngredientDefinition | 카탈로그 원료 | id, sourceFeedNo, name, category, selectionGroup, defaultPriceKrwPerKg, nutrition |
| IngredientNutritionProfile | 성분(건물 기준 %) | moisture, dm, cp, tdn, ndf, adf, nfc, ee, ash, ca, p |
| UserIngredientDefinition | 사용자 원료 | id(`USER_<UUID>`), ownerLoginID, name, category, price, nutrition, createdAt |
| IngredientLine | 배합 라인 | name, definitionID?, amount, unit(kg/g), priceOverrideKrwPerKg? |
| FeedFormula | 배합 | id, name, stage, items, isTestFormula, checkedAt |
| AnalysisSummaryMetrics | 계산 결과 | 총 원물/건물 kg, 수분%, 축별 %DM, Ca:P |
| NutrientStatus | 판정 | nutrient, current, target, tone(부족/주의/적정/과잉), message |
| CorrectionAction | 교정 액션 | ingredientID, type(increase/decrease/add), amountKg |
| Recommendation | 추천안 | strategy, actions, simulatedMetrics, resolutionRate, isFullyResolved, isReferenceOnly, costDeltaKrw, 설명 필드 |
| SavedAnalysis (P3) | 분석 이력 스냅샷 | id, savedAt, formula 사본, metrics, statuses, recommendation, algorithmVersion |
| SimulationConstraints (P2) | 시뮬레이션 제약 | lockedIngredientIDs, perIngredient min/max kg, maxAdjustmentRatio, costWeight |

## ID·단위 규칙

- 카탈로그 ID: `FEED_<no>`(표준사료성분표 1~114, 농사로 200~223), `CUSTOM_*`.
- 사용자 원료 ID: `USER_<UUID>`. 조회는 항상 카탈로그 → 사용자 순이 아니라
  **provider가 통합 해석**하며, 사용자 입력 성분이 우선한다.
- 입력 단위는 kg 또는 g(내부적으로 kg 환산). 성분은 건물 기준 %.
- `definitionID == nil` 라인은 계산 제외·총량 포함(물 등). 추천 후보 불가.

## 영속화 키 (UserDefaults JSON)

| 키 | 내용 |
| --- | --- |
| hanwoo.prototype.users | 로컬 계정 |
| hanwoo.prototype.currentLoginID | 세션 |
| hanwoo.prototype.posts | 커뮤니티 |
| hanwoo.prototype.userIngredients | 사용자 원료 |
| hanwoo.prototype.formulas (P3) | 사용자 배합 |
| hanwoo.prototype.analysisHistory (P3) | 분석 이력(SavedAnalysis 배열) |

디코딩 실패 레코드는 건너뛰고 로그를 남긴다(전체 손실 방지). 스키마 변경 시
마이그레이션은 Repository 구현 내부에서 처리하며 도메인/엔진은 영향받지 않는다.

## 재현성

SavedAnalysis는 결과뿐 아니라 **배합 사본과 algorithmVersion**을 저장한다.
엔진이 갱신되어도 과거 이력은 저장 당시 값 그대로 표시하고, "현재 엔진으로
다시 계산" 액션을 명시적으로 제공할 수 있다(자동 재계산 금지).
