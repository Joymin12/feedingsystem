# Hanufit iOS Refactor Handoff

## Purpose

The current iOS app was built quickly to validate release-oriented features. As a result, `HanwooPrototypeApp.swift` still contains screens, state, persistence, and several user flows. The next developer should not change product behavior first. The priority is to preserve existing calculation and recommendation results while separating the boundaries between View, State, Engine, and Data.

## One-Line Project Description

Hanufit is an iOS app that calculates Hanwoo TMR/TMF ration inputs on a dry-matter basis, classifies them against growth-stage nutrient targets, and produces one composite correction recommendation centered on the user's existing ingredients.

## Current Core User Flow

1. The user enters formula ingredients and as-fed kg.
2. The app calculation engine converts as-fed kg to dry-matter kg.
3. The app calculates CP, TDN, EE, NDF, ADF, Ca, P, Ca:P, and moisture.
4. The app classifies each value as deficient, caution, adequate, or excess according to growth-stage criteria.
5. The correction engine generates ingredient increase/decrease actions and the app engine recalculates them.
6. The user sees the projected result and explanation.
7. The user can manually enter an ingredient nutrition profile from a feed analysis report in the ingredient-add screen.
8. The user can edit/delete custom ingredients in `My Farm > My Ingredients`.

## Calculation Rules That Must Be Preserved

- User input is as-fed kg.
- Nutrient averages are calculated on a dry-matter basis.
- `DM% = 100 - moisture%`
- `ingredient DM kg = as-fed kg * DM% / 100`
- `nutrient %DM = sum(ingredient DM kg * ingredient nutrient %DM) / total DM kg`
- Moisture is calculated from total as-fed mass.
- User-entered ingredients must be converted to `IngredientDefinition` and included in calculation/recommendation like catalog ingredients.
- Only ingredients with a `definitionID` can participate in calculation/recommendation.

## Current File Responsibilities

- `apps/ios/HanwooPrototype/HanwooPrototype/HanwooPrototypeApp.swift`
  - Largest file.
  - Contains app entry, `PrototypeStore`, auth/sign-up, formula screens, farm screen, community, ingredient selection/add/manage screens.
  - Highest-priority refactor target.

- `apps/ios/HanwooPrototype/HanwooPrototype/DomainModels.swift`
  - Growth-stage criteria, ingredient category, ingredient definition, user ingredient, formula, analysis, recommendation domain models.
  - Keep stable unless calculation criteria are intentionally changed.

- `apps/ios/HanwooPrototype/HanwooPrototype/IngredientCatalog.swift`
  - App-side catalog/seed.
  - User-entered ingredients should not be written here. They are stored separately as `UserIngredientDefinition`.

- `apps/ios/HanwooPrototype/HanwooPrototype/PrototypeStore+CalculationEngine.swift`
  - Formula nutrient calculation.
  - Good candidate for extraction into a pure `CalculationEngine`.

- `apps/ios/HanwooPrototype/HanwooPrototype/PrototypeStore+CorrectionEngine.swift`
  - Recommendation/composite correction generation.
  - Good candidate for extraction into `RecommendationEngine` or `CorrectionUseCase`.

- `apps/ios/HanwooPrototype/HanwooPrototype/RecommendationViews.swift`
  - Recommendation UI.
  - Already partially separated; use it as a reference for view splitting.

- `apps/ios/HanwooPrototype/HanwooPrototype/DesignSystem.swift`
  - Shared colors, cards, buttons, badges, and UI components.

- `apps/ios/HanwooPrototype/HanwooPrototype/SupabaseService.swift`
  - Experimental Supabase adapter.
  - Do not make the first release depend on server connectivity.

## Recently Added User Ingredient Feature

### Model

- `UserIngredientDefinition`
- ID format: `USER_<UUID>`
- Fields:
  - `ownerLoginID`
  - `name`
  - `category`
  - `defaultPriceKrwPerKg`
  - `nutrition`
  - `createdAt`

### Persistence

- Currently saved in `UserDefaults` under `hanwoo.prototype.userIngredients`.
- For production, place this behind a Repository and later migrate to SwiftData/CoreData or server sync.

### Calculation Link

- `PrototypeStore.ingredientDefinition(id:)` first looks up the base catalog, then user ingredients.
- Both the calculation engine and correction engine resolve nutrition through this path, so user ingredients are calculation-ready.

### Screens

- Formula ingredient add sheet:
  - `IngredientPickerSheet`
  - `CustomIngredientInputView`
- My ingredient management:
  - `UserIngredientManagementView`
  - `UserIngredientEditView`

## Recommended Architecture

Use `MVVM + UseCase/Engine/Repository`.

```text
Views
  -> ViewModels
    -> UseCases
      -> Engines
      -> Repositories
```

### Separation Goals

- Views handle display and user input only.
- ViewModels handle screen state, validation, and action dispatch.
- UseCases handle user-flow-level operations.
- Engines handle pure calculation/recommendation.
- Repositories handle persistence and data access.

## Refactor Priority

1. Split `PrototypeStore` into domain-specific Stores/ViewModels:
   - `SessionStore`
   - `FormulaStore`
   - `IngredientStore`
   - `CommunityStore`
   - `DiaryStore`

2. Move ingredient-related screens to separate files:
   - `IngredientPickerSheet`
   - `IngredientCategoryListView`
   - `CustomIngredientInputView`
   - `UserIngredientManagementView`
   - `UserIngredientEditView`

3. Move formula screens to separate files:
   - `BlendView`
   - `FormulaDetailView`
   - `IngredientAmountEditor`

4. Extract the calculation engine into a pure type:
   - Target: `CalculationEngine.calculate(formula, ingredientProvider) -> AnalysisMetrics`
   - It must not depend on SwiftUI, `@Published`, or `UserDefaults`.

5. Extract the correction engine into a pure type:
   - Target: `CorrectionEngine.recommend(formula, stage, ingredientProvider) -> [Recommendation]`
   - Preserve the flow where generated recommendations are recalculated and validated by the app engine.

6. Put persistence behind Repository protocols:
   - `IngredientRepository`
   - `FormulaRepository`
   - `UserRepository`
   - Initial implementation may still use UserDefaults, but later SwiftData/Supabase migration must not require engine rewrites.

## Message To Give The Refactor Developer

Use this exact request:

```text
Please refactor the Hanufit iOS app into a release-ready structure.

The app is SwiftUI-based, and `HanwooPrototypeApp.swift` currently contains too many Views, Store logic, and user flows. The target architecture is MVVM + UseCase/Engine/Repository.

Do not change calculation results or recommendation behavior during the first refactor pass. The current domain rules must be preserved: user input is as-fed kg, the app converts to dry-matter kg, and CP/TDN/EE/NDF/ADF/Ca/P/Ca:P/moisture are classified against growth-stage criteria.

User-entered ingredients with `USER_...` IDs must remain calculation-ready and recommendation-ready like catalog ingredients. Preserve the current `ingredientDefinition(id:)` lookup behavior, or replace it with an equivalent Repository/Provider.

Refactor priority:
1. Separate ingredient selection, direct ingredient input, and my-ingredient management screens.
2. Separate formula editing screens.
3. Split `PrototypeStore` into Session/Formula/Ingredient/Community/Diary responsibilities.
4. Extract `CalculationEngine` as a pure calculation type.
5. Extract `CorrectionEngine` as a pure recommendation type.
6. Hide UserDefaults persistence behind Repository protocols.

After refactoring, verify that the Gyeonggi TMR 3000kg test formula, CP excess, TDN excess, CP deficiency, and EE excess + CP deficiency scenarios still produce similar analysis values and a primary recommendation.
```

## Do Not Do During Refactor

- Do not change calculation formulas without explicit approval.
- Do not change growth-stage criteria without explicit approval.
- Do not revert user-entered ingredients to calculation-excluded custom lines.
- Do not use `definitionID == nil` ingredients as recommendation candidates.
- Do not let AI invent calculated nutrient values.
- Do not make server/Supabase connectivity mandatory for the first release.

## Refactor Completion Criteria

- `HanwooPrototypeApp.swift` only contains app entry and high-level composition.
- View files, ViewModels, UseCases, Engines, and Repositories have clear boundaries.
- Xcode build passes.
- Adding/editing/deleting user ingredients still affects formula calculation.
- The primary recommendation is generated for representative test formulas.
- Storage can be changed without rewriting calculation or recommendation engines.
