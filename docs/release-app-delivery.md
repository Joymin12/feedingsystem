# Hanwoo TMR Release App Delivery

## 목적

이 프로젝트는 한우 TMR 배합 입력, 영양 분석, 복합교정안 추천, 사육일지 기록을 하나의 iOS 앱 흐름으로 묶는 현장형 앱이다.

핵심 원칙:

- 사용자는 원물 kg 기준으로 배합을 입력한다.
- 내부 계산은 DM 기준으로 수행한다.
- 성장단계별 기준으로 `적정 / 주의 / 부족 / 과잉`을 판정한다.
- 추천안은 단일 원료가 아니라 복합교정안 대표안이다.
- AI는 설명용이고, 교정안 자체는 계산 엔진이 결정한다.

## 현재 출시형 화면 범위

적용 대상 핵심 화면:

- 홈
- 배합 입력
- 분석 결과
- 추천안
- 최근 분석
- 사육일지
- 내 농장
- 엔진 검증

이번 마감에서는 공용 디자인 시스템을 코드에 반영해서 아래 기준으로 통일했다.

- 연한 올리브/크림 계열 배경
- 라운드 큰 카드
- 운영 대시보드형 히어로 영역
- 상태 배지와 핵심 지표 타일
- 추천안 카드의 계층 정리

## 피그마 산출물

출시형 주요 화면 4종을 피그마 파일로 생성했다.

- 파일: [Hanwoo TMR Release App Screens](https://www.figma.com/design/s0zgQbmYcZb1yF7gAJNMfx)

현재 포함 화면:

- 홈
- 배합
- 분석 결과
- 추천안

용도:

- 출시 시연용 비주얼 기준
- 추가 디자인 고도화의 기준점
- 개발/디자인 커뮤니케이션 기준

## 코드 기준 파일

핵심 앱 UI:

- `/Users/jowm/Desktop/feedingsystem/apps/ios/HanwooPrototype/HanwooPrototype/HanwooPrototypeApp.swift`
- `/Users/jowm/Desktop/feedingsystem/apps/ios/HanwooPrototype/HanwooPrototype/RecommendationViews.swift`

원료 카탈로그:

- `/Users/jowm/Desktop/feedingsystem/apps/ios/HanwooPrototype/HanwooPrototype/IngredientCatalog.swift`

개발자용 추천 엔진 설명:

- `/Users/jowm/Desktop/feedingsystem/docs/tmr-recommendation-engine-developer-brief.md`

Supabase 인증/커뮤니티 설정 (현재 미사용, 옵션 보관용):

- `/Users/jowm/Desktop/feedingsystem/docs/supabase/supabase-auth-community-setup.md`
- `/Users/jowm/Desktop/feedingsystem/docs/supabase/schema.sql`

원료 분류표:

- `/Users/jowm/Desktop/feedingsystem/docs/seeds/final-ingredient-category-groups.json`

원료 source 확장 DB:

- `/Users/jowm/Desktop/feedingsystem/docs/seeds/ingredients.source.extensions.final.json`

## 원료 DB 운영 원칙

- 기존 `1~114` 원료와 신규 `200~223` 원료를 함께 유지한다.
- 자동 매칭/병합은 하지 않는다.
- 신규 원료도 추천 후보에 포함한다.
- source DB 원본은 보존한다.
- 앱 카탈로그 구조상 optional이 아닌 영양성분은 `0`으로 넣지만, source 원본은 별도 유지한다.

## 추천 엔진 원칙

- 추천안은 복합교정안 형태여야 한다.
- 예:
  - `미강 -20kg`
  - `파쇄옥수수 +12kg`
  - `대두박 +3kg`
- 대표안 1개를 먼저 보여주고, 대안은 추가로 펼쳐 보여준다.
- `적용 후 예상`은 각 지표별 상태까지 함께 보여준다.

## 현재 운영 모드

- 1차 출시는 `iOS 로컬 앱` 기준으로 진행한다.
- 사용자 인증, 커뮤니티, 사용자 원료 선택도 현재는 `로컬 fallback`을 기본으로 사용한다.
- Supabase 코드는 저장소에 남겨두되, 현재 릴리즈 경로에서는 사용하지 않는다.
- 배합 계산과 복합교정안 추천은 계속 로컬 엔진이 담당한다.

## 개발자에게 먼저 읽힐 문서

추천 엔진과 배합비 교정안을 이어서 개발하려면 아래 순서로 읽으면 된다.

1. `/Users/jowm/Desktop/feedingsystem/docs/tmr-recommendation-engine-developer-brief.md`
2. `/Users/jowm/Desktop/feedingsystem/docs/user-auth-and-ingredient-scope.md`
3. `/Users/jowm/Desktop/feedingsystem/docs/seeds/final-ingredient-category-groups.json`
4. `/Users/jowm/Desktop/feedingsystem/docs/seeds/ingredients.source.extensions.final.json`
5. `/Users/jowm/Desktop/feedingsystem/docs/seeds/README.md`
6. `/Users/jowm/Desktop/feedingsystem/docs/seeds/ingredient-db-normalization-policy.json`

참고 문서:

- `/Users/jowm/Desktop/feedingsystem/docs/supabase/supabase-auth-community-setup.md`
- `/Users/jowm/Desktop/feedingsystem/docs/supabase/schema.sql`

## 이번 턴에서 의도적으로 하지 않은 것

- 자동 테스트 추가
- 회귀 테스트 정비
- 서버 이관
- API DTO 구현
- 앱스토어 배포 메타데이터 정리

이건 사용자 요청대로 `테스트 없이 바로 직행` 기준으로 제외했다.

## 바로 다음 작업

- 새 `200~223` 원료가 실제 추천안에 어떻게 반영되는지 엔진 검증 7개 배합 재확인
- 홈/배합/분석/추천 외 나머지 화면까지 같은 디자인 시스템으로 추가 정리
- 저장 흐름과 최근 분석/일지 흐름의 실제 사용성 점검
