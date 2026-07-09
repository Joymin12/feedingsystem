import { randomUUID } from "node:crypto";

import type {
  AnalysisInputSnapshot,
  AnalysisRun,
  ActionType,
  AnalysisRunAdHocRequest,
  AnalysisRunFromFormulaRequest,
  AnalysisStatuses,
  AnalysisSummary,
  AnalysisTargets,
  AnalysisWarning,
  FarmIngredientSetting,
  FarmProfile,
  Formula,
  FormulaItem,
  Ingredient,
  NutrientStatus,
  RequirementProfile,
} from "@feedingsystem/contracts";

import { DEFAULT_REQUIREMENT_PROFILES } from "./requirements.js";
import { buildAlternativeText, buildCautionText, buildReasonText } from "./text.js";

const SINGLE_TARGET_TOLERANCE = 0.05;
const MOISTURE_MIN_PCT = 35;
const MOISTURE_MAX_PCT = 55;
const MOISTURE_DM_TOLERANCE_PCT = 0.5;
const CA_P_RATIO_MIN = 1.5;
const CA_P_RATIO_MAX = 2.0;

interface ResolvedItem extends FormulaItem {
  ingredient: Ingredient;
  used_price_krw_per_kg: number;
}

export interface AnalyzeRunParams {
  actorUserId: string;
  currentMonth?: number;
  farmProfile: FarmProfile;
  farmIngredientSettings: FarmIngredientSetting[];
  ingredients: Ingredient[];
  formulas?: Formula[];
  request: AnalysisRunAdHocRequest | AnalysisRunFromFormulaRequest;
  requirementProfiles?: RequirementProfile[];
}

function round(value: number, digits = 2): number {
  const factor = 10 ** digits;
  return Math.round(value * factor) / factor;
}

function selectRequirementProfile(
  stage: RequirementProfile["stage"],
  avgWeightKg: number,
  targetAdg: number | undefined,
  requirementProfiles: RequirementProfile[],
): RequirementProfile {
  const matched = requirementProfiles.find((profile) => {
    const stageMatch = profile.stage === stage;
    const weightMatch =
      avgWeightKg >= profile.min_weight_kg && avgWeightKg <= profile.max_weight_kg;
    const adgMinMatch = profile.min_adg === undefined || targetAdg === undefined || targetAdg >= profile.min_adg;
    const adgMaxMatch = profile.max_adg === undefined || targetAdg === undefined || targetAdg <= profile.max_adg;

    return stageMatch && weightMatch && adgMinMatch && adgMaxMatch;
  });

  if (!matched) {
    return requirementProfiles.find((profile) => profile.stage === stage) ?? requirementProfiles[0]!;
  }

  return matched;
}

function determineSingleTargetStatus(value: number, target: number): NutrientStatus {
  if (value < target * (1 - SINGLE_TARGET_TOLERANCE)) {
    return "deficient";
  }
  if (value > target * (1 + SINGLE_TARGET_TOLERANCE)) {
    return "excess";
  }
  return "adequate";
}

function determineRangeStatus(value: number, min: number, max: number): NutrientStatus {
  if (value < min) {
    return "deficient";
  }
  if (value > max) {
    return "excess";
  }
  return "adequate";
}

function deriveNfcPctDm(nutrition: Ingredient["current_nutrition"]): number {
  return round(100 - (nutrition.cp_pct_dm + nutrition.ee_pct_dm + nutrition.ash_pct_dm + nutrition.ndf_pct_dm), 2);
}

function validateNutritionSnapshot(ingredient: Ingredient): Ingredient["current_nutrition"] {
  const nutrition = ingredient.current_nutrition as Ingredient["current_nutrition"];
  const dmDelta = Math.abs((100 - nutrition.moisture_pct) - nutrition.dm_pct);
  if (dmDelta > MOISTURE_DM_TOLERANCE_PCT) {
    throw new Error(`ingredient moisture/dm mismatch: ${ingredient.code}`);
  }
  if (nutrition.dm_pct <= 0) {
    throw new Error(`ingredient dm must be greater than 0: ${ingredient.code}`);
  }

  const normalizedNfc = Number.isFinite(nutrition.nfc_pct_dm)
    ? nutrition.nfc_pct_dm
    : deriveNfcPctDm(nutrition);
  const nfcSource = Number.isFinite(nutrition.nfc_pct_dm)
    ? nutrition.nfc_source
    : "derived";

  const normalized = {
    ...nutrition,
    nfc_pct_dm: normalizedNfc,
    nfc_source: nfcSource,
  };

  const requiredPercentages: Array<[string, number]> = [
    ["moisture_pct", normalized.moisture_pct],
    ["dm_pct", normalized.dm_pct],
    ["ash_pct_dm", normalized.ash_pct_dm],
    ["cp_pct_dm", normalized.cp_pct_dm],
    ["tdn_pct_dm", normalized.tdn_pct_dm],
    ["ndf_pct_dm", normalized.ndf_pct_dm],
    ["adf_pct_dm", normalized.adf_pct_dm],
    ["nfc_pct_dm", normalized.nfc_pct_dm],
    ["ee_pct_dm", normalized.ee_pct_dm],
    ["ca_pct_dm", normalized.ca_pct_dm],
    ["p_pct_dm", normalized.p_pct_dm],
  ];

  for (const [field, value] of requiredPercentages) {
    if (!Number.isFinite(value)) {
      throw new Error(`ingredient nutrient missing: ${ingredient.code}.${field}`);
    }
    if (value < 0) {
      throw new Error(`ingredient nutrient must be non-negative: ${ingredient.code}.${field}`);
    }
  }

  if (normalized.moisture_pct > 100 || normalized.dm_pct > 100) {
    throw new Error(`ingredient moisture/dm out of range: ${ingredient.code}`);
  }

  return normalized;
}

function buildWarnings(summary: AnalysisSummary, statuses: AnalysisStatuses, month: number): AnalysisWarning[] {
  const warnings: AnalysisWarning[] = [];

  if (statuses.status_moisture === "deficient") {
    warnings.push({
      code: "moisture_low",
      message: "수분이 낮아 기호성과 혼합 안정성 저하 가능성이 있습니다.",
      severity: "warning",
    });
  }
  if (statuses.status_moisture === "excess") {
    warnings.push({
      code: "moisture_high",
      message: "수분이 높아 저장성과 발열 리스크를 점검해야 합니다.",
      severity: "critical",
    });
  }
  if (statuses.status_tdn === "deficient") {
    warnings.push({
      code: "energy_deficient",
      message: "TDN 부족으로 목표 증체 달성 가능성이 낮아질 수 있습니다.",
      severity: "warning",
    });
  }
  if (statuses.status_cp === "deficient") {
    warnings.push({
      code: "protein_deficient",
      message: "CP 부족으로 단백질 보강 검토가 필요합니다.",
      severity: "warning",
    });
  }
  if (statuses.status_ndf === "deficient" || statuses.status_adf === "deficient") {
    warnings.push({
      code: "fiber_low",
      message: "섬유 수준이 낮아 반추 안정성 리스크가 있습니다.",
      severity: "critical",
    });
  }
  if (statuses.status_ca_p_ratio !== "adequate") {
    warnings.push({
      code: "ca_p_ratio_out_of_range",
      message: "칼슘과 인 비율이 권장 범위를 벗어나 광물질 균형을 점검해야 합니다.",
      severity: "warning",
    });
  }
  if (summary.tdn_pct_dm > 78 && summary.ndf_pct_dm < 28) {
    warnings.push({
      code: "acidosis_risk",
      message: "고전분/저섬유 조합으로 산증 위험을 점검해야 합니다.",
      severity: "critical",
    });
  }
  if (month >= 6 && month <= 8 && summary.moisture_pct > 50) {
    warnings.push({
      code: "season_storage_risk",
      message: "고온기에 수분이 높아 저장성 관리가 중요합니다.",
      severity: "warning",
    });
  }

  return warnings;
}

function resolveItems(
  items: FormulaItem[],
  ingredients: Ingredient[],
  settings: FarmIngredientSetting[],
): ResolvedItem[] {
  return items.map((item) => {
    const ingredient = ingredients.find((candidate) => candidate.ingredient_id === item.ingredient_id);
    if (!ingredient) {
      throw new Error(`ingredient not found: ${item.ingredient_id}`);
    }

    const setting = settings.find((candidate) => candidate.ingredient_id === item.ingredient_id);
    const usedPrice =
      item.price_override_krw_per_kg ??
      setting?.custom_price_krw_per_kg ??
      ingredient.default_price_krw_per_kg;

    return {
      ...item,
      ingredient,
      used_price_krw_per_kg: usedPrice,
    };
  });
}

function buildInputSnapshot(
  stage: Formula["stage"],
  avgWeightKg: number,
  headCount: number,
  objective: Formula["objective"],
  targetAdg: number | undefined,
  month: number,
  farmProfile: FarmProfile,
  items: ResolvedItem[],
  bannedIngredientIds: string[],
  inventoryItems: AnalysisInputSnapshot["inventory_items"],
): AnalysisInputSnapshot {
  const seasonCode = month >= 3 && month <= 5 ? "spring" : month >= 6 && month <= 8 ? "summer" : month >= 9 && month <= 11 ? "autumn" : "winter";

  const snapshotItems: AnalysisInputSnapshot["items"] = items.map((item) => {
    const nutritionSnapshot = validateNutritionSnapshot(item.ingredient);
    const base = {
      ingredient_id: item.ingredient_id,
      as_fed_kg_per_head_day: item.as_fed_kg_per_head_day,
      price_source: item.price_source,
      ingredient_name: item.ingredient.name_ko,
      used_price_krw_per_kg: item.used_price_krw_per_kg,
      source_version: nutritionSnapshot.source_version,
      nutrition_snapshot: nutritionSnapshot,
    };

    return item.price_override_krw_per_kg !== undefined
      ? {
          ...base,
          price_override_krw_per_kg: item.price_override_krw_per_kg,
        }
      : base;
  });

  return {
    stage,
    avg_weight_kg: avgWeightKg,
    head_count: headCount,
    objective,
    season_code: seasonCode,
    ...(targetAdg !== undefined ? { target_adg: targetAdg } : {}),
    items: snapshotItems,
    farm_profile_summary: {
      storage_level: farmProfile.storage_level,
      wet_feed_policy: farmProfile.wet_feed_policy,
      cost_priority: farmProfile.cost_priority,
      stability_priority: farmProfile.stability_priority,
    },
    banned_ingredient_ids: bannedIngredientIds,
    inventory_items: inventoryItems,
  };
}

function buildRecommendations(params: {
  farmProfile: FarmProfile;
  settings: FarmIngredientSetting[];
  ingredients: Ingredient[];
  items: ResolvedItem[];
  summary: AnalysisSummary;
  statuses: AnalysisStatuses;
}): AnalysisRun["recommendations"] {
  const { farmProfile, settings, ingredients, items, summary, statuses } = params;
  const currentIngredientIds = new Set(items.map((item) => item.ingredient_id));

  const nutrientFocus: string[] = [];
  if (statuses.status_cp === "deficient") nutrientFocus.push("CP");
  if (statuses.status_tdn === "deficient") nutrientFocus.push("TDN");
  if (statuses.status_ndf === "deficient") nutrientFocus.push("NDF");
  if (statuses.status_adf === "deficient") nutrientFocus.push("ADF");
  if (statuses.status_ca === "deficient") nutrientFocus.push("Ca");
  if (statuses.status_p === "deficient") nutrientFocus.push("P");
  if (statuses.status_moisture === "deficient") nutrientFocus.push("수분");

  const scored = ingredients
    .map((ingredient) => {
      const setting = settings.find((candidate) => candidate.ingredient_id === ingredient.ingredient_id);
      if (setting?.is_banned || setting?.is_enabled === false) {
        return null;
      }

      const nutrition = validateNutritionSnapshot(ingredient);
      const isWet = nutrition.moisture_pct >= 60 || ingredient.ai_profile.tags.includes("wet");
      const price = setting?.custom_price_krw_per_kg ?? ingredient.default_price_krw_per_kg;

      let score = 0;
      if (statuses.status_cp === "deficient") score += nutrition.cp_pct_dm * 0.7;
      if (statuses.status_tdn === "deficient") score += nutrition.tdn_pct_dm * 0.35;
      if (statuses.status_ndf === "deficient") score += nutrition.ndf_pct_dm * 0.25;
      if (statuses.status_adf === "deficient") score += nutrition.adf_pct_dm * 0.25;
      if (statuses.status_ca_p_ratio === "deficient") score += nutrition.ca_pct_dm * 8;
      if (statuses.status_ca_p_ratio === "excess") score += nutrition.p_pct_dm * 8;
      if (statuses.status_ca === "deficient") score += nutrition.ca_pct_dm * 12;
      if (statuses.status_p === "deficient") score += nutrition.p_pct_dm * 10;
      if (statuses.status_moisture === "deficient" && isWet) score += 10;
      if (statuses.status_moisture === "excess" && isWet) score -= 20;
      if (farmProfile.wet_feed_policy === "avoid" && isWet) score -= 12;
      if (farmProfile.storage_level === "high" && isWet) score -= 8;
      if (farmProfile.cost_priority >= 4) score += Math.max(0, 12 - price / 100);
      if (farmProfile.stability_priority >= 4 && !isWet) score += 6;
      if (setting?.preferred) score += 8;
      if (setting?.avoided) score -= 10;
      if ((setting?.inventory_kg ?? 0) > 0) score += 4;
      if (currentIngredientIds.has(ingredient.ingredient_id)) score += 2;

      const actionType: ActionType =
        statuses.status_moisture === "excess" && isWet && currentIngredientIds.has(ingredient.ingredient_id)
          ? "reduce"
          : "add";

      const suggestedDeltaAsFed =
        ingredient.category === "mineral"
          ? 0.05
          : isWet
            ? 1.5
            : ingredient.category === "roughage"
              ? 0.8
              : 0.6;
      const suggestedDeltaDm = round(suggestedDeltaAsFed * (nutrition.dm_pct / 100), 3);
      const estimatedCostDelta = round(price * suggestedDeltaAsFed, 2);

      return {
        recommendation_id: randomUUID(),
        rank: 0,
        action_type: actionType,
        ingredient_id: ingredient.ingredient_id,
        suggested_delta_as_fed_kg: round(suggestedDeltaAsFed, 3),
        suggested_delta_dm_kg: suggestedDeltaDm,
        estimated_cost_delta: estimatedCostDelta,
        estimated_changes: {
          cp_pct_dm: round((suggestedDeltaDm * nutrition.cp_pct_dm) / Math.max(summary.total_dm_kg, 1), 2),
          tdn_pct_dm: round((suggestedDeltaDm * nutrition.tdn_pct_dm) / Math.max(summary.total_dm_kg, 1), 2),
          ndf_pct_dm: round((suggestedDeltaDm * nutrition.ndf_pct_dm) / Math.max(summary.total_dm_kg, 1), 2),
          adf_pct_dm: round((suggestedDeltaDm * nutrition.adf_pct_dm) / Math.max(summary.total_dm_kg, 1), 2),
          nfc_pct_dm: round((suggestedDeltaDm * nutrition.nfc_pct_dm) / Math.max(summary.total_dm_kg, 1), 2),
          ee_pct_dm: round((suggestedDeltaDm * nutrition.ee_pct_dm) / Math.max(summary.total_dm_kg, 1), 2),
          ca_pct_dm: round((suggestedDeltaDm * nutrition.ca_pct_dm) / Math.max(summary.total_dm_kg, 1), 2),
          p_pct_dm: round((suggestedDeltaDm * nutrition.p_pct_dm) / Math.max(summary.total_dm_kg, 1), 2),
          moisture_pct: round(nutrition.moisture_pct * (suggestedDeltaAsFed / Math.max(summary.total_as_fed_kg, 1)), 2),
        },
        score: round(score, 3),
        reason_text: buildReasonText(ingredient, nutrientFocus, farmProfile),
        caution_text: buildCautionText(ingredient),
        alternative_text: "",
      };
    })
    .filter((recommendation): recommendation is NonNullable<typeof recommendation> => Boolean(recommendation))
    .sort((left, right) => right.score - left.score)
    .slice(0, 3)
    .map((recommendation, index, array) => ({
      ...recommendation,
      rank: index + 1,
      alternative_text: buildAlternativeText(
        recommendation,
        array
          .map((candidate) => ingredients.find((ingredient) => ingredient.ingredient_id === candidate.ingredient_id))
          .filter((ingredient): ingredient is Ingredient => Boolean(ingredient)),
      ),
    }));

  return scored;
}

export function analyzeRun(params: AnalyzeRunParams): AnalysisRun {
  const month = params.currentMonth ?? new Date().getMonth() + 1;
  const formulas = params.formulas ?? [];
  const requirementProfiles = params.requirementProfiles ?? DEFAULT_REQUIREMENT_PROFILES;
  const formulaRequest = params.request.mode === "formula" ? params.request : undefined;

  const source =
    formulaRequest
      ? formulas.find((formula) => formula.formula_id === formulaRequest.formula_id)
      : undefined;
  const adhocRequest = params.request.mode === "adhoc" ? params.request : undefined;

  if (formulaRequest && !source) {
    throw new Error(`formula not found: ${formulaRequest.formula_id}`);
  }

  const stage = source?.stage ?? adhocRequest?.stage!;
  const avgWeightKg = source?.avg_weight_kg ?? adhocRequest?.avg_weight_kg!;
  const headCount = source?.head_count ?? adhocRequest?.head_count!;
  const objective = source?.objective ?? adhocRequest?.objective!;
  const targetAdg = source?.target_adg ?? adhocRequest?.target_adg;
  const formulaItems = source?.items ?? adhocRequest?.items ?? [];
  const bannedIngredientIds = adhocRequest?.banned_ingredient_ids ?? [];
  const inventoryItems = adhocRequest?.inventory_items ?? [];

  const requirement = selectRequirementProfile(stage, avgWeightKg, targetAdg, requirementProfiles);
  const items = resolveItems(formulaItems, params.ingredients, params.farmIngredientSettings);

  const aggregates = items.reduce(
    (accumulator, item) => {
      if (item.as_fed_kg_per_head_day < 0) {
        throw new Error(`formula item as-fed kg must be non-negative: ${item.ingredient.code}`);
      }

      const nutrition = validateNutritionSnapshot(item.ingredient);
      const dmKg = item.as_fed_kg_per_head_day * (nutrition.dm_pct / 100);
      const nutrientFactor = dmKg / 100;

      accumulator.totalAsFedKg += item.as_fed_kg_per_head_day;
      accumulator.totalDmKg += dmKg;
      accumulator.ashKg += nutrientFactor * nutrition.ash_pct_dm;
      accumulator.cpKg += nutrientFactor * nutrition.cp_pct_dm;
      accumulator.tdnKg += nutrientFactor * nutrition.tdn_pct_dm;
      accumulator.ndfKg += nutrientFactor * nutrition.ndf_pct_dm;
      accumulator.adfKg += nutrientFactor * nutrition.adf_pct_dm;
      accumulator.nfcKg += nutrientFactor * nutrition.nfc_pct_dm;
      accumulator.eeKg += nutrientFactor * nutrition.ee_pct_dm;
      accumulator.caKg += nutrientFactor * nutrition.ca_pct_dm;
      accumulator.pKg += nutrientFactor * nutrition.p_pct_dm;
      accumulator.cost += item.as_fed_kg_per_head_day * item.used_price_krw_per_kg;

      return accumulator;
    },
    {
      totalAsFedKg: 0,
      totalDmKg: 0,
      ashKg: 0,
      cpKg: 0,
      tdnKg: 0,
      ndfKg: 0,
      adfKg: 0,
      nfcKg: 0,
      eeKg: 0,
      caKg: 0,
      pKg: 0,
      cost: 0,
    },
  );

  if (aggregates.totalDmKg <= 0) {
    throw new Error("analysis failed: total DM kg must be greater than 0");
  }

  const totalDmKg = aggregates.totalDmKg;
  const totalAsFedKg = Math.max(aggregates.totalAsFedKg, 0.0001);
  const measuredMoisture =
    params.request.mode === "adhoc" ? params.request.measured_moisture_pct : undefined;
  const computedMoisture = 100 - (aggregates.totalDmKg / totalAsFedKg) * 100;
  const moisturePct = measuredMoisture ?? computedMoisture;
  const caPRatio = aggregates.pKg > 0 ? aggregates.caKg / aggregates.pKg : Number.POSITIVE_INFINITY;

  const summary: AnalysisSummary = {
    total_as_fed_kg: round(aggregates.totalAsFedKg, 3),
    total_dm_kg: round(aggregates.totalDmKg, 3),
    moisture_pct: round(moisturePct, 2),
    cp_pct_dm: round((aggregates.cpKg / totalDmKg) * 100, 2),
    tdn_pct_dm: round((aggregates.tdnKg / totalDmKg) * 100, 2),
    ndf_pct_dm: round((aggregates.ndfKg / totalDmKg) * 100, 2),
    adf_pct_dm: round((aggregates.adfKg / totalDmKg) * 100, 2),
    nfc_pct_dm: round((aggregates.nfcKg / totalDmKg) * 100, 2),
    ee_pct_dm: round((aggregates.eeKg / totalDmKg) * 100, 2),
    ca_pct_dm: round((aggregates.caKg / totalDmKg) * 100, 2),
    p_pct_dm: round((aggregates.pKg / totalDmKg) * 100, 2),
    ca_p_ratio: Number.isFinite(caPRatio) ? round(caPRatio, 2) : Number.POSITIVE_INFINITY,
    cost_per_head_day: round(aggregates.cost, 2),
    cost_per_kg: round(aggregates.cost / totalAsFedKg, 2),
  };

  const targets: AnalysisTargets = {
    target_cp_pct_dm: requirement.target_cp_pct_dm,
    target_tdn_pct_dm: requirement.target_tdn_pct_dm,
    target_ndf_min_pct_dm: requirement.target_ndf_min_pct_dm,
    target_ndf_max_pct_dm: requirement.target_ndf_max_pct_dm,
    target_adf_min_pct_dm: requirement.target_adf_min_pct_dm,
    target_adf_max_pct_dm: requirement.target_adf_max_pct_dm,
    target_ca_pct_dm: requirement.target_ca_pct_dm,
    target_p_pct_dm: requirement.target_p_pct_dm,
  };

  const statuses: AnalysisStatuses = {
    status_cp: determineSingleTargetStatus(summary.cp_pct_dm, targets.target_cp_pct_dm),
    status_tdn: determineSingleTargetStatus(summary.tdn_pct_dm, targets.target_tdn_pct_dm),
    status_ndf: determineRangeStatus(summary.ndf_pct_dm, targets.target_ndf_min_pct_dm, targets.target_ndf_max_pct_dm),
    status_adf: determineRangeStatus(summary.adf_pct_dm, targets.target_adf_min_pct_dm, targets.target_adf_max_pct_dm),
    status_ca: determineSingleTargetStatus(summary.ca_pct_dm, targets.target_ca_pct_dm),
    status_p: determineSingleTargetStatus(summary.p_pct_dm, targets.target_p_pct_dm),
    status_ca_p_ratio: determineRangeStatus(summary.ca_p_ratio, CA_P_RATIO_MIN, CA_P_RATIO_MAX),
    status_moisture: determineRangeStatus(summary.moisture_pct, MOISTURE_MIN_PCT, MOISTURE_MAX_PCT),
  };

  const warnings = buildWarnings(summary, statuses, month);
  const recommendations = buildRecommendations({
    farmProfile: params.farmProfile,
    settings: params.farmIngredientSettings,
    ingredients: params.ingredients.filter(
      (ingredient) => !bannedIngredientIds.includes(ingredient.ingredient_id),
    ),
    items,
    summary,
    statuses,
  });

  const inputSnapshot = buildInputSnapshot(
    stage,
    avgWeightKg,
    headCount,
    objective,
    targetAdg,
    month,
    params.farmProfile,
    items,
    bannedIngredientIds,
    inventoryItems,
  );

  return {
    run_id: randomUUID(),
    mode: params.request.mode,
    summary,
    statuses,
    targets,
    warnings,
    recommendations,
    input_snapshot: inputSnapshot,
    created_at: new Date().toISOString(),
    ...(source ? { formula_id: source.formula_id } : {}),
  };
}
