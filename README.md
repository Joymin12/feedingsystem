# Hanufit Hanwoo TMR Recommendation App

Hanufit is an iOS app for Hanwoo TMR/TMF ration analysis and composite correction recommendations. The first release is intentionally based on a local iOS calculation and correction engine, without requiring a backend server. User-entered ingredient nutrition profiles are treated as calculation-ready ingredients and are included in analysis and recommendation simulation.

## Repository Structure

- `apps/ios`: SwiftUI iOS app.
- `apps/ios/HanwooPrototype/HanwooPrototype/DomainModels.swift`: Growth-stage criteria, ingredient, formula, analysis, recommendation, and user domain models.
- `apps/ios/HanwooPrototype/HanwooPrototype/IngredientCatalog.swift`: App-side ingredient catalog for local calculation.
- `apps/ios/HanwooPrototype/HanwooPrototype/PrototypeStore+CalculationEngine.swift`: Dry-matter based nutrition calculation.
- `apps/ios/HanwooPrototype/HanwooPrototype/PrototypeStore+CorrectionEngine.swift`: Composite ration correction engine.
- `apps/ios/HanwooPrototype/HanwooPrototype/RecommendationViews.swift`: Recommendation UI.
- `docs/architecture.md`: Current system architecture.
- `docs/ios-refactor-handoff.md`: Refactor handoff document for iOS developers.
- `docs/launch-architecture-refactor-plan.md`: Pre-release architecture refactor plan.
- `docs/tmr-recommendation-engine-developer-brief.md`: Calculation and recommendation engine developer brief.
- `docs/release-app-delivery.md`: Release-app implementation direction.
- `docs/seeds`: Ingredient seed files and DB normalization policies.

## Current Scope

- Local sign-up and login flow.
- User-specific ingredient selection.
- User-entered ingredient add/edit/delete.
- As-fed kg based ration editing.
- Dry-matter based CP, TDN, EE, NDF, ADF, Ca, P, Ca:P, and moisture calculation.
- Growth-stage status classification: deficient, caution, adequate, excess.
- Composite correction recommendation using existing formula ingredients first.
- Recent analysis, diary, and community baseline flows.

## Development Principles

- The first release uses the iOS local calculation engine as the source of truth.
- Server and Supabase work should remain optional until the local engine and UX are stable.
- User input is as-fed kg; nutrient averaging is done on a dry-matter basis.
- User-entered ingredients must be included in calculation and recommendation the same way as catalog ingredients.
- AI must not invent final nutrient values. AI may assist with candidate direction and explanation, but final calculation, classification, and recommendation validation must be performed by the app engine.

## Requirements

- Node.js 20 or later recommended.
- pnpm 10.7.0.
- iOS app execution requires macOS and Xcode.
- Windows can run API/domain/typecheck/test workflows, but cannot run iOS Simulator directly.

## Setup

Node packages remain for future API/domain work. They are not required just to open the iOS app in Xcode.

```bash
cd feedingsystem
corepack enable
corepack pnpm install
```

## Verification Commands

```bash
corepack pnpm typecheck
corepack pnpm test
corepack pnpm build
```

## Run The iOS App On macOS

Open the Xcode project:

```bash
open apps/ios/HanwooPrototype/HanwooPrototype.xcodeproj
```

In Xcode:

1. Select an iPhone Simulator target.
2. Press `Run`.
3. To install on a physical iPhone, select your Apple ID team in `Signing & Capabilities`, then choose the connected iPhone as the run target.

If opening from Terminal does not work, double-click this file in Finder:

```text
apps/ios/HanwooPrototype/HanwooPrototype.xcodeproj
```

## Windows Limitation

iOS Simulator is a macOS-only tool included with Xcode. Windows cannot run the iOS simulator directly.

Windows can still be used for:

- API work.
- Domain logic work.
- TypeScript typecheck and tests.
- Documentation updates.
- GitHub upload and code review.

To inspect the iOS app UI without a local Mac, use one of:

- A Mac running Xcode.
- A remote Mac.
- A cloud Mac service.
- A TestFlight or device build shared from a Mac.

## Current iOS App Status

- Open `apps/ios/HanwooPrototype/HanwooPrototype.xcodeproj` in Xcode.
- The current app is a local iOS calculation/recommendation app.
- Live API integration is not required for the first release path.
