#!/usr/bin/env node

import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";

const rootDir = resolve(dirname(new URL(import.meta.url).pathname), "..");
const defaultInputPath = resolve(rootDir, "docs/seeds/ingredients.raw.json");
const defaultPolicyPath = resolve(rootDir, "docs/seeds/ingredient-db-normalization-policy.json");
const defaultOutputPath = resolve(rootDir, "docs/seeds/ingredients.normalized.raw.json");

function parseArgs(argv) {
  const options = {
    input: defaultInputPath,
    policy: defaultPolicyPath,
    output: defaultOutputPath,
  };

  for (let index = 0; index < argv.length; index += 1) {
    const token = argv[index];
    if (token === "--input" && argv[index + 1]) {
      options.input = resolve(process.cwd(), argv[index + 1]);
      index += 1;
    } else if (token === "--policy" && argv[index + 1]) {
      options.policy = resolve(process.cwd(), argv[index + 1]);
      index += 1;
    } else if (token === "--output" && argv[index + 1]) {
      options.output = resolve(process.cwd(), argv[index + 1]);
      index += 1;
    } else if (token === "--help") {
      printHelp();
      process.exit(0);
    }
  }

  return options;
}

function printHelp() {
  console.log(`Usage: node scripts/normalize-raw-ingredients.mjs [options]

Options:
  --input <path>   Raw ingredient JSON path
  --policy <path>  Normalization policy JSON path
  --output <path>  Normalized output JSON path
  --help           Show help
`);
}

function round(value, digits = 2) {
  return Number.parseFloat(value.toFixed(digits));
}

function normalizeUseCategory(category) {
  return category === "보충사료" ? "mineral" : "tmr";
}

function normalizeRecord(record, policy) {
  const overriddenCategory = policy.category_overrides?.[String(record.feed_no)] ?? record.category;
  const moisture =
    record.moisture_pct ?? (typeof record.dm_pct === "number" ? round(100 - record.dm_pct, 2) : null);

  return {
    feed_no: record.feed_no,
    name_ko: record.name_ko,
    category: overriddenCategory,
    use_category: normalizeUseCategory(overriddenCategory),
    data_source: record.data_source ?? "농사로_raw_2026-05-04",
    needs_review: record.needs_review ?? false,
    independent_duplicate_source: policy.independent_duplicates.includes(record.feed_no),
    dm_pct: record.dm_pct ?? null,
    moisture_pct: moisture,
    cp_pct: record.cp_pct ?? null,
    ee_pct: record.ee_pct ?? null,
    cf_pct: record.cf_pct ?? null,
    ash_pct: record.ash_pct ?? null,
    ndf_pct: record.ndf_pct ?? null,
    adf_pct: record.adf_pct ?? null,
    nfc_pct: record.nfc_pct ?? null,
    ca_pct: record.ca_pct ?? null,
    p_pct: record.p_pct ?? null,
    tdn_pct: record.tdn_pct ?? null,
    db_matched: record.db_matched ?? null,
  };
}

function main() {
  const options = parseArgs(process.argv.slice(2));
  const raw = JSON.parse(readFileSync(options.input, "utf-8"));
  const policy = JSON.parse(readFileSync(options.policy, "utf-8"));

  if (!Array.isArray(raw)) {
    throw new Error("Raw ingredient input must be an array.");
  }

  const excludedFeedNos = new Set(policy.exclude_feed_no ?? []);
  const normalized = raw
    .filter((record) => !excludedFeedNos.has(record.feed_no))
    .map((record) => normalizeRecord(record, policy))
    .sort((left, right) => left.feed_no - right.feed_no);

  mkdirSync(dirname(options.output), { recursive: true });
  writeFileSync(options.output, `${JSON.stringify(normalized, null, 2)}\n`, "utf-8");

  const tmrCount = normalized.filter((record) => record.use_category === "tmr").length;
  const mineralCount = normalized.filter((record) => record.use_category === "mineral").length;

  console.log(
    JSON.stringify(
      {
        input: options.input,
        output: options.output,
        total_raw: raw.length,
        total_normalized: normalized.length,
        excluded: raw.length - normalized.length,
        tmr_count: tmrCount,
        mineral_count: mineralCount,
      },
      null,
      2,
    ),
  );
}

main();
