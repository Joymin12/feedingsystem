import test from "node:test";
import assert from "node:assert/strict";

import type { AnalysisRun } from "@feedingsystem/contracts";

import { buildPdfReport, buildXlsxReport } from "./report-builder.js";

const sampleRun: AnalysisRun = {
  run_id: "run-1",
  formula_id: "formula-1",
  mode: "formula",
  summary: {
    total_as_fed_kg: 12.28,
    total_dm_kg: 7.12,
    moisture_pct: 42.01,
    cp_pct_dm: 13.2,
    tdn_pct_dm: 72.4,
    ndf_pct_dm: 31.8,
    adf_pct_dm: 18.5,
    nfc_pct_dm: 41.2,
    ee_pct_dm: 3.4,
    ca_pct_dm: 0.51,
    p_pct_dm: 0.32,
    ca_p_ratio: 1.59,
    cost_per_head_day: 5120,
    cost_per_kg: 417.59,
  },
  statuses: {
    status_cp: "adequate",
    status_tdn: "adequate",
    status_ndf: "adequate",
    status_adf: "adequate",
    status_ca: "adequate",
    status_p: "adequate",
    status_ca_p_ratio: "adequate",
    status_moisture: "adequate",
  },
  targets: {
    target_cp_pct_dm: 13,
    target_tdn_pct_dm: 72,
    target_ndf_min_pct_dm: 28,
    target_ndf_max_pct_dm: 36,
    target_adf_min_pct_dm: 17,
    target_adf_max_pct_dm: 24,
    target_ca_pct_dm: 0.45,
    target_p_pct_dm: 0.28,
  },
  warnings: [
    {
      code: "season_storage_risk",
      message: "storage risk",
      severity: "warning",
    },
  ],
  recommendations: [
    {
      recommendation_id: "rec-1",
      rank: 1,
      action_type: "add",
      ingredient_id: "soybean-meal",
      suggested_delta_as_fed_kg: 0.2,
      suggested_delta_dm_kg: 0.18,
      estimated_cost_delta: 140,
      estimated_changes: { cp_pct_dm: 0.4 },
      score: 92,
      reason_text: "reason",
      caution_text: "caution",
      alternative_text: "alternative",
    },
  ],
  input_snapshot: {
    stage: "fattening_mid",
    avg_weight_kg: 620,
    head_count: 20,
    objective: "growth",
    target_adg: 0.9,
    season_code: "spring",
    items: [],
    farm_profile_summary: {
      storage_level: "medium",
      wet_feed_policy: "allowed",
      cost_priority: 3,
      stability_priority: 4,
    },
    banned_ingredient_ids: [],
    inventory_items: [],
  },
  created_at: "2026-04-04T10:00:00.000Z",
};

test("buildPdfReport returns a valid PDF header and trailer", () => {
  const buffer = buildPdfReport(sampleRun);
  const text = buffer.toString("utf8");

  assert.equal(text.startsWith("%PDF-1.4"), true);
  assert.equal(text.includes("Hanwoo TMR Analysis Report"), true);
  assert.equal(text.includes("startxref"), true);
  assert.equal(text.trimEnd().endsWith("%%EOF"), true);
});

test("buildXlsxReport returns a ZIP archive containing workbook parts", () => {
  const buffer = buildXlsxReport(sampleRun);
  const text = buffer.toString("utf8");

  assert.equal(buffer.subarray(0, 2).toString("utf8"), "PK");
  assert.equal(text.includes("[Content_Types].xml"), true);
  assert.equal(text.includes("xl/workbook.xml"), true);
  assert.equal(text.includes("xl/worksheets/sheet1.xml"), true);
});
