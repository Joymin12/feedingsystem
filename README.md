# Hanwoo TMR Platform

한우 TMR 운영 도구를 위한 모노레포입니다. 현재는 **Android 앱 + NestJS API** 기준으로 정리되어 있습니다.

## Workspace

- `apps/android`: Kotlin + Jetpack Compose 안드로이드 앱
- `apps/api`: NestJS 기반 REST API
- `packages/contracts`: 공유 타입과 API 계약
- `packages/domain`: 배합 계산, 부족/적정/과잉 판정, 추천 엔진

## 현재 MVP 범위

- `preferred_stage`를 포함한 농장 설정 관리
- `formula` 기반 기본 TMR 저장/수정
- `preferred_stage` 기준 대표 분석 생성
- 같은 `formula` 기준 `stage comparison` 조회
- 추천 결과를 `owned_ingredient_adjustments` / `supplemental_suggestions`로 분리
- Figma 앱 UI 기준의 안드로이드 홈 / 배합 / 추천 / 커뮤니티 / 농장 화면 골격

## 아키텍처 원칙

- 계산은 `packages/domain`의 엔진이 수행하고, AI가 숫자를 계산하지 않는다.
- 추천은 계산 결과 이후에만 생성한다.
- `formula.items`는 배합 입력만 담당한다.
- 보유 원료 정책은 `farm_ingredient_settings`, 재고는 `inventory` 레이어로 분리한다.
- `formula`, `analysis_run`, `recommendation` 모델 이름은 유지한다.

## 주요 API

- `GET /v1/farm/profile`
- `PUT /v1/farm/profile`
- `POST /v1/analysis-runs`
- `GET /v1/analysis-runs/:runId`
- `GET /v1/formulas`
- `GET /v1/formulas/:formulaId`
- `PUT /v1/formulas/:formulaId`
- `GET /v1/formulas/:formulaId/stage-comparison`

## 실행

### API

1. `npm install`
2. `npm run dev`
3. API: `http://localhost:4000/v1`

### Android

1. Android Studio 설치
2. `apps/android` 폴더를 Android Studio로 열기
3. JDK 17, Android SDK 34 기준으로 Gradle Sync
4. Emulator에서 API 주소는 `http://10.0.2.2:4000` 사용
5. Nest API를 먼저 켠 뒤 앱 실행

## 비고

- 현재 `apps/api/src/store.ts`는 mock store를 사용한다.
- `apps/android`는 Figma 앱 UI 파일을 기준으로 Compose 화면 구조를 맞추는 중이다.
- 커뮤니티 화면은 현재 API가 없어 앱 내부 seed 데이터로 표시한다.
- stage target DB와 ingredient DB는 MVP에서는 상수/seed 형태로 시작하고, 이후 실제 데이터 소스로 교체할 수 있게 경계를 나눠 두었다.