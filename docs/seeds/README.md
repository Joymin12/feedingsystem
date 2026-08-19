# Seeds And Source DB

## Files

- `ingredients.seed.json`
  - Curated seed read directly by API/domain tests.
  - Must contain complete nutrition snapshots.
  - Must not allow `null`.

- `final-ingredient-category-groups.json`
  - Final operating category table.
  - Fixed to four categories: `concentrate / roughage / agricultural byproduct / mineral-additive`.
  - Records final included ingredients and category rules by `feed_no`.
  - `4/5/6` are consolidated into `4 cracked corn` for final operating use.

- `ingredients.source.extensions.final.json`
  - Final raw source DB extension set.
  - Allows missing `null` values.
  - Preserves field names and independent ingredient entries.
  - Acts as source-of-truth before app/server promotion.
  - Currently keeps the `feed_no 200-223` extension set.

- `ingredient-db-normalization-policy.json`
  - Excluded ingredients, category overrides, and `null` preservation policy.

## Rules

- Keep `source DB` and `API seed` separate.
- `final-ingredient-category-groups.json` does not overwrite the source DB directly; it only fixes the final app/operations category mapping.
- Inclusion in the source DB does not automatically promote an ingredient to calculation/recommendation use.
- Ingredients missing key fields such as `ndf/adf/tdn/ca/p` may remain source-only.
- The app catalog may include some missing values as `0` for input convenience; current policy also allows them as recommendation candidates.
- `TDN > 100` is allowed.
- `Coffee hull`, `coffee byproduct`, animal/insect/dairy byproducts, and zinc oxide are excluded from the final DB.
- Extension ingredient `coffee grounds` in `200-223` remains in the source DB and app catalog.
- Field-name ingredients such as rice bran, barley bran, distillers grains, lupin, soybean meal, and citrus pulp must not be automatically matched to canonical ingredients.
- Some oilseed meal/byproduct ingredients remain categorized as agricultural byproducts even if their nutrition profile resembles concentrate feed.
