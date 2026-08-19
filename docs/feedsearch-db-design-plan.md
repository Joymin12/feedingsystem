# feedSearch OpenAPI DB Design Plan

Created: 2026-04-28

## Summary

The `feedSearch` OpenAPI should not be modeled as a simple table where one ingredient equals one row of moisture/CP/TDN values.

The service is structurally more complex:

- One list operation.
- Eight detail operations.
- Each detail operation returns different nutrient groups and row categories.
- Some detail operations may return two or three grouped rows for one ingredient.
- Metadata such as analysis score, note, and category labels can appear together with component values.

Recommended storage design:

1. `raw collection layer`
   - Preserve full OpenAPI responses.
2. `normalized storage layer`
   - Normalize ingredient identity, row categories, and measured components.
3. `app projection layer`
   - Produce calculation-ready nutrition profiles for the app.

The current `ingredients + ingredient_nutrition_versions` concept is not enough to preserve the full `feedSearch` raw structure.

## API Structure

Service name: `feedSearch`

Operations:

- `feedSearchList`
- `feedSearchInfoDtl`
- `feedSearchMineralDtl`
- `feedSearchNutritiveDtl`
- `feedSearchDigestDtl`
- `feedSearchAminoDtl`
- `feedSearchVitaminDtl`
- `feedSearchCellDtl`
- `feedSearchChemDtl`

List endpoint:

- `http://api.nongsaro.go.kr/service/feedSearch/feedSearchList`

Common list request parameters:

- `apiKey`
- `sType`
- `sText`
- `pageNo`

Common list response fields:

- `hsrrlManageNo`
- `hsrrlNo`
- `koreanNm`
- `engNm`
- `hsrrlPrdlstCodeLclasNm`
- `numOfRows`
- `pageNo`
- `totalCount`

Detail records are fetched by `hsrrlManageNo` across the eight detail operations.

## Recommended Tables

### Raw Layer

`feedsearch_raw_responses`

- `id`
- `operation_name`
- `request_params`
- `response_body`
- `fetched_at`
- `source_version`

Purpose:

- Preserve exact API responses.
- Allow re-normalization if mapping rules change.
- Avoid losing row groups or notes not used by the current app.

### Normalized Identity Layer

`feedsearch_ingredients`

- `id`
- `hsrrl_manage_no`
- `hsrrl_no`
- `korean_name`
- `english_name`
- `large_category_name`
- `product_category_name`
- `source_year`
- `created_at`
- `updated_at`

Purpose:

- Keep stable ingredient identity separately from nutrition values.

### Normalized Measurement Layer

`feedsearch_component_values`

- `id`
- `ingredient_id`
- `operation_name`
- `row_category_name`
- `component_code`
- `component_name`
- `value`
- `unit`
- `analysis_score`
- `note`
- `source_payload_ref`
- `created_at`

Purpose:

- Store every nutrient/component value with its source operation and row category.
- Preserve multiple rows per ingredient.
- Preserve metadata needed for review.

### App Projection Layer

`ingredient_nutrition_profiles`

- `id`
- `ingredient_id`
- `profile_version`
- `dm_pct`
- `moisture_pct`
- `cp_pct_dm`
- `tdn_pct_dm`
- `ee_pct_dm`
- `ndf_pct_dm`
- `adf_pct_dm`
- `nfc_pct_dm`
- `ash_pct_dm`
- `ca_pct_dm`
- `p_pct_dm`
- `mapping_status`
- `review_required`
- `created_at`

Purpose:

- Provide app-ready values for calculation.
- Keep incomplete or ambiguous source ingredients out of calculation until reviewed.
- Separate source preservation from release app behavior.

## App Integration Policy

- Do not connect the iOS first release directly to `feedSearch`.
- Use curated app catalog data for local calculation.
- Use `feedSearch` as a future source DB ingestion path.
- Do not auto-merge field names with canonical ingredients without review.
- Keep missing source values as `null` in source/raw layers.
- If the app catalog needs a non-optional value, document whether `0` is a true value or a placeholder.

## Promotion Criteria From Source To App Catalog

An ingredient can be promoted to app calculation use only when:

- Moisture or DM is available.
- CP and TDN are available or intentionally reviewed.
- Ca and P are available if mineral balance is required.
- NDF/ADF availability is reviewed for fiber classification.
- The ingredient name has been reviewed to avoid incorrect canonical matching.

## Current Product Direction

For the first release, this document is reference-only. The app currently uses:

- `IngredientCatalog.swift` for local app calculation.
- `ingredients.source.extensions.final.json` for source DB extension records.
- `UserIngredientDefinition` for user-entered feed analysis values.

Server ingestion from `feedSearch` should start only after the local iOS engine and app catalog policies are stable.
