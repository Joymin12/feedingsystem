# Hanwoo TMR Calculation And Recommendation Engine Developer Brief

## 1. Project Purpose

Hanufit is an iOS app where Hanwoo farmers enter their current TMR/TMF formula in `as-fed kg`. The app engine calculates nutrition on a dry-matter basis, compares the result against growth-stage criteria, classifies each nutrient as `deficient / caution / adequate / excess`, and produces one composite correction plan.

Core principles:

- The first release is based on the `iOS local calculation/correction engine`.
- A recommendation is a composite correction plan, not a single-ingredient suggestion.
- The default primary recommendation adjusts only ingredients already present in the user's formula.
- Internal simulation may freely change total mass, but the final output must be normalized back to the user's original total as-fed kg.
- AI may assist with candidate direction and explanation, but final calculation, classification, and validation are performed by the app engine.

Example output:

- `Rice bran -20kg`
- `Cracked corn +12kg`
- `Soybean meal +3kg`

## 2. Data Boundaries

### Source DB

File:

- `/Users/jowm/Desktop/feedingsystem/docs/seeds/ingredients.source.extensions.final.json`

Role:

- Raw preservation layer.
- Keeps field names.
- Allows missing `null` values.
- Keeps independent ingredients separate.

### App Catalog

File:

- `/Users/jowm/Desktop/feedingsystem/apps/ios/HanwooPrototype/HanwooPrototype/IngredientCatalog.swift`

Role:

- iOS calculation catalog.
- Current policy keeps `0` values and does not exclude them as missing values.
- Current policy also allows those ingredients as recommendation candidates.

Caution:

- Long-term, consider optional nutrition profiles so the app can distinguish a true `0` from a placeholder `0`.

### User Ingredient DB

These are ingredients manually entered by app users from feed analysis reports.

Role:

- Reflect feed analysis values from local cooperatives, agricultural cooperatives, or analysis institutions.
- Stored with `USER_...` IDs.
- Direct input fields: moisture, CP, TDN, EE, NDF, ADF, NFC, ash, Ca, P.
- Used in calculation and recommendation simulation exactly like catalog ingredients.

Important:

- Do not store user ingredients as name-only lines.
- Only user ingredients with nutrition profiles should be used for calculation/recommendation.
- Current storage is local UserDefaults. During server migration, move this to a user-scoped ingredient table.

### API Seed

File:

- `/Users/jowm/Desktop/feedingsystem/docs/seeds/ingredients.seed.json`

Role:

- Curated seed for future server migration.
- Not required for the first release path.

## 3. Input And Calculation Basis

User input is always as-fed kg. The app converts this to dry-matter kg, then calculates each nutrient as a dry-matter weighted average.

### 3.1 As-Fed kg To DM kg

```text
DM_kg = as_fed_kg x (dm_pct / 100)
```

or:

```text
DM_kg = as_fed_kg x (1 - moisture_pct / 100)
```

### 3.2 Whole-Formula Nutrients

CP, TDN, EE, NDF, ADF, Ca, and P are `%DM` values.

```text
formula CP%DM = sum(ingredient DMkg x ingredient CP%DM) / total DMkg
formula TDN%DM = sum(ingredient DMkg x ingredient TDN%DM) / total DMkg
formula EE%DM = sum(ingredient DMkg x ingredient EE%DM) / total DMkg
formula NDF%DM = sum(ingredient DMkg x ingredient NDF%DM) / total DMkg
formula ADF%DM = sum(ingredient DMkg x ingredient ADF%DM) / total DMkg
formula Ca%DM = sum(ingredient DMkg x ingredient Ca%DM) / total DMkg
formula P%DM = sum(ingredient DMkg x ingredient P%DM) / total DMkg
```

### 3.3 Moisture

Moisture is calculated on an as-fed basis.

```text
total moisture kg = sum(ingredient as-fed kg x moisture_pct / 100)
formula moisture% = total moisture kg / total as-fed kg x 100
```

### 3.4 Ca:P

Ca:P is a ratio, not a percentage.

```text
Ca:P = Ca_pct_dm / P_pct_dm
```

### 3.5 Calculation References

Dry-matter based calculation is a standard feed analysis and ration formulation method.

- Oregon State University Extension explains `DM% = 100% - Moisture%` and why as-fed and dry-matter bases must be separated.
- Nebraska Extension explains that when converting from as-fed to dry matter, nutrient concentration increases and weight decreases according to dry-matter percentage.
- Penn State Extension provides `As Fed nutrient content = DM nutrient content x DM ratio` and `DM nutrient content = As Fed nutrient content / DM ratio`.
- USDA AMS Organic Handbook calculates dry-matter intake by multiplying as-fed feed amount by dry-matter percentage.

Reference URLs:

- `https://extension.oregonstate.edu/catalog/em-8801-understanding-your-forage-test-results`
- `https://extensionpubs.unl.edu/publication/g2093/feed-dry-matter-conversions`
- `https://extension.psu.edu/determining-forage-quality-understanding-feed-analysis`
- `https://www.ams.usda.gov/rules-regulations/organic/handbook/5017-1`

## 4. Growth-Stage Criteria

### Adequate Range

| Stage | Period | CP | TDN | EE | NDF | ADF | Ca | P | Ca:P | Moisture |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Growing | 6-14 months | 14-18 | 68-72 | <=5 | 35-45 | 20-28 | 0.45-0.80 | 0.28-0.45 | 1.5-2.0 | 40-45 |
| Early fattening | 14-20 months | 12-15 | 72-76 | <=5 | 32-38 | 18-24 | 0.35-0.65 | 0.22-0.38 | 1.5-2.0 | 40-45 |
| Late fattening | 20 months to shipping | 11-13 | 73-78 | <=5 | 25-32 | 15-20 | 0.30-0.60 | 0.20-0.35 | 1.5-2.0 | 40-45 |

### Caution Range

Caution ranges must not overlap the adequate range.

| Stage | CP caution | TDN caution | EE caution | NDF caution | ADF caution | Ca caution | P caution | Ca:P caution | Moisture caution |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Growing | 13-<14 / >18-19 | 66-<68 / >72-74 | >5-6 | 32-<35 / >45-48 | 18-<20 / >28-30 | 0.38-<0.45 / >0.80-0.90 | 0.24-<0.28 / >0.45-0.52 | 1.4-<1.5 / >2.0-2.1 | 36-<40 / >45-49 |
| Early fattening | 11-<12 / >15-16 | 70-<72 / >76-78 | >5-6 | 29-<32 / >38-40 | 16-<18 / >24-26 | 0.30-<0.35 / >0.65-0.75 | 0.19-<0.22 / >0.38-0.44 | 1.4-<1.5 / >2.0-2.1 | 36-<40 / >45-49 |
| Late fattening | 10-<11 / >13-14 | 71-<73 / >78-80 | >5-6 | 23-<25 / >32-35 | 13-<15 / >20-22 | 0.25-<0.30 / >0.60-0.70 | 0.17-<0.20 / >0.35-0.41 | 1.4-<1.5 / >2.0-2.1 | 36-<40 / >45-49 |

For moisture, `<=35` is deficient and `>=50` is excess. For other nutrients, deficient/excess means outside the caution range.

## 5. Recommendation Engine Goal

The goal is to produce one primary correction plan that gets the ration into, or as close as possible to, the adequate range. To avoid breaking the farmer's existing feeding flow, the default primary recommendation only adjusts ingredients already in the current formula.

Policy:

- Candidate ingredients are current formula ingredient lines.
- Do not add ingredients that are not in the formula to the default primary recommendation.
- No increase/decrease cap.
- Reject any candidate that makes an ingredient negative.
- During internal search, total as-fed kg may change from 3000kg to 4000kg or 2000kg.
- The final recommendation must be normalized back to the original user-entered total as-fed kg.
- After normalization, recalculate and classify projected metrics.
- Moisture should influence risk explanation but should not be a stronger rejection condition than CP/TDN/EE/NDF/ADF/Ca/P/Ca:P.

## 6. Recommendation Flow

```text
1. User enters formula as-fed kg
2. App engine calculates current nutrients
3. App engine classifies deficient/caution/adequate/excess
4. AI or rule engine generates adjustment candidates
5. App engine applies candidates and recalculates
6. Candidate totals are normalized back to original total as-fed kg
7. Normalized formula is recalculated
8. One closest primary recommendation is shown
9. AI explains the final recommendation in farmer-friendly language
```

## 7. AI Role

AI should:

- Suggest increase/decrease candidates within ingredients currently in the formula.
- Explain why each ingredient is increased or decreased.
- Connect cause and action, such as "increase soybean meal because CP is low" or "reduce rice bran because EE is high."
- Explain composite tradeoffs across CP, TDN, EE, fiber, and minerals.
- Convert app-engine results into farmer-friendly text.
- Tone may use "we recommend".

AI must not:

- Guess final calculated values such as CP, TDN, or Ca:P.
- Override app-engine classifications.
- Finalize a primary recommendation with ingredients not in the app DB or current formula.
- Use absolute claims such as "this is always good."

## 8. Required Recommendation Output Shape

Return only one primary recommendation.

```json
{
  "summary": "This plan reduces rice bran to lower excess EE while adjusting soybean meal and cracked corn to keep CP and TDN balanced.",
  "actions": [
    {
      "type": "decrease",
      "ingredientId": "FEED_216",
      "ingredientName": "Rice bran",
      "amountKg": 20
    },
    {
      "type": "increase",
      "ingredientId": "CUSTOM_SOYBEAN_MEAL",
      "ingredientName": "Soybean meal",
      "amountKg": 15
    }
  ],
  "inputTotalAsFedKg": 3000,
  "outputTotalAsFedKg": 3000,
  "projectedMetrics": {
    "cpPctDm": 12.8,
    "tdnPctDm": 74.1,
    "eePctDm": 4.9,
    "ndfPctDm": 31.4,
    "adfPctDm": 19.2,
    "caPctDm": 0.42,
    "pPctDm": 0.29,
    "caPRatio": 1.45,
    "moisturePct": 39.8
  },
  "isPrimaryResolved": true,
  "resolutionRate": 0.88
}
```

`inputTotalAsFedKg` and `outputTotalAsFedKg` must be equal. Even if internal candidate totals differ, normalize before showing the result.

## 9. Developer Implementation Prompt

```md
Implement the Hanwoo TMR recommendation engine.

Goal:
- User input is as-fed kg.
- Internal calculation is dry-matter based.
- The output is one composite correction plan, not a single-ingredient suggestion.
- The primary recommendation only increases/decreases ingredients already present in the current formula.
- Internal simulation totals may change, but the final result must be normalized back to the user's original total as-fed kg.

Input:
- Formula ingredient list (ingredient id, name, as-fed kg)
- Growth stage (growing / early fattening / late fattening)
- Ingredient nutrition DB (%DM)
- User-entered ingredient nutrition profiles (%DM)

Required calculation:
1. Convert each ingredient from as-fed kg to DM kg
2. Calculate whole-formula CP, TDN, EE, NDF, ADF, Ca, P, and moisture
3. Calculate Ca:P ratio
4. Compare against growth-stage criteria and classify deficient/caution/adequate/excess

Recommendation rules:
1. Classify the current formula problem pattern.
2. Treat ingredients strongly contributing to excess nutrients as reduction candidates.
3. Treat current-formula ingredients that can fill deficient nutrients as increase candidates.
4. Combine multiple actions into a composite correction plan.
5. Apply each candidate and recalculate with the app engine.
6. If candidate total mass differs from the original, normalize back to the original total as-fed kg.
7. Recalculate projected metrics after normalization.
8. Show only one primary recommendation.

Important:
- AI assists with explanation and candidate generation only.
- Final calculation, classification, and recommendation validation are done by the app engine.
- Do not add new ingredients to the default primary recommendation.
- Moisture influences risk explanation but is not a hard first-priority rejection condition.
- Explanations must describe composite correction tradeoffs.
```
