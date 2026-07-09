# feedSearch OpenAPI 기반 DB 설계 기획안

작성일: 2026-04-28

## 1. 결론

`feedSearch` OpenAPI는 단순히 `원료 1건 = 수분/CP/TDN/... 1행` 구조가 아닙니다.

- 목록 1개 오퍼레이션
- 상세 8개 오퍼레이션
- 각 상세는 서로 다른 성분군과 행 구분값을 가짐
- 일부 오퍼레이션은 2행 또는 3행 묶음으로 표현됨
- `분석점수`, `비고`, `구분코드명`이 성분값과 같이 내려옴

따라서 가장 좋은 구조는 아래 3층입니다.

1. `원본 수집층`
   - OpenAPI 응답 전문 보존
2. `정규화 저장층`
   - 사료 기본정보, 행 구분, 성분 측정치를 구조화
3. `앱 투영층`
   - 앱 계산에 필요한 수치만 정리한 계산용 프로필

지금 저장소의 `ingredients + ingredient_nutrition_versions` 구조만으로는 `feedSearch`의 원본 구조를 충분히 담지 못합니다.

## 2. 참고한 파일

- 가이드 명세서: [OpenAPI 활용 매뉴얼 - 사료검색.hwp](/Users/jowm/Downloads/feedSearch/OpenAPI%20활용%20매뉴얼%20-%20사료검색.hwp)
- REST 샘플 목록: [feedSearchList.jsp](/Users/jowm/Downloads/feedSearch/샘플소스/rest/jsp/feedSearchList.jsp)
- REST 샘플 상세: [feedSearchDtl.jsp](/Users/jowm/Downloads/feedSearch/샘플소스/rest/jsp/feedSearchDtl.jsp)
- PHP 샘플 목록: [feedSearchList.php](/Users/jowm/Downloads/feedSearch/샘플소스/rest/php/feedSearchList.php)
- PHP 샘플 상세: [feedSearchDtl.php](/Users/jowm/Downloads/feedSearch/샘플소스/rest/php/feedSearchDtl.php)

## 3. OpenAPI 구조 분석

### 3.1 서비스 구조

가이드 명세서 기준 서비스명은 `feedSearch`입니다.

오퍼레이션은 다음 9개입니다.

- `feedSearchList`
- `feedSearchInfoDtl`
- `feedSearchMineralDtl`
- `feedSearchNutritiveDtl`
- `feedSearchDigestDtl`
- `feedSearchAminoDtl`
- `feedSearchVitaminDtl`
- `feedSearchCellDtl`
- `feedSearchChemDtl`

### 3.2 목록 조회 구조

샘플 코드 기준 목록 조회 요청 URL:

- `http://api.nongsaro.go.kr/service/feedSearch/feedSearchList`

샘플에서 확인되는 요청 파라미터:

- `apiKey`
- `sType`
- `sText`
- `pageNo`

샘플에서 확인되는 목록 응답 주요 필드:

- `hsrrlManageNo`
- `hsrrlNo`
- `koreanNm`
- `engNm`
- `hsrrlPrdlstCodeLclasNm`
- `numOfRows`
- `pageNo`
- `totalCount`

### 3.3 상세 조회 구조

상세는 `hsrrlManageNo` 1개를 기준으로 8개 오퍼레이션을 각각 호출해 조합합니다.

샘플 기준 상세 요청 URL 예시:

- `http://api.nongsaro.go.kr/service/feedSearch/feedSearchInfoDtl`
- `http://api.nongsaro.go.kr/service/feedSearch/feedSearchMineralDtl`
- ...

샘플에서 공통으로 확인되는 요청 파라미터:

- `apiKey`
- `hsrrlManageNo`

### 3.4 각 상세 오퍼레이션이 담는 정보

#### `feedSearchInfoDtl`

기본 식별/분류 정보:

- `hsrrlManageNo`
- `year`
- `hsrrlNo`
- `koreanNm`
- `engNm`
- `hsrrlPrdlstCodeNm`
- `hsrrlPrdlstCodeLclasNm`

#### `feedSearchMineralDtl`

샘플 화면명은 `일반조성분`입니다.

행 구분값:

- `gnrlmakemntSeNm`

수치 필드:

- `mitrValue` 수분
- `takprotValue` 조단백질
- `cuftValue` 조지방
- `usefulRdshNtrgwaterValue` 가용무질소물
- `crfbValue` 조섬유
- `inqiremntValue` 조회분

보조 필드:

- `analsScoreValue`
- `sRm`

#### `feedSearchNutritiveDtl`

행 구분값:

- `ntrtmpySeNm`
- `ntrtmpyKdlsNm`

수치 필드:

- `tdngValue`
- `deValue`
- `geValue`
- `methylValue`
- `trmreValue`
- `nemValue`
- `negValue`
- `nelValue`

보조 필드:

- `sRm`

중요:
샘플에서 컬럼 라벨과 내부 필드명이 완전히 직관적으로 일치하지 않습니다. 예를 들어 `trmreValue`가 화면에서 `NE` 컬럼에 매핑됩니다. 따라서 DB에는 `필드코드`와 `표시라벨`을 분리해서 저장해야 합니다.

#### `feedSearchDigestDtl`

행 구분값:

- `frexrtSeNm`
- `frexrtKdlsNm`

수치 필드:

- `dryMttrValue`
- `protValue`
- `lcltyValue`
- `usefulRdshNtrgwaterValue`
- `fberValue`

보조 필드:

- `analsScoreValue`
- `sRm`

#### `feedSearchChemDtl`

샘플 화면명은 `무기질`입니다.

행 구분값:

- `inorganicMatterSeNm`

수치 필드:

- `dryMttrValue`
- `clciValue`
- `phphValue`
- `ptssValue`
- `naValue`
- `mgnValue`
- `gtValue`
- `sulfurValue`
- `seasnValue`
- `mangValue`
- `cbltValue`
- `zincValue`
- `copprValue`
- `flrnValue`

보조 필드:

- `analsScoreValue`
- `sRm`

#### `feedSearchAminoDtl`

행 구분값:

- `aminoAcdSeCodeNm`

수치 필드:

- `takprotValue`
- `cystineValue`
- `mthnValue`
- `asparticAcdValue`
- `thrnValue`
- `serineValue`
- `glutamicAcdValue`
- `prliValue`
- `artclysnValue`
- `alnnValue`
- `valineValue`
- `isoliritnwValue`
- `liritnwValue`
- `tyrsValue`
- `phnyValue`
- `lysnValue`
- `hstdValue`
- `nh3Value`
- `argnValue`
- `trypValue`

보조 필드:

- `analsScoreValue`
- `sRm`

#### `feedSearchVitaminDtl`

행 구분값:

- `vtmnSeCodeNm`

수치 필드:

- `dryMttrValue`
- `catnValue`
- `vtmaValue`
- `vteValue`
- `vtb1Value`
- `vtb2Value`
- `pnacValue`
- `nacnValue`
- `vtb6Value`
- `biotinValue`
- `flacValue`
- `cholineValue`
- `vtb12Value`

보조 필드:

- `analsScoreValue`
- `sRm`

#### `feedSearchCellDtl`

행 구분값:

- `cellThnflmSeCodeNm`

수치 필드:

- `dryMttrValue`
- `ndfValue`
- `adfValue`
- `hemicelluloseValue`
- `ligninValue`
- `celluloseValue`
- `silictarValue`
- `nfcValue`

보조 필드:

- `analsScoreValue`
- `sRm`

## 4. 설계 시 반드시 반영할 사실

### 4.1 `hsrrlManageNo`는 원본 기준 식별자다

목록에서 상세로 넘어갈 때 사용하는 핵심 키는 `hsrrlManageNo`입니다.

따라서 내부 DB에도 이 값을 별도 컬럼으로 저장해야 합니다.

권장:

- `source_system = 'nongsaro_feedsearch'`
- `source_record_id = hsrrlManageNo`

### 4.2 `hsrrlNo`만으로는 부족하다

`hsrrlNo`는 사람이 보는 사료번호에 가깝고, 실제 상세 호출의 연결키는 아닙니다.

따라서:

- `hsrrlManageNo`를 기술 식별자
- `hsrrlNo`를 비즈니스 코드

로 분리해야 합니다.

### 4.3 원본은 행 구조를 가진다

예를 들어 `feedSearchNutritiveDtl`은 단순히 `TDN 1개`가 아니라,

- 어떤 구분(`ntrtmpySeNm`)
- 어떤 세부 행(`ntrtmpyKdlsNm`)

에 속한 값인지 같이 와야 합니다.

즉 `ingredient_nutrition_versions` 한 줄로 강제로 펼치면 정보가 손실됩니다.

### 4.4 샘플 화면 라벨과 필드코드는 불일치 가능성이 있다

샘플 코드에 표시 라벨과 내부 코드명이 어색하게 매핑된 경우가 있습니다.

따라서 DB에는 아래 둘을 함께 저장해야 합니다.

- `metric_code`
- `metric_label`

## 5. 권장 DB 아키텍처

### 5.1 원본 수집층

이 레이어는 OpenAPI 응답 원문을 그대로 보존합니다.

#### `feedsearch_sync_runs`

수집 실행 단위

- `id`
- `sync_type` 예: `search_seed`, `detail_refresh`, `manual_fetch`
- `requested_by`
- `started_at`
- `finished_at`
- `status`
- `note`

#### `feedsearch_raw_responses`

오퍼레이션별 원문 저장

- `id`
- `sync_run_id`
- `operation_name`
- `request_url`
- `request_params_json`
- `source_record_id` (`hsrrlManageNo` 또는 null)
- `page_no`
- `http_status`
- `result_code`
- `result_msg`
- `response_xml`
- `fetched_at`
- unique: `(operation_name, source_record_id, page_no, fetched_at)`

이 테이블이 필요한 이유:

- API 응답 변경 추적
- 파서 버그 재처리
- 원본 데이터 감사

### 5.2 정규화 저장층

#### `feed_reference_items`

사료 기본 엔티티

- `id`
- `source_system`
- `source_record_id` = `hsrrlManageNo`
- `source_feed_no` = `hsrrlNo`
- `year`
- `name_ko`
- `name_en`
- `product_class_name` = `hsrrlPrdlstCodeNm`
- `product_group_name` = `hsrrlPrdlstCodeLclasNm`
- `is_active`
- `first_seen_at`
- `last_seen_at`

unique 권장:

- `(source_system, source_record_id)`

주의:
`name_ko`는 unique로 잡지 않는 것이 맞습니다. 이름은 중복될 수 있고, 같은 이름의 연도별/버전별 데이터가 존재할 수 있습니다.

#### `feed_reference_aliases`

이름/검색어 확장

- `id`
- `feed_reference_item_id`
- `alias_type` (`ko`, `en`, `legacy_code`, `user_synonym`)
- `alias_value`
- unique: `(feed_reference_item_id, alias_type, alias_value)`

#### `feed_reference_operations`

상세 오퍼레이션 스냅샷 헤더

- `id`
- `feed_reference_item_id`
- `operation_name`
- `source_year`
- `analysis_score`
- `remark`
- `raw_response_id`
- `fetched_at`

예:

- `feedSearchMineralDtl`
- `feedSearchNutritiveDtl`
- `feedSearchChemDtl`

#### `feed_reference_rows`

각 상세 오퍼레이션의 행 구조 저장

- `id`
- `operation_snapshot_id`
- `row_order`
- `row_group_label`
- `row_subgroup_label`
- `row_basis_label`
- `row_key`
- `raw_row_json`

예:

- `gnrlmakemntSeNm`
- `ntrtmpySeNm`
- `ntrtmpyKdlsNm`
- `inorganicMatterSeNm`

를 여기로 흡수

#### `feed_reference_measurements`

가장 중요한 테이블입니다. 모든 영양 필드를 long-format으로 저장합니다.

- `id`
- `feed_reference_row_id`
- `metric_code`
- `metric_label`
- `metric_group`
- `value_numeric`
- `unit`
- `display_order`
- `raw_field_name`

예:

- `metric_code = moisture`
- `raw_field_name = mitrValue`
- `metric_group = general_composition`
- `unit = percent`

이 구조를 쓰면:

- 필드가 추가돼도 스키마 변경이 거의 없음
- 화면별 그룹핑이 쉬움
- 원본 필드코드 보존 가능

## 6. 앱 계산용 투영층

앱은 `feedSearch` 원본 전체를 매번 읽을 필요가 없습니다.

실제 계산에는 소수 필드만 필요합니다.

권장 투영 테이블:

#### `ingredients`

현재 테이블 유지 가능. 다만 수정 필요:

- `name_ko UNIQUE` 제거 권장
- `name_en` 추가
- `source_system` 추가
- `source_record_id` 추가
- `source_feed_no` 추가
- `source_year` 추가
- `product_class_name` 추가
- `product_group_name` 추가

즉 `feed_reference_items`와 연결되는 앱 엔티티로 사용

#### `ingredient_nutrition_versions`

현재 테이블은 유지하되, 용도를 명확히 바꿔야 합니다.

용도:

- 계산 엔진 전용 수치 캐시
- 앱에서 바로 쓰는 정제된 대표값

권장 추가 컬럼:

- `source_operation_snapshot_ids jsonb`
- `basis_type` 예: `dm_basis`, `as_fed_basis`, `canonical`
- `normalization_rule_version`

그리고 수치는 지금처럼 핵심만 남깁니다.

- `moisture_pct`
- `dm_pct`
- `cp_pct_dm`
- `tdn_pct_dm`
- `ndf_pct_dm`
- `adf_pct_dm`
- `ca_pct_dm`
- `p_pct_dm`

필요시 확장:

- `ee_pct_dm`
- `ash_pct_dm`
- `nfc_pct_dm`
- `k_pct_dm`
- `mg_pct_dm`

### 왜 투영층이 필요한가

앱은 아래만 빠르게 계산하면 됩니다.

- 수분
- DM
- CP
- TDN
- NDF
- ADF
- Ca
- P

하지만 원본은 훨씬 복잡합니다. 따라서

- 원본 보존은 `feed_reference_*`
- 계산은 `ingredient_nutrition_versions`

로 분리해야 합니다.

## 7. 추천/설명층

기존 `ingredient_ai_profiles`는 유지해도 됩니다.

다만 원료 검색 OpenAPI만으로는 다음이 충분하지 않을 가능성이 큽니다.

- 정의
- 장점
- 주의점
- 저장성
- 기호성
- 추천 상황
- 피해야 할 상황

따라서 이 테이블은 `feedSearch` 원천과 분리된 수기/큐레이션 데이터로 유지하는 것이 맞습니다.

권장 구조:

#### `ingredient_ai_profiles`

- `ingredient_id`
- `definition`
- `benefits text[]`
- `cautions text[]`
- `storage_note`
- `palatability_note`
- `recommended_stage_notes text[]`
- `avoid_stage_notes text[]`
- `tags jsonb`
- `source_note`
- `updated_at`

## 8. 현재 스키마에서 바꿔야 할 점

### 8.1 `ingredients.name_ko UNIQUE`는 너무 강하다

같은 이름의 다른 연도/버전/출처가 들어올 수 있습니다.

권장:

- `name_ko UNIQUE` 제거
- 대신 `(source_system, source_record_id)`를 유니크로 사용

### 8.2 `ingredient_nutrition_versions`만으로는 원본 손실이 크다

현재 구조는 계산용 캐시로는 적절하지만, `feedSearch` 전체를 저장하는 원본 테이블로는 부적절합니다.

즉 이 테이블은 유지하되 역할을 축소해야 합니다.

### 8.3 원본 응답 보존 테이블이 필요하다

OpenAPI는 언제든 구조가 달라질 수 있습니다.

원본 XML 저장 없이 바로 정제 테이블에만 넣으면:

- 파서 수정
- 신규 필드 추가
- 데이터 품질 감사

가 어려워집니다.

## 9. 수집 전략

### 9.1 전량 수집은 API 특성상 위험할 수 있다

샘플 코드상 목록 조회는 `sText` 검색어 입력을 강제합니다.

즉 이 API는 `전체 덤프용 API`보다 `검색형 API`에 가깝습니다.

이 말은 곧:

- 전체 사료를 한 번에 안정적으로 당겨오는 용도인지 확실하지 않음
- 색인형 대량 수집은 별도 전략이 필요

따라서 권장 수집 전략은 아래 순서입니다.

1. MVP
   - 자주 쓰는 원료만 선별 수집
   - 수기 매핑 포함
2. 확장
   - 검색어 seed 목록 기반 수집
   - 중복 제거/이름 정규화
3. 안정화
   - 관리자 검수 후 `ingredient_nutrition_versions` 투영

### 9.2 수집 파이프라인

권장 파이프라인:

1. 검색어 seed 준비
2. `feedSearchList` 호출
3. `hsrrlManageNo` 확보
4. 상세 8오퍼레이션 호출
5. `feedsearch_raw_responses` 저장
6. 파서로 `feed_reference_*` 적재
7. 계산용 대표값 산출
8. `ingredient_nutrition_versions` 갱신

## 10. 앱 관점에서 최종적으로 필요한 테이블

앱 구현 기준 최소 세트는 아래입니다.

### 원본/관리

- `feedsearch_sync_runs`
- `feedsearch_raw_responses`
- `feed_reference_items`
- `feed_reference_aliases`
- `feed_reference_operations`
- `feed_reference_rows`
- `feed_reference_measurements`

### 앱 계산

- `ingredients`
- `ingredient_nutrition_versions`
- `requirement_profiles`

### 앱 추천/운영

- `ingredient_ai_profiles`
- `farm_ingredient_settings`
- `farm_ingredient_preferences`
- `formulas`
- `formula_items`
- `analysis_runs`
- `recommendations`
- `diary_entries` 또는 사육일지 관련 테이블

## 11. 실무 권장안

가장 현실적인 선택은 아래입니다.

### 권장안 A

`원본 정규화 + 계산용 투영` 2중 구조

장점:

- OpenAPI 필드 손실 최소
- 앱 계산 속도 빠름
- 나중에 성분항목 확장 쉬움

단점:

- 초기 구현이 단순 테이블 1개보다 복잡

### 비권장안 B

처음부터 `ingredients + ingredient_nutrition_versions`에만 바로 적재

문제:

- `analsScoreValue`, `비고`, `행구분`, `추가 영양 필드` 대부분 손실
- 필드 구조가 바뀌면 재적재 어려움
- 샘플 코드의 다행 구조를 표현할 수 없음

## 12. 최종 제안

이 프로젝트에는 아래 구조가 가장 적합합니다.

1. `feedSearch` OpenAPI는 원본 수집층으로 보존
2. 상세 8오퍼레이션은 long-format 측정치 테이블로 정규화
3. 앱 계산에는 별도의 `ingredient_nutrition_versions` 투영 사용
4. 추천/설명은 `ingredient_ai_profiles`로 분리 유지
5. 현재 스키마는 유지하되, `feed_reference_*` 계열을 새로 추가하는 방향으로 확장

즉 정리하면:

- `feedSearch API`는 원천 데이터 저장소
- `ingredients / ingredient_nutrition_versions`는 앱 계산 캐시
- `ingredient_ai_profiles`는 추천 지식층

이 3층으로 가는 것이 가장 안전합니다.

## 13. 다음 작업 우선순위

1. 현재 `docs/db/schema.sql`을 기준으로 `feed_reference_*` 계열 테이블 추가안 작성
2. `ingredients`와 `ingredient_nutrition_versions` 수정 마이그레이션 초안 작성
3. `feedSearch` 필드코드 -> 내부 metric dictionary 매핑표 작성
4. seed 수집용 검색어 목록 설계

