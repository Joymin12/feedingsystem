# Pre-Release System Architecture

## Target Structure

The first release is based on an `iOS local calculation and correction engine`, not server-side calculation. The app receives an as-fed kg ration from the user, converts it to a dry-matter basis, compares the result against growth-stage criteria, classifies each nutrient as `deficient / caution / adequate / excess`, and shows one composite correction plan.

AI does not produce final nutrient values. AI may assist with candidate adjustment direction and user-facing explanation, but the final recommendation shown to the user must be recalculated and validated by the app engine.

## App Layers

| Layer | Responsibility | Current File |
| --- | --- | --- |
| App Shell / Screen Composition | App entry point, tab flow, temporary screen containers | `/Users/jowm/Desktop/feedingsystem/apps/ios/HanwooPrototype/HanwooPrototype/HanwooPrototypeApp.swift` |
| Domain Models | Growth stages, criteria, ingredients, formulas, analysis, recommendations, user models | `/Users/jowm/Desktop/feedingsystem/apps/ios/HanwooPrototype/HanwooPrototype/DomainModels.swift` |
| Store / State | Local state, persistence, auth fallback, screen actions | `/Users/jowm/Desktop/feedingsystem/apps/ios/HanwooPrototype/HanwooPrototype/HanwooPrototypeApp.swift` |
| Calculation Engine | As-fed kg to DM kg conversion, weighted nutrient averages, status classification | `/Users/jowm/Desktop/feedingsystem/apps/ios/HanwooPrototype/HanwooPrototype/PrototypeStore+CalculationEngine.swift` |
| Correction Engine | Composite correction generation, simulation, recommendation selection | `/Users/jowm/Desktop/feedingsystem/apps/ios/HanwooPrototype/HanwooPrototype/PrototypeStore+CorrectionEngine.swift` |
| Recommendation UI | Recommendation card, projected result, action display | `/Users/jowm/Desktop/feedingsystem/apps/ios/HanwooPrototype/HanwooPrototype/RecommendationViews.swift` |
| Ingredient Catalog | App-side ingredient catalog for calculation | `/Users/jowm/Desktop/feedingsystem/apps/ios/HanwooPrototype/HanwooPrototype/IngredientCatalog.swift` |
| User Ingredients | User-entered ingredient nutrition profiles and local persistence | `/Users/jowm/Desktop/feedingsystem/apps/ios/HanwooPrototype/HanwooPrototype/DomainModels.swift`, `/Users/jowm/Desktop/feedingsystem/apps/ios/HanwooPrototype/HanwooPrototype/HanwooPrototypeApp.swift` |
| Optional Backend Adapter | Supabase integration candidate; disabled by default for the current release path | `/Users/jowm/Desktop/feedingsystem/apps/ios/HanwooPrototype/HanwooPrototype/SupabaseService.swift` |

## Data Boundaries

- `source DB`: Raw preservation layer. Allows `null`, field names, and independent ingredient entries.
- `app catalog`: Swift-side ingredient catalog used directly by the iOS app.
- `API seed`: Curated seed for a future server migration. Not required for the first release.

The current policy keeps ingredients with `0` values in the app catalog and does not exclude them from recommendation candidates. Long-term, it would be safer to make nutrition profiles optional so the app can distinguish a true zero from a zero used to fill missing data.

User-entered ingredients are saved as separate ingredient definitions with `USER_...` IDs. User-entered moisture, CP, TDN, EE, NDF, ADF, NFC, ash, Ca, and P values are used in calculation and recommendation simulation the same way as catalog ingredient values. The app must not store name-only custom ingredients that are excluded from calculation.

## Recommendation Engine Boundary

Release recommendation policy:

- Show only one primary recommendation.
- Candidate ingredients are limited to ingredient lines actually entered in the current formula.
- The default recommendation must not add a new ingredient in kg just because it exists in the app DB.
- Internal simulation may temporarily increase or decrease total as-fed kg.
- Before display, the final output must be normalized back to the user's original total as-fed kg and recalculated.
- There is no maximum increase/decrease limit. Ingredient kg must never become negative.
- Ca/P/mineral adjustment is allowed only if the relevant mineral ingredient is already present in the formula.
- Moisture is not a hard first-priority constraint; it is handled through risk explanation.
- Moisture classification is `40-45% adequate`, `36-<40% / >45-49% caution`, `<=35% deficient`, `>=50% excess`.
- Explanations must describe composite tradeoffs, not single-cause claims such as "rice bran was reduced only because it increased EE."

## AI Responsibility

AI may:

- Suggest candidate adjustment directions based on current classification.
- Explain engine-validated recommendations in farmer-friendly language.
- Connect cause and action, such as "increase protein sources because CP is low" or "check storage stability because moisture is high."

AI must not:

- Invent or estimate final CP, TDN, EE, NDF, ADF, Ca, P, Ca:P, or moisture values.
- Override the app engine's deficient/caution/adequate/excess classification.
- Add an ingredient that is not in the current formula as the default primary recommendation.
- Show an unvalidated recommendation as final.

## Refactor Direction

The largest current technical debt is that `HanwooPrototypeApp.swift` still contains Store logic, screens, and some shared UI. The pre-release structure should be split in this order:

1. Separate domain models.
2. Split views into feature-specific files.
3. Split Store responsibilities into auth, formula, diary, community, and regression state.
4. Move calculation and recommendation engines toward pure functions with low Store dependency.
5. Freeze the recommendation policy: current formula ingredients only, normalize to original total kg, one primary recommendation.
6. Validate recommendation direction with at least five regression formulas.

## Server Migration Criteria

Server/NestJS/PostgreSQL migration is not the current priority. Start it only after:

- Growth-stage criteria are stable.
- Source DB, app catalog, and API seed boundaries are stable.
- The iOS local engine reproduces analysis and recommendation results on regression formulas.
- AI responsibility is fixed as explanation/candidate assistance.

When server migration starts, split APIs in this order: `/analysis`, `/recommendations`, `/formulas`, `/ingredients`.
