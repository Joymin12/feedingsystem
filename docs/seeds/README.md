# Seeds and Source DB

## Files

- `ingredients.seed.json`
  - API와 domain 테스트가 직접 읽는 curated seed
  - 완전한 영양 스냅샷이 있어야 함
  - `null` 허용 안 함

- `final-ingredient-category-groups.json`
  - 최종 운영 분류표
  - `농후사료 / 조사료 / 농산부산물 / 광물질 / 첨가제` 4카테고리로 고정
  - 최종 포함 원료와 카테고리 기준을 feed_no 단위로 기록
  - `4/5/6`은 최종 운영 기준에서 `4 파쇄옥수수`로 통합

- `ingredients.source.extensions.final.json`
  - 최종 원료 원본 DB 추가분
  - `null` 결측 허용
  - 현장명/독립 원료 유지
  - 앱/서버 편입 전 source-of-truth 역할
  - 현재는 `feed_no 200~223` 확장 세트를 유지

- `ingredient-db-normalization-policy.json`
  - 제외 원료, 카테고리 override, `null` 유지 정책

## Rules

- `source DB`와 `API seed`는 분리 유지
- `final-ingredient-category-groups.json`은 source DB를 바로 덮어쓰지 않고, 앱/운영용 최종 분류 기준만 고정한다
- `source DB`에 들어간다고 해서 바로 계산/추천용으로 승격하지 않음
- `ndf/adf/tdn/ca/p` 등 핵심 필드가 부족한 원료는 source-only로 둘 수 있음
- 앱 카탈로그는 입력 편의를 위해 일부 결측 원료를 `0` 보정으로 포함할 수 있으며, 현재 추천 후보에도 포함한다
- `TDN > 100`은 허용
- `커피피`, `커피부산물`, 동물성/곤충류/낙농가공부산물, 산화아연은 최종 DB에서 제외
- 확장 원료 `200~223` 안의 `커피박`은 source DB와 앱 카탈로그에 유지한다
- `미강`, `맥강`, `주정박`, `루핀`, `대두박`, `감귤박` 등 현장명 원료는 기존 canonical 원료와 자동 매칭하지 않고 source DB에서 독립 원료로 유지
- 일부 유박/부산물 계열은 영양성분이 농후사료와 비슷해도 source DB 분류는 `농산부산물`로 유지
