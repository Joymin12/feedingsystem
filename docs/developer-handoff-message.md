# Developer Handoff Message

Use this message when handing the project to an external iOS/refactor developer.

```text
Hi, please review and refactor the Hanufit iOS project.

Project summary:
Hanufit is a Hanwoo TMR/TMF ration analysis app. Users enter formula ingredients in as-fed kg. The app converts each ingredient to dry-matter kg, calculates CP, TDN, EE, NDF, ADF, Ca, P, Ca:P, and moisture, classifies the result against growth-stage criteria, and shows one composite correction recommendation.

Important product rule:
The first release must remain an iOS-local calculation/recommendation app. Do not make server/Supabase or AI API calls mandatory for the core calculation flow. AI may assist with explanation later, but final nutrient values, status classification, and recommendation validation must come from the app engine.

Please read these documents in order:

1. README.md
   - Overall repository structure, run instructions, current scope, and release direction.

2. docs/ios-refactor-handoff.md
   - Most important document for your task. It explains the current iOS structure, required calculation rules, user-entered ingredients, refactor priorities, and what must not change.

3. docs/architecture.md
   - Current system architecture and layer boundaries. It defines the iOS local engine, data boundaries, AI responsibility, recommendation boundary, and server migration criteria.

4. docs/launch-architecture-refactor-plan.md
   - Step-by-step pre-release refactor plan. Use this as the execution roadmap.

5. docs/tmr-recommendation-engine-developer-brief.md
   - Calculation and recommendation engine details. It includes dry-matter formulas, growth-stage nutrient criteria, recommendation policy, AI role, and expected output shape.

6. docs/release-app-delivery.md
   - Release app scope, UI/reference files, ingredient DB policy, and current operating mode.

7. docs/user-auth-and-ingredient-scope.md
   - Local auth, user ingredient selection, community permissions, and current local persistence limitations.

8. docs/qa/checklists.md
   - Review checklist for calculation, recommendation, frontend, DB, and core user scenarios.

Reference-only documents:

- docs/seeds/README.md
  - Ingredient seed/source DB rules.

- docs/feedsearch-db-design-plan.md
  - Future feedSearch OpenAPI ingestion design. Do not prioritize this for the first release.

- docs/supabase/supabase-auth-community-setup.md
  - Optional future Supabase auth/community setup. Not required for the first release path.

Code files to inspect first:

1. apps/ios/HanwooPrototype/HanwooPrototype/HanwooPrototypeApp.swift
   - Current largest file. Contains app entry, PrototypeStore, auth, screens, user ingredient management, and several user flows. Main refactor target.

2. apps/ios/HanwooPrototype/HanwooPrototype/DomainModels.swift
   - Domain models and growth-stage criteria. Do not change calculation criteria without explicit approval.

3. apps/ios/HanwooPrototype/HanwooPrototype/IngredientCatalog.swift
   - App-side ingredient catalog.

4. apps/ios/HanwooPrototype/HanwooPrototype/PrototypeStore+CalculationEngine.swift
   - Current dry-matter based calculation engine.

5. apps/ios/HanwooPrototype/HanwooPrototype/PrototypeStore+CorrectionEngine.swift
   - Current recommendation/correction engine.

6. apps/ios/HanwooPrototype/HanwooPrototype/RecommendationViews.swift
   - Recommendation UI.

7. apps/ios/HanwooPrototype/HanwooPrototype/DesignSystem.swift
   - Shared UI tokens/components.

Refactor target architecture:
Use MVVM + UseCase/Engine/Repository.

Priority:
1. Split ingredient selection, custom ingredient input, and my-ingredient management screens.
2. Split formula editing and analysis screens.
3. Split PrototypeStore into Session/Formula/Ingredient/Community/Diary responsibilities.
4. Extract CalculationEngine as a pure type.
5. Extract CorrectionEngine as a pure type.
6. Hide UserDefaults persistence behind Repository protocols.

Do not change these behaviors:
- User input is as-fed kg.
- Nutrient averages are dry-matter weighted.
- User-entered USER_... ingredients are calculation-ready and recommendation-ready.
- The primary recommendation should use ingredients already present in the formula.
- Final recommended total as-fed kg should match the user's original total kg after normalization.
- AI must not invent final nutrient values.
- Supabase/server should remain optional for this release.

Verification after refactor:
- Xcode build must pass.
- Add/edit/delete user ingredients must still affect calculation.
- Representative formulas should still generate one primary recommendation.
- Check Gyeonggi TMR 3000kg, CP excess, TDN excess, CP deficiency, and EE excess + CP deficiency scenarios.
```
