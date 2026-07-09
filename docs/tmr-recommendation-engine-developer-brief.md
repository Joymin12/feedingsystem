# 한우 TMR 배합 계산/추천 엔진 개발 브리프

## 1. 프로젝트 목적

이 프로젝트는 한우 농가가 `원물 기준 kg`로 현재 배합을 입력하면:

1. 내부적으로 `DM 기준`으로 영양을 계산하고
2. 성장단계별 기준과 비교해 `부족 / 주의 / 적정 / 과잉`을 판정하며
3. 최종적으로 `복합교정안` 형태의 추천안을 제시하는 앱입니다.

핵심 원칙:

- `추천안 = 복합교정안 대표안`
- `AI는 설명 전용`
- `교정안 결정은 규칙 기반 엔진`
- `1차 출시는 iOS 로컬 엔진`
- `사용자 인증/커뮤니티도 현재는 로컬 저장 우선`
- `서버/NestJS 계산 엔진 이관은 후속 단계`

예상 출력 형태:

- `미강 -20kg`
- `파쇄옥수수 +12kg`
- `대두박 +3kg`

## 2. 데이터 경계

현재 인증과 커뮤니티는 아래 로컬 기준 문서를 같이 본다.

- `/Users/jowm/Desktop/feedingsystem/docs/user-auth-and-ingredient-scope.md`

Supabase 문서는 현재 미사용 참고 문서다.

- `/Users/jowm/Desktop/feedingsystem/docs/supabase/supabase-auth-community-setup.md`
- `/Users/jowm/Desktop/feedingsystem/docs/supabase/schema.sql`

프로젝트에는 원료 데이터가 3층으로 나뉩니다.

### source DB

파일:
- `/Users/jowm/Desktop/feedingsystem/docs/seeds/ingredients.source.extensions.final.json`

특징:
- 현장명 유지
- 결측값 `null` 허용
- 원본/source-of-truth 역할

예:
- `미강`
- `비지`
- `주정박`
- `루핀`

### app catalog

파일:
- `/Users/jowm/Desktop/feedingsystem/apps/ios/HanwooPrototype/HanwooPrototype/IngredientCatalog.swift`

특징:
- 앱이 직접 계산에 사용하는 카탈로그
- `IngredientNutritionProfile`이 optional을 허용하지 않기 때문에 결측 source 원료는 현재 `0`으로 보정해 편입
- 사용자 검색/선택 가능
- 추천 후보에도 현재 포함

중요:
- 이 정책은 입력 편의를 우선한 것이고, 결측 보정 원료는 추천 품질 리스크가 있음

### curated API seed

파일:
- `/Users/jowm/Desktop/feedingsystem/docs/seeds/ingredients.seed.json`

특징:
- 완전한 영양 스냅샷이 있는 curated seed
- `null` 허용 안 함
- API/domain 테스트용

## 3. 입력과 계산 기준

사용자 입력은 항상 `원물 kg`입니다.

내부 계산은 다음 순서로 진행합니다.

### 3.1 원물 -> DM 변환

공식:

```text
DM_kg = as_fed_kg × (dm_pct / 100)
```

또는

```text
DM_kg = as_fed_kg × (1 - moisture_pct / 100)
```

### 3.2 배합 전체 영양 계산

각 원료의 영양성분은 `%DM` 기준입니다.

배합 전체 성분은 `DM 가중평균`으로 계산합니다.

예:

```text
배합 CP%DM = Σ(원료 DMkg × 원료 CP%DM) / 총 DMkg
배합 TDN%DM = Σ(원료 DMkg × 원료 TDN%DM) / 총 DMkg
```

### 3.3 수분

전체 수분은 원물 기준으로 계산합니다.

```text
총 수분kg = Σ(원료 as-fed kg × moisture_pct / 100)
배합 수분% = 총 수분kg / 총 as-fed kg × 100
```

### 3.4 Ca:P 비율

`Ca`, `P`는 각각 `%DM 절대량`으로 계산하고,
`Ca:P`는 `%`가 아니라 `비율`입니다.

```text
Ca:P = Ca_pct_dm / P_pct_dm
```

## 4. 성장단계 기준

### 육성기

- `CP 14~18`
- `TDN 68~75`
- `NDF 35~45`
- `ADF 20~28`
- `EE <= 6`
- `Ca 0.45~0.80`
- `P 0.28~0.45`
- `Ca:P 1.5~2.0`
- `수분 40~45`

### 비육전기

- `CP 12~15`
- `TDN 72~76`
- `NDF 30~38`
- `ADF 18~24`
- `EE <= 6`
- `Ca 0.35~0.65`
- `P 0.22~0.38`
- `Ca:P 1.5~2.0`
- `수분 40~45`

### 비육후기

- `CP 11~13`
- `TDN 73~78`
- `NDF 25~32`
- `ADF 15~20`
- `EE <= 6`
- `Ca 0.30~0.60`
- `P 0.20~0.35`
- `Ca:P 1.5~2.0`
- `수분 40~45`

## 5. 판정 로직

### 범위형 영양소

- `적정`: 범위 안
- `주의`: 범위 밖이지만 주의 밴드 안
- `부족/과잉`: 주의 밴드 초과

### 수분

- `<35`: 부족
- `35~40`: 주의
- `40~45`: 적정
- `45~50`: 주의
- `>50`: 과잉

### 표현 톤

- `주의`: `권장합니다`, `고려해보세요`
- `부족/과잉`: `점검이 필요합니다`

## 6. 추천 엔진 목표

엔진 목표는 `원료 1개 추천`이 아니라 `복합교정안 생성`입니다.

예:

- `미강 -20kg`
- `파쇄옥수수 +12kg`
- `대두박 +3kg`

즉 엔진은 다음을 수행해야 합니다.

1. 현재 배합 문제를 분류
2. 과잉 원료 감량
3. 전체 재계산
4. 부족 원료 보강
5. 최종 복합교정안 후보 생성
6. 대표안 1개 선택

## 7. 현재 엔진 구조

핵심 파일:
- `/Users/jowm/Desktop/feedingsystem/apps/ios/HanwooPrototype/HanwooPrototype/PrototypeStore+CorrectionEngine.swift`

현재 구조:

### 7.1 패턴 분류

예:
- `CP+TDN 과잉`
- `CP 과잉`
- `TDN 과잉`
- `EE 과잉 + CP 부족`
- `CP+TDN 부족`
- `fiber deficit`

### 7.2 플랜 생성

패턴별로:
- 감량 후보 찾기
- 보강 후보 찾기
- 다중 액션 묶음 생성

### 7.3 대표안 선택

대표안 선택 우선순위:

1. 하드 제약 통과
2. 과잉 해결 우선
3. 부족 해결
4. 보유 원료 우선
5. 변경 수 적은 안
6. 비용 낮은 안

## 8. 후보 원료 규칙

### 농후사료

단백질/에너지 보강 또는 감량에 사용

예:
- `파쇄옥수수`
- `대두박`
- `루핀`
- `맥주박`
- `주정박`
- `참깻묵(호마박)`

### 조사료

섬유 부족 또는 조사료 대체에 사용

예:
- `볏짚(사일리지)`
- `티모시 짚`
- `오차드그라스 짚`
- `알팔파 펠렛`
- `각종 사일리지`

### 농산부산물

부산물/껍질류/습식 원료

예:
- `미강`
- `비지`
- `맥강`
- `사과박`
- `감귤박`

### 광물질 / 첨가제

예:
- `석회석`
- `소금`
- `인산칼슘류`

## 9. 구현 규칙

### 9.1 입력 단위

- UI 입력: `원물 kg`
- 내부 계산: `DM 기준`

### 9.2 수분 파생

```text
moisture_pct = 100 - dm_pct
```

### 9.3 결측 원료 처리

현재 앱 카탈로그는 `IngredientNutritionProfile`이 non-optional이므로:

- source DB 결측값 `null`은 유지
- app catalog 편입 시 결측값은 `0`으로 채움
- 현재 정책상 이 원료도 추천 후보에 포함

개발 리스크:

- `대두박(232)`처럼 `CP만 있고 TDN/섬유/광물질이 0`으로 들어간 원료는
  추천 품질을 왜곡할 수 있음

장기 권장:

- `IngredientNutritionProfile`을 optional 허용 구조로 리팩토링
- 추천 시 `측정 가능 성분만` 쓰는 방향으로 개선

## 10. 개발자가 구현해야 할 추천 결과 형태

결과는 최소 아래 구조를 가져야 합니다.

```json
{
  "strategy": "costEffective | balanced | ownedFirst",
  "summary": "왜 이 교정안을 제안했는지 한 줄 요약",
  "actions": [
    {
      "type": "decrease | increase | add",
      "ingredientId": "FEED_216",
      "ingredientName": "미강",
      "amountKg": 20
    }
  ],
  "projectedMetrics": {
    "cpPctDm": 12.8,
    "tdnPctDm": 74.1,
    "ndfPctDm": 31.4,
    "adfPctDm": 19.2,
    "caPctDm": 0.42,
    "pPctDm": 0.29,
    "caPRatio": 1.45,
    "moisturePct": 41.2
  },
  "isFullyResolved": false,
  "resolutionRate": 0.72,
  "costDeltaKrw": 12000
}
```

## 11. 개발자용 구현 프롬프트

아래 프롬프트를 개발자/에이전트에게 그대로 전달해도 됩니다.

```md
한우 TMR 배합 추천 엔진을 구현한다.

목표:
- 사용자 입력은 항상 원물 kg
- 내부 계산은 DM 기준
- 결과는 단일 원료 추천이 아니라 복합교정안

입력:
- 배합 원료 목록 (ingredient id, name, as-fed kg)
- 성장단계 (육성기 / 비육전기 / 비육후기)
- 원료 영양 DB (%DM)

필수 계산:
1. 각 원료 원물 kg -> DM kg 변환
2. 배합 전체 CP, TDN, NDF, ADF, EE, Ca, P, 수분 계산
3. Ca:P 비율 계산
4. 성장단계 기준과 비교해 부족/주의/적정/과잉 판정

추천 원칙:
1. 현재 배합 문제 패턴을 먼저 분류한다.
2. 과잉은 감량으로 먼저 해결한다.
3. 감량 후 전체 배합을 다시 계산한다.
4. 부족은 보강 원료 추가로 해결한다.
5. 결과는 여러 액션이 묶인 복합교정안이어야 한다.

예시 출력:
- 미강 -20kg
- 파쇄옥수수 +12kg
- 대두박 +3kg

대표안 선택 우선순위:
1. 하드 제약 통과
2. 과잉 해결 우선
3. 부족 해결
4. 변경 수 적은 안
5. 비용 낮은 안

중요:
- AI는 설명 전용이다.
- 교정안 결정은 규칙 기반 엔진이 한다.
- source DB의 일부 원료는 결측이 있어 app catalog에서는 0으로 채워져 있다.
- 이 원료는 추천 품질 왜곡 가능성이 있으므로 구현 시 별도 품질 주석을 남긴다.
```
