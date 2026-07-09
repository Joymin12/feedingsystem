import test from "node:test";
import assert from "node:assert/strict";

import type { FarmIngredientSetting, FarmProfile, Ingredient, SeedIngredientRecord } from "@feedingsystem/contracts";

import seedIngredients from "../../../docs/seeds/ingredients.seed.json";
import { analyzeRun } from "./analysis.js";

function buildIngredients(records: SeedIngredientRecord[]): Ingredient[] {
  return records.map((record, index) => ({
    ingredient_id: `ingredient-${index + 1}`,
    code: record.code,
    name_ko: record.name_ko,
    category: record.category,
    default_price_krw_per_kg: record.default_price_krw_per_kg,
    description: record.description,
    current_nutrition: record.nutrition,
    ai_profile: record.ai_profile,
  }));
}

test("analyzeRun returns summary, statuses, warnings, and top 3 recommendations", () => {
  const ingredients = buildIngredients(seedIngredients as SeedIngredientRecord[]);
  const farmProfile: FarmProfile = {
    farm_id: "farm-1",
    farm_name: "테스트 농장",
    storage_level: "medium",
    wet_feed_policy: "allowed",
    cost_priority: 3,
    stability_priority: 4,
    preferred_ingredients: [],
    avoided_ingredients: [],
  };
  const settings: FarmIngredientSetting[] = ingredients.map((ingredient) => ({
    ingredient_id: ingredient.ingredient_id,
    is_enabled: true,
    is_banned: false,
    preferred: false,
    avoided: false,
    inventory_kg: 100,
    price_source: "market_default",
  }));

  const findIngredientId = (code: string) =>
    ingredients.find((ingredient) => ingredient.code === code)?.ingredient_id ?? "";

  const analysis = analyzeRun({
    actorUserId: "user-1",
    currentMonth: 7,
    farmProfile,
    farmIngredientSettings: settings,
    ingredients,
    request: {
      mode: "adhoc",
      stage: "fattening_mid",
      avg_weight_kg: 620,
      head_count: 20,
      objective: "growth",
      target_adg: 0.9,
      items: [
        {
          ingredient_id: findIngredientId("CORN_GRAIN"),
          as_fed_kg_per_head_day: 4.2,
          price_source: "market_default",
        },
        {
          ingredient_id: findIngredientId("CORN_SILAGE"),
          as_fed_kg_per_head_day: 6.0,
          price_source: "market_default",
        },
        {
          ingredient_id: findIngredientId("RICE_STRAW"),
          as_fed_kg_per_head_day: 1.2,
          price_source: "market_default",
        },
      ],
    },
  });

  assert.ok(analysis.summary.total_as_fed_kg > 0);
  assert.ok(analysis.summary.total_dm_kg > 0);
  assert.ok(analysis.summary.nfc_pct_dm >= 0);
  assert.ok(analysis.summary.ee_pct_dm >= 0);
  assert.ok(analysis.summary.ca_p_ratio > 0);
  assert.equal(analysis.recommendations.length, 3);
  assert.ok(analysis.warnings.length > 0);
  assert.match(analysis.input_snapshot.season_code, /summer|spring|autumn|winter/);
  assert.ok(analysis.input_snapshot.items.every((item) => item.nutrition_snapshot.dm_pct >= 0));
  assert.ok(analysis.input_snapshot.items.every((item) => item.nutrition_snapshot.nfc_source === "derived"));
});

test("analyzeRun derives NFC when it is missing from source data", () => {
  const ingredients = buildIngredients(seedIngredients as SeedIngredientRecord[]);
  const corn = ingredients.find((ingredient) => ingredient.code === "CORN_GRAIN");
  assert.ok(corn);
  const { nfc_pct_dm: _nfc, nfc_source: _nfcSource, ...legacyNutrition } = corn.current_nutrition;
  corn.current_nutrition = legacyNutrition as typeof corn.current_nutrition;

  const analysis = analyzeRun({
    actorUserId: "user-1",
    farmProfile: {
      farm_id: "farm-1",
      farm_name: "테스트 농장",
      storage_level: "medium",
      wet_feed_policy: "allowed",
      cost_priority: 3,
      stability_priority: 3,
      preferred_ingredients: [],
      avoided_ingredients: [],
    },
    farmIngredientSettings: [
      {
        ingredient_id: corn.ingredient_id,
        is_enabled: true,
        is_banned: false,
        preferred: false,
        avoided: false,
        price_source: "market_default",
      },
    ],
    ingredients: [corn],
    request: {
      mode: "adhoc",
      stage: "fattening_mid",
      avg_weight_kg: 620,
      head_count: 10,
      objective: "growth",
      items: [
        {
          ingredient_id: corn.ingredient_id,
          as_fed_kg_per_head_day: 5,
          price_source: "market_default",
        },
      ],
    },
  });

  assert.equal(analysis.input_snapshot.items[0]?.nutrition_snapshot.nfc_source, "derived");
  assert.equal(analysis.summary.nfc_pct_dm, 75.7);
});

test("analyzeRun fails when total DM kg is zero", () => {
  const ingredients = buildIngredients(seedIngredients as SeedIngredientRecord[]);
  const mineral = ingredients.find((ingredient) => ingredient.code === "MINERAL_PREMIX");
  assert.ok(mineral);
  mineral.current_nutrition.dm_pct = 0;
  mineral.current_nutrition.moisture_pct = 100;

  assert.throws(
    () =>
      analyzeRun({
        actorUserId: "user-1",
        farmProfile: {
          farm_id: "farm-1",
          farm_name: "테스트 농장",
          storage_level: "medium",
          wet_feed_policy: "allowed",
          cost_priority: 3,
          stability_priority: 3,
          preferred_ingredients: [],
          avoided_ingredients: [],
        },
        farmIngredientSettings: [
          {
            ingredient_id: mineral.ingredient_id,
            is_enabled: true,
            is_banned: false,
            preferred: false,
            avoided: false,
            price_source: "market_default",
          },
        ],
        ingredients: [mineral],
        request: {
          mode: "adhoc",
          stage: "fattening_mid",
          avg_weight_kg: 620,
          head_count: 10,
          objective: "growth",
          items: [
            {
              ingredient_id: mineral.ingredient_id,
              as_fed_kg_per_head_day: 1,
              price_source: "market_default",
            },
          ],
        },
      }),
    /dm must be greater than 0|total DM kg must be greater than 0/,
  );
});

test("analyzeRun fails when moisture and DM are inconsistent", () => {
  const ingredients = buildIngredients(seedIngredients as SeedIngredientRecord[]);
  const corn = ingredients.find((ingredient) => ingredient.code === "CORN_GRAIN");
  assert.ok(corn);
  corn.current_nutrition.moisture_pct = 20;

  assert.throws(
    () =>
      analyzeRun({
        actorUserId: "user-1",
        farmProfile: {
          farm_id: "farm-1",
          farm_name: "테스트 농장",
          storage_level: "medium",
          wet_feed_policy: "allowed",
          cost_priority: 3,
          stability_priority: 3,
          preferred_ingredients: [],
          avoided_ingredients: [],
        },
        farmIngredientSettings: [
          {
            ingredient_id: corn.ingredient_id,
            is_enabled: true,
            is_banned: false,
            preferred: false,
            avoided: false,
            price_source: "market_default",
          },
        ],
        ingredients: [corn],
        request: {
          mode: "adhoc",
          stage: "fattening_mid",
          avg_weight_kg: 620,
          head_count: 10,
          objective: "growth",
          items: [
            {
              ingredient_id: corn.ingredient_id,
              as_fed_kg_per_head_day: 1,
              price_source: "market_default",
            },
          ],
        },
      }),
    /moisture\/dm mismatch/,
  );
});
