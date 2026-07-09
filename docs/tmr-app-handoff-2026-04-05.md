# 한우 TMR 앱 구현 핸드오프

작성일: 2026-04-05

## 1. 목적

- 농가가 현재 급여 중인 기본 TMR을 입력하고 저장한다.
- 농장 설정의 `preferred_stage`를 기준으로 대표 분석 결과를 먼저 본다.
- 같은 배합에 대해 다른 성장 단계 결과도 비교해서 본다.
- 추천은 `보유 원료 우선` 원칙으로 생성하고, 부족하면 외부 추천 원료를 별도로 제시한다.
- iOS 프로토타입을 먼저 검증하고, 이후 안드로이드는 같은 API/도메인 계약을 재사용한다.

## 2. 현재 코드 기준 고정사항

### 모노레포 구조

- `apps/api`: REST API
- `apps/ios`: 설치형 사용자 프로토타입 UI
- `packages/contracts`: 공유 enum, DTO, 응답 타입
- `packages/domain`: 계산 엔진, 상태 판정, 추천 로직

### 기존 핵심 모델

- 내부 저장 모델은 `formula`를 유지한다.
- 사용자 노출 문구는 필요하면 `기본 TMR`로 바꾼다.
- 분석 결과 저장 모델은 `analysis_run`을 유지한다.
- 추천 결과 저장 모델은 `recommendation`을 유지한다.

### 현재 Stage 기준

다음 enum을 유지한다.

```ts
export type Stage =
  | "growing_early"
  | "growing_late"
  | "fattening_early"
  | "fattening_mid"
  | "fattening_late"
  | "breeding";
```

`growing` 단일 단계나 4단계 축으로 다시 정의하지 않는다.

## 3. 이번 구현의 핵심 결정

### 용어 매핑

- 제품 문서의 `기본 TMR` = 현재 코드의 `formula`
- 제품 문서의 `기본 TMR 원료 목록` = 현재 코드의 `formula.items`
- 제품 문서의 `단계별 분석 결과` = 확장된 `analysis` 응답 또는 비교 전용 응답

### 농장 설정 확장

기존 `FarmProfile`에 `preferred_stage`를 추가한다.

```ts
type FarmProfile = {
  farm_id: string;
  farm_name: string;
  storage_level: StorageLevel;
  wet_feed_policy: WetFeedPolicy;
  cost_priority: number;
  stability_priority: number;
  notes?: string;
  preferred_ingredients: string[];
  avoided_ingredients: string[];
  preferred_stage: Stage;
};
```

`preferred_stage`는 선택값이 아니라 필수값으로 맞추는 편이 안전하다.
초기값은 운영 정책에 따라 `fattening_mid` 또는 기존 대표 단계 기준으로 백필한다.

### 계산/추천 경계

- 계산 엔진은 수치형 영양 데이터만 사용한다.
- 추천 엔진은 계산 결과를 입력으로 받는다.
- 추천 문구, 태그, 주의사항은 계산 판정 이후 해석 레이어에서만 사용한다.

## 4. 데이터 모델 원칙

### 유지할 테이블

- `farm_profiles`
- `ingredients`
- `ingredient_nutrition_versions`
- `ingredient_ai_profiles`
- `farm_ingredient_settings`
- `formulas`
- `formula_items`
- `analysis_runs`
- `recommendations`

### 추가 또는 변경할 필드

#### `farm_profiles`

- `preferred_stage stage_enum NOT NULL`

#### `analysis_runs`

대표 단계 결과와 비교 결과를 같이 보여주기 위해 아래 중 하나로 확장한다.

옵션 A
- 기존 `analysis_runs`는 단일 단계 결과만 유지
- 비교용 응답은 API 서비스 계층에서 같은 formula를 여러 stage로 재계산해 조합

옵션 B
- `analysis_runs.input_snapshot` 또는 별도 JSON 필드에 비교 결과를 스냅샷 저장

MVP는 옵션 A가 더 단순하다.

#### `recommendations`

현재 단일 Top N 랭킹만으로는 요구사항을 표현하기 어렵다.
출력 계약은 아래처럼 두 그룹으로 분리한다.

- `owned_ingredient_adjustments`
- `supplemental_suggestions`

영속화는 아래 두 방법 중 하나를 선택한다.

옵션 A
- 기존 `recommendations` 테이블 유지
- `recommendation_group` 같은 구분 필드 추가

옵션 B
- 저장은 기존 방식 유지
- API 응답에서 그룹을 분리해 반환

MVP는 옵션 B가 더 빠르다.

## 5. API 방향

기존 엔드포인트를 최대한 유지한다.

### 농장 설정

```ts
GET /v1/farm/profile
PUT /v1/farm/profile
```

응답과 요청에 `preferred_stage`를 추가한다.

### 배합 저장

```ts
POST /v1/formulas
GET /v1/formulas/:formulaId
PUT /v1/formulas/:formulaId
```

설명 문구나 화면 레이블만 `기본 TMR`로 바꿀 수 있다.

### 대표 분석 + 단계 비교

MVP 권장안:

```ts
POST /v1/analysis-runs
GET /v1/analysis-runs/:runId
GET /v1/formulas/:formulaId/stage-comparison
```

`POST /v1/analysis-runs`는 `preferred_stage` 기준 대표 결과 1건을 생성한다.
`GET /v1/formulas/:formulaId/stage-comparison`은 같은 formula를 여러 stage로 계산한 비교 데이터를 반환한다.

응답 예시:

```ts
type StageComparisonResponse = {
  preferred_stage: Stage;
  representative_run_id?: string;
  representative: {
    stage: Stage;
    nutrients: Array<{
      key: "dm" | "cp" | "tdn" | "ndf" | "adf" | "ca" | "p" | "moisture";
      current_value: number;
      target_value?: number;
      min_target_value?: number;
      max_target_value?: number;
      status: "deficient" | "adequate" | "excess";
    }>;
  };
  comparisons: Array<{
    stage: Stage;
    deficient_count: number;
    excess_count: number;
    adequate_count: number;
  }>;
};
```

### 추천 조회

현재 분석 상세 응답 안의 추천을 확장하거나 별도 조회 API를 둔다.

권장 응답 형태:

```ts
type StageRecommendationResult = {
  stage: Stage;
  issues: Array<{
    nutrient_key: string;
    status: "deficient" | "excess";
    explanation: string;
  }>;
  owned_ingredient_adjustments: Array<{
    ingredient_id: string;
    action: "increase" | "decrease" | "maintain" | "replace";
    reason: string;
  }>;
  supplemental_suggestions: Array<{
    ingredient_id: string;
    reason: string;
    caution?: string;
  }>;
};
```

## 6. 도메인 구현 방향

### 계산 엔진

현재 `packages/domain/src/analysis.ts`를 중심으로 확장한다.

- 단일 stage 계산 함수는 유지한다.
- 같은 formula를 여러 stage에 대해 반복 계산하는 orchestration 함수를 추가한다.
- 대표 결과는 `preferred_stage`를 기준으로 선택한다.

권장 흐름:

1. formula 로드
2. 대표 stage 결정
3. 대표 stage로 분석 실행
4. 비교 대상 stage 목록 순회
5. stage별 deficient/adequate/excess 집계
6. 결과를 대표 응답 + 비교 응답으로 조합

### 추천 엔진

현재 로직은 전 후보를 한 번에 점수화하는 구조다.
요구사항에 맞추려면 2단계로 바꾼다.

권장 흐름:

1. 계산 결과에서 부족/과잉 영양소 추출
2. 보유 원료 또는 현재 사용 중 원료만 대상으로 1차 추천 생성
3. 1차 추천으로 해결 불가한 항목이 있으면 외부 원료 후보 생성
4. 설명 문구와 주의사항은 마지막 단계에서 조합

### 보유 원료 판단 기준

다음 중 하나라도 만족하면 보유 원료 후보로 본다.

- `farm_ingredient_settings.inventory_kg > 0`
- 현재 formula에 포함된 원료
- 농장 설정에서 사용 가능(`is_enabled=true`, `is_banned=false`)한 원료

운영 정책상 더 엄격히 가려면 `inventory_kg > 0`만 보유 원료로 본다.
MVP는 현재 formula 포함 원료 + 재고 원료를 모두 허용하는 편이 UX상 낫다.

## 7. 프론트 구현 방향

### 홈 화면

- 내 농장 요약
- `preferred_stage` 표시
- 최근 대표 분석 결과 요약
- 같은 formula 기준 단계 비교 카드
- 보유 원료 추천 카드
- 외부 추천 원료 카드

### 농장 설정 화면

기존 필드 유지:

- 농장명
- 저장성 수준
- 습식 원료 정책
- 비용 우선도
- 안정성 우선도
- 메모

추가 필드:

- `preferred_stage`

### 배합 입력 화면

내부 API와 상태 이름은 `formula` 유지:

- 배합명
- 단계
- 평균 체중
- 두수
- 목표 ADG
- 원료 추가/삭제
- 저장
- 저장 후 분석

화면 문구는 필요 시 `기본 TMR`로 노출한다.

### 결과 화면

- 대표 단계 기준 요약 카드
- 영양소별 부족/적정/과잉
- 자동 경고
- 보유 원료 기준 조정안
- 외부 추천 원료
- 단계별 비교 섹션

프론트는 계산값을 재가공하지 않고 API 응답을 그대로 렌더링한다.

## 8. 구현 순서

### 1단계 계약 정리

- `packages/contracts`에 `preferred_stage` 반영
- 비교 응답 타입 추가
- 추천 응답 분리 타입 추가
- OpenAPI 갱신

### 2단계 DB/Mock 정리

- `farm_profiles.preferred_stage` 추가
- mock database 기본값 추가
- seed 또는 초기 farm profile 백필 정책 반영

### 3단계 도메인 확장

- 단일 분석 유지
- multi-stage comparison 서비스 추가
- 추천을 `owned`와 `supplemental`로 분리

### 4단계 API 확장

- `/farm/profile` 요청/응답 확장
- `/formulas/:formulaId/stage-comparison` 추가
- 분석 상세 응답 또는 추천 응답 확장

### 5단계 프론트 반영

- 농장 설정에 `preferred_stage` 추가
- 홈 화면 대표 결과/비교 섹션 추가
- 분석 상세 화면 추천 그룹 분리

## 9. 역할별 전달사항

### Backend

- `preferred_stage`를 기존 `farm_profiles`에 추가
- `formula` 모델은 유지
- 비교용 API는 같은 formula를 여러 stage로 계산해 응답 조합
- 추천 결과는 `owned`와 `supplemental`을 명시적으로 분리
- 계산 엔진은 태그/문구 DB에 의존하지 않도록 유지

### Frontend

- 홈 상단에 `preferred_stage` 대표 결과 노출
- 결과 화면에서 추천 그룹을 분리해서 표시
- `formula` 기반 API는 유지하되 사용자 문구는 `기본 TMR`로 정리
- 비교 카드에서 단계별 부족/과잉 개수를 빠르게 읽을 수 있게 구성

### QA

- `preferred_stage` 저장/조회 검증
- 같은 formula에서 stage별 결과가 달라지는지 검증
- 대표 단계와 비교 단계가 섞이지 않는지 검증
- 보유 원료 추천과 외부 추천이 분리되는지 검증
- 계산 결과와 추천 문구가 모순되지 않는지 검증

### Refactoring

- stage label 상수화
- nutrient key 상수화
- 비교 응답 조합 로직을 API 서비스 계층으로 분리
- 추천 점수화와 문구 생성 로직 분리

### Code Review

- enum 값이 contracts/OpenAPI/DB/UI에서 일치하는지 확인
- `preferred_stage` 기본값과 fallback이 안전한지 확인
- 계산 엔진이 태그나 설명 텍스트에 오염되지 않았는지 확인
- 추천 그룹이 응답 단계에서만 분리된 것인지, 실제 로직도 분리됐는지 확인
- 웹 전용 가정이 contracts/domain에 침투하지 않았는지 확인

## 10. 위험요소

- `Stage`를 새 enum으로 재정의하면 기존 요구치 프로필과 UI가 함께 깨진다.
- `base_mix`를 새 엔티티로 만들면 `formula`와 이중 모델이 된다.
- 비교 결과를 단일 `analysis_run`에 무리하게 합치면 스냅샷 의미가 흐려진다.
- 보유 원료 우선 규칙을 점수 가산 정도로만 처리하면 제품 요구사항을 만족하지 못한다.
- 안드로이드 구조를 먼저 가정하면 아직 없는 앱 계층 때문에 문서와 실제 구현이 어긋난다.

## 11. 금지사항

- `formula`를 폐기하고 `base_mix`를 새 저장 모델로 만들지 않는다.
- `Stage`를 4단계로 축소하지 않는다.
- 계산 로직에서 AI 태그나 설명 문구를 직접 사용하지 않는다.
- 프론트에서 부족/과잉 판정을 다시 계산하지 않는다.
- 보유 원료 추천과 외부 추천을 한 배열에 섞어서 반환하지 않는다.

## 12. 테스트 체크리스트

- `preferred_stage` 저장 및 조회
- 농장 설정 수정 후 홈 반영
- formula 저장 후 대표 단계 분석 생성
- 같은 formula 기준 단계별 비교 응답 생성
- 단계 변경 시 부족/적정/과잉 집계 변화
- 보유 원료가 있으면 1차 추천에 우선 반영
- 보유 원료만으로 부족하면 외부 추천 fallback 생성
- 금지 원료가 어떤 추천 그룹에도 포함되지 않음
- 분석 결과와 추천 문구 간 모순 없음
- 웹에서 같은 입력값으로 재조회해도 결과가 일관됨

## 13. 안드로이드 확장 기준

- 현재 저장소에는 안드로이드 앱 모듈이 없다.
- 안드로이드는 이후 별도 앱으로 추가하되 `packages/contracts` 수준의 API 계약을 기준으로 맞춘다.
- 웹과 안드로이드는 같은 정보 구조를 사용한다.
- 도메인 규칙은 API와 contracts에 두고, 플랫폼별 화면 컴포넌트에는 넣지 않는다.

## 14. 권장 MVP 범위

- `preferred_stage` 추가
- 대표 결과 1건 생성
- 같은 formula 기준 stage comparison 조회
- 추천 결과를 `보유 원료 조정안`과 `추가 추천 원료`로 분리
- 홈/설정/결과 화면 반영

이 범위를 먼저 닫은 뒤, 그 다음에 리포트와 안드로이드 확장을 붙이는 순서가 맞다.
