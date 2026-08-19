# Hanufit TMR Release App Delivery

## Purpose

This project is a field-oriented iOS app that combines Hanwoo TMR formula entry, nutrient analysis, composite correction recommendation, and diary/history flows.

Core principles:

- Users enter formulas in as-fed kg.
- Internal calculation is dry-matter based.
- Nutrients are classified by growth-stage criteria as adequate, caution, deficient, or excess.
- The recommendation is one primary composite correction plan, not a single-ingredient suggestion.
- AI is for explanation assistance; the correction plan itself is decided and verified by the calculation engine.

## Current Release Screen Scope

Core screens:

- Home
- Formula entry
- Analysis result
- Recommendation
- Recent analysis
- Diary
- My Farm
- Engine regression verification

The current UI direction uses:

- Light olive/cream background.
- Large rounded cards.
- Dashboard-like hero sections.
- Status badges and metric tiles.
- Clear hierarchy in recommendation cards.

## Figma Output

Release-oriented screen references were created in Figma.

- File: [Hanwoo TMR Release App Screens](https://www.figma.com/design/s0zgQbmYcZb1yF7gAJNMfx)

Current screens:

- Home
- Formula
- Analysis result
- Recommendation

Purpose:

- Visual reference for release demo.
- Baseline for further design refinement.
- Shared reference for development/design communication.

## Code Reference Files

Domain models:

- `/Users/jowm/Desktop/feedingsystem/apps/ios/HanwooPrototype/HanwooPrototype/DomainModels.swift`

Shared design system:

- `/Users/jowm/Desktop/feedingsystem/apps/ios/HanwooPrototype/HanwooPrototype/DesignSystem.swift`

Core app UI:

- `/Users/jowm/Desktop/feedingsystem/apps/ios/HanwooPrototype/HanwooPrototype/HanwooPrototypeApp.swift`
- `/Users/jowm/Desktop/feedingsystem/apps/ios/HanwooPrototype/HanwooPrototype/RecommendationViews.swift`

Ingredient catalog:

- `/Users/jowm/Desktop/feedingsystem/apps/ios/HanwooPrototype/HanwooPrototype/IngredientCatalog.swift`

User-entered ingredients:

- `/Users/jowm/Desktop/feedingsystem/apps/ios/HanwooPrototype/HanwooPrototype/DomainModels.swift`
- `/Users/jowm/Desktop/feedingsystem/apps/ios/HanwooPrototype/HanwooPrototype/HanwooPrototypeApp.swift`

Recommendation engine developer brief:

- `/Users/jowm/Desktop/feedingsystem/docs/tmr-recommendation-engine-developer-brief.md`

Optional Supabase auth/community setup:

- `/Users/jowm/Desktop/feedingsystem/docs/supabase/supabase-auth-community-setup.md`
- `/Users/jowm/Desktop/feedingsystem/docs/supabase/schema.sql`

Ingredient category table:

- `/Users/jowm/Desktop/feedingsystem/docs/seeds/final-ingredient-category-groups.json`

Source ingredient extension DB:

- `/Users/jowm/Desktop/feedingsystem/docs/seeds/ingredients.source.extensions.final.json`

## Ingredient DB Operating Principles

- Keep existing `1-114` ingredients and new `200-223` ingredients together.
- Do not automatically match or merge field-name ingredients with canonical ingredients.
- Include new ingredients as recommendation candidates.
- Store user-entered ingredients with `USER_...` IDs and include them in calculation/recommendation candidates.
- User-entered ingredients allow direct input of moisture, CP, TDN, EE, NDF, ADF, NFC, ash, Ca, and P.
- Preserve the raw source DB separately.
- Some non-optional app catalog nutrition fields may use `0`, but source data should remain separately preserved.

## Recommendation Engine Principles

- Recommendations must be composite correction plans.
- Show only one primary recommendation to the user.
- Default candidates are limited to ingredient lines actually entered in the user's formula.
- Do not add new ingredients in kg to the default primary recommendation.
- Internal simulation may change total as-fed mass, but final display must be normalized back to the user's original total as-fed kg.
- Moisture is not a hard first-priority condition; explain high/low moisture risk instead.
- Example action format:
  - `Rice bran -20kg`
  - `Cracked corn +12kg`
  - `Soybean meal +3kg`
- The projected result must show nutrient status after applying the recommendation.

## Current Operating Mode

- First release is based on the `local iOS app`.
- Auth, community, and user ingredient selection currently use local fallback behavior.
- Supabase code remains in the repository, but it is not part of the current release path.
- Formula calculation and composite correction recommendation remain local engine responsibilities.

## Documents Developers Should Read First

For continuing recommendation engine and formula correction work, read in this order:

1. `/Users/jowm/Desktop/feedingsystem/docs/ios-refactor-handoff.md`
2. `/Users/jowm/Desktop/feedingsystem/docs/architecture.md`
3. `/Users/jowm/Desktop/feedingsystem/docs/tmr-recommendation-engine-developer-brief.md`
4. `/Users/jowm/Desktop/feedingsystem/docs/user-auth-and-ingredient-scope.md`
5. `/Users/jowm/Desktop/feedingsystem/docs/seeds/final-ingredient-category-groups.json`
6. `/Users/jowm/Desktop/feedingsystem/docs/seeds/ingredients.source.extensions.final.json`
7. `/Users/jowm/Desktop/feedingsystem/docs/seeds/README.md`
8. `/Users/jowm/Desktop/feedingsystem/docs/seeds/ingredient-db-normalization-policy.json`

Optional reference:

- `/Users/jowm/Desktop/feedingsystem/docs/supabase/supabase-auth-community-setup.md`
- `/Users/jowm/Desktop/feedingsystem/docs/supabase/schema.sql`

## Intentionally Not Done In This Pass

- New automated tests.
- Regression suite cleanup.
- Server migration.
- API DTO implementation.
- App Store metadata preparation.

## Immediate Next Work

- Split remaining screens and Store state out of `HanwooPrototypeApp.swift`.
- Freeze the recommendation engine policy in code: current formula ingredients only, normalize to original total kg, one primary recommendation.
- Re-check how new `200-223` ingredients appear in recommendation simulation.
- Review actual usability of save, recent analysis, and diary flows.
