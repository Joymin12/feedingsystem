# 아키텍처 개요

## 모노레포

- `apps/api`: NestJS REST API
- `apps/ios`: SwiftUI 프로토타입 UI
- `packages/contracts`: API/도메인 공유 enum, DTO, 응답 타입
- `packages/domain`: 계산, 판정, 추천 점수화, 설명 템플릿

## 핵심 경계

- 인증/권한: API 계층
- 계산 엔진: 순수 함수
- 추천 엔진: 순수 함수
- 스냅샷 저장: 영속 계층
- 리포트 생성: 분석 스냅샷 기준

## 데이터 원칙

- 농장 데이터 테이블은 모두 `farm_id` 포함
- `analysis_runs`는 목표값과 입력 문맥을 함께 저장
- `ingredient_nutrition_versions`는 version 이력 테이블
- `recommendation_memos`는 update/delete 금지

## 구현 단계

### M1 계약 고정

- OpenAPI
- PostgreSQL DDL
- Seed JSON

### M2 백엔드 핵심

- auth
- farm profile
- ingredients
- formulas
- analysis runs
- recommendation memos

### M3 프론트 핵심

- 로그인
- 배합 입력
- 계산 결과
- 추천과 사육일지
- 최근 분석 조회

### M4 하드닝

- QA 자동화
- 리포트
- 성능 보강
- 리팩토링
