# Pre-Release Architecture Refactor Plan

## Purpose

The current app was built quickly to validate features, so one large SwiftUI file still contains screens, state, domain flow, and some shared components. Before release, responsibilities must be separated so UI changes do not affect the calculation engine and recommendation changes do not break screens.

## Work Completed

- Moved domain models out of `HanwooPrototypeApp.swift`.
- Added `DomainModels.swift`.
- Moved shared UI components to `DesignSystem.swift`.
- Updated user-entered ingredients so they are stored as `USER_...` ingredient definitions with nutrition profiles.
- Extended `ingredientDefinition(id:)` lookup so user-entered ingredients participate in calculation and recommendation simulation.
- Added `My Farm > My Ingredients` for editing/deleting user-entered ingredients.
- Added the developer handoff document `docs/ios-refactor-handoff.md`.
- Added `DomainModels.swift` to the Xcode project Sources build phase.
- Added `DesignSystem.swift` to the Xcode project Sources build phase.
- Rewrote `architecture.md` around the iOS local release architecture.
- Updated `release-app-delivery.md` around the one-primary-recommendation policy.
- Rewrote `tmr-recommendation-engine-developer-brief.md` around the current AI/recommendation-engine responsibilities.

## Current File Responsibilities

| File | Current Responsibility | Next Refactor Direction |
| --- | --- | --- |
| `HanwooPrototypeApp.swift` | Store, app entry, many screens, some shared UI | Split into feature View files and Store files |
| `DomainModels.swift` | Growth stages, criteria, ingredients, formulas, analysis, recommendations, user models | Keep stable |
| `DesignSystem.swift` | Colors, background, cards, badges, shared display components | Keep; expand tokens after final design direction |
| `PrototypeStore+CalculationEngine.swift` | Nutrition calculation and status classification | Move toward a pure calculation utility with lower Store dependency |
| `PrototypeStore+CorrectionEngine.swift` | Candidate generation, simulation, recommendation selection | Align with current-formula-only, total-kg normalization, one-primary policy |
| `IngredientCatalog.swift` | App-side calculation catalog | Keep source DB vs app catalog boundary documented |
| `UserIngredientDefinition` | User-entered ingredient nutrition profile | Move behind user ingredient Repository during server/storage migration |
| `RecommendationViews.swift` | Recommendation UI | Simplify around one primary recommendation |
| `SupabaseService.swift` | Optional Supabase integration | Keep optional/disabled for first release |

Use `docs/ios-refactor-handoff.md` as the primary handoff document for an external refactor developer.

## Refactor Phases

### Phase 1. Domain And Documentation Boundary

Completion criteria:

- Domain models are separated from screen code.
- Release architecture documentation reflects the iOS local engine direction.
- Recommendation engine policy documentation matches the current product decisions.

Status: in progress; first separation pass completed.

### Phase 2. Freeze Recommendation Policy In Code

Tasks:

- Limit recommendation candidates to ingredient lines actually entered in the current formula.
- Exclude new `add` ingredients from the default primary recommendation.
- Normalize internally simulated totals back to the original user-entered total as-fed kg.
- Return only one primary recommendation.
- Remove fallback UI concepts such as "ration redesign review" and "alternative options" from the primary flow.

Completion criteria:

- Final recommended total as-fed kg equals the user's input total as-fed kg.
- All recommendation actions refer to ingredients present in the current formula.
- UI displays only one primary recommendation.

### Phase 3. Split Views

Targets:

- `HomeView`
- `FormulaEditorView`
- `AnalysisView`
- `HistoryView`
- `DiaryView`
- `FarmView`
- `CommunityView`
- `AuthView`
- `IngredientPickerView`
- `UserIngredientManagementView`
- Shared card, badge, and form components

Completion criteria:

- `HanwooPrototypeApp.swift` only handles app entry and top-level composition.
- Screen changes do not require editing calculation or recommendation engine files.

### Phase 4. Split Store

Targets:

- `FormulaStore`
- `AnalysisStore`
- `DiaryStore`
- `CommunityStore`
- `AuthStore`
- `IngredientSelectionStore`

Completion criteria:

- Screen state and calculation-engine inputs have clear boundaries.
- Future server migration points are concentrated in `Service` or `Repository` layers.

### Phase 5. Release Validation

Validation targets:

- Growth-stage criteria classification.
- As-fed kg to DM kg conversion.
- CP, TDN, EE, NDF, ADF, Ca, P, Ca:P, and moisture calculation.
- Gyeonggi TMR 3000kg formula.
- CP excess, TDN excess, CP deficiency, EE excess + CP deficiency cases.
- Projected result after recommendation.
- Moisture classification: `40-45% adequate`, `36-<40% / >45-49% caution`, `<=35% deficient`, `>=50% excess`.

Completion criteria:

- Build succeeds.
- Representative test formulas generate composite correction plans, not single-ingredient suggestions only.
- Recommended final total kg equals the original input total kg.
- Pre-release limitations and validation results are documented.

## Immediate Next Steps

1. Run Xcode build after model separation.
2. Remove `add`-based primary recommendation behavior and multi-strategy selection from the recommendation engine.
3. Remove alternative-option and redesign-review language from the recommendation UI.
4. Start splitting `FormulaEditorView`, `AnalysisView`, and `HistoryView`.
