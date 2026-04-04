import type {
  AnalysisRun,
  FarmIngredientSetting,
  FarmProfile,
  Formula,
  FormulaItem,
  InventoryItem,
  NutrientKey,
  NutrientSnapshot,
  NutrientStatus,
  Recommendation,
  RecommendationIssue,
  RepresentativeStageResult,
  Stage,
  StageComparisonResponse,
  StageComparisonSummary
} from "@hanwoo-tmr/contracts";
import {
  nutrientLabelMap,
  recommendationSchema,
  stageComparisonResponseSchema,
  stageLabelMap
} from "@hanwoo-tmr/contracts";
import { STAGE_TARGETS } from "../constants/stage-targets";
import { clamp, round } from "../utils/math";

export type FormulaStageEvaluation = {
  stage: Stage;
  nutrients: NutrientSnapshot[];
  deficient_count: number;
  adequate_count: number;
  excess_count: number;
};

export type RecommendationContext = {
  farmProfile: FarmProfile;
  farmIngredientSettings: FarmIngredientSetting[];
  inventory: InventoryItem[];
};

type OwnedCandidate = {
  item: FormulaItem;
  inventory_kg: number;
  setting?: FarmIngredientSetting;
};

const STAGE_ORDER: Stage[] = [
  "growing_early",
  "growing_late",
  "fattening_early",
  "fattening_mid",
  "fattening_late",
  "breeding"
];

const EXTERNAL_SUGGESTION_LIBRARY: Record<NutrientKey, { ingredient_id: string; ingredient_name: string; caution: string }> = {
  dm: {
    ingredient_id: "dry_forage_mix",
    ingredient_name: "건조 조사료 믹스",
    caution: "건물 비율 조정은 섭취량 변화를 함께 봐야 합니다."
  },
  cp: {
    ingredient_id: "soybean_meal",
    ingredient_name: "대두박",
    caution: "단백질 과보강이 되지 않도록 단계별로 증량합니다."
  },
  tdn: {
    ingredient_id: "corn_grain",
    ingredient_name: "옥수수 곡물",
    caution: "에너지 보강 시 산증 리스크를 함께 점검합니다."
  },
  ndf: {
    ingredient_id: "alfalfa_hay",
    ingredient_name: "알팔파 건초",
    caution: "섬유 보강은 반추 안정성 회복 속도에 맞춰 점진적으로 적용합니다."
  },
  adf: {
    ingredient_id: "rice_straw",
    ingredient_name: "볏짚",
    caution: "과도한 ADF 증가는 섭취량 저하를 부를 수 있습니다."
  },
  ca: {
    ingredient_id: "limestone",
    ingredient_name: "석회석",
    caution: "칼슘 보강 시 인과의 비율을 함께 확인해야 합니다."
  },
  p: {
    ingredient_id: "dcp",
    ingredient_name: "인산칼슘",
    caution: "칼슘-인 균형을 같이 관리해야 합니다."
  },
  moisture: {
    ingredient_id: "wet_silage",
    ingredient_name: "습식 사일리지",
    caution: "수분 보정은 저장성과 기호성을 동시에 점검합니다."
  }
};

function getItemSignal(item: FormulaItem, key: NutrientKey): number {
  if (key === "dm") {
    return 100 - item.moisture_percent;
  }

  if (key === "moisture") {
    return item.moisture_percent;
  }

  if (key === "cp") {
    return item.cp_percent;
  }

  if (key === "tdn") {
    return item.tdn_percent;
  }

  if (key === "ndf") {
    return item.ndf_percent;
  }

  if (key === "adf") {
    return item.adf_percent;
  }

  if (key === "ca") {
    return item.ca_percent;
  }

  return item.p_percent;
}

function calculateWeightedNutrients(formula: Formula): Record<NutrientKey, number> {
  const totalInclusion = formula.items.reduce((sum, item) => sum + item.inclusion_percent, 0) || 1;

  const aggregate = formula.items.reduce(
    (sum, item) => {
      const share = item.inclusion_percent / totalInclusion;

      sum.dm += share * (100 - item.moisture_percent);
      sum.cp += share * item.cp_percent;
      sum.tdn += share * item.tdn_percent;
      sum.ndf += share * item.ndf_percent;
      sum.adf += share * item.adf_percent;
      sum.ca += share * item.ca_percent;
      sum.p += share * item.p_percent;
      sum.moisture += share * item.moisture_percent;

      return sum;
    },
    { dm: 0, cp: 0, tdn: 0, ndf: 0, adf: 0, ca: 0, p: 0, moisture: 0 }
  );

  return {
    dm: round(aggregate.dm, 1),
    cp: round(aggregate.cp, 1),
    tdn: round(aggregate.tdn, 1),
    ndf: round(aggregate.ndf, 1),
    adf: round(aggregate.adf, 1),
    ca: round(aggregate.ca, 2),
    p: round(aggregate.p, 2),
    moisture: round(aggregate.moisture, 1)
  };
}

function classifyNutrient(value: number, min: number, max: number): NutrientStatus {
  if (value < min) {
    return "deficient";
  }

  if (value > max) {
    return "excess";
  }

  return "adequate";
}

function buildEvaluation(formula: Formula, stage: Stage): FormulaStageEvaluation {
  const targets = STAGE_TARGETS[stage].nutrientTargets;
  const values = calculateWeightedNutrients(formula);

  const nutrients: NutrientSnapshot[] = (Object.keys(values) as NutrientKey[]).map((key) => {
    const target = targets[key];
    const current_value = values[key];
    const status = classifyNutrient(current_value, target.min, target.max);

    return {
      key,
      label: nutrientLabelMap[key],
      current_value,
      target_value: target.target,
      min_target_value: target.min,
      max_target_value: target.max,
      status
    };
  });

  return {
    stage,
    nutrients,
    deficient_count: nutrients.filter((item) => item.status === "deficient").length,
    adequate_count: nutrients.filter((item) => item.status === "adequate").length,
    excess_count: nutrients.filter((item) => item.status === "excess").length
  };
}

function buildRepresentativeStageResult(evaluation: FormulaStageEvaluation): RepresentativeStageResult {
  return {
    stage: evaluation.stage,
    nutrients: evaluation.nutrients,
    deficient_count: evaluation.deficient_count,
    adequate_count: evaluation.adequate_count,
    excess_count: evaluation.excess_count
  };
}

function buildComparisonSummary(evaluation: FormulaStageEvaluation): StageComparisonSummary {
  return {
    stage: evaluation.stage,
    deficient_count: evaluation.deficient_count,
    adequate_count: evaluation.adequate_count,
    excess_count: evaluation.excess_count
  };
}

function buildIssueExplanation(nutrient: NutrientSnapshot): string {
  if (nutrient.status === "deficient") {
    return `${nutrient.label}가 목표 하한보다 ${round((nutrient.min_target_value ?? nutrient.current_value) - nutrient.current_value, 1)} 낮습니다.`;
  }

  return `${nutrient.label}가 목표 상한보다 ${round(nutrient.current_value - (nutrient.max_target_value ?? nutrient.current_value), 1)} 높습니다.`;
}

function buildOwnedAdjustmentReason(issue: RecommendationIssue): string {
  return `보유 원료 우선 원칙에 따라 ${nutrientLabelMap[issue.nutrient_key]} 보완용 1차 조정안으로 선택했습니다.`;
}

function buildReductionReason(issue: RecommendationIssue): string {
  return `${nutrientLabelMap[issue.nutrient_key]} 과잉 신호를 낮추기 위해 현재 배합 내 해당 원료 감량을 우선 제안합니다.`;
}

function buildMaintainReason(): string {
  return "현재 배합은 큰 조정 없이 유지 가능해 보이며, 다음 분석 주기까지 관찰을 권장합니다.";
}

function buildSupplementalReason(issue: RecommendationIssue): string {
  return `보유 원료만으로 ${nutrientLabelMap[issue.nutrient_key]} 부족 대응이 어려워 외부 후보를 제시합니다.`;
}

function buildSettingMap(context: RecommendationContext): Map<string, FarmIngredientSetting> {
  return new Map(context.farmIngredientSettings.map((item) => [item.ingredient_id, item]));
}

function buildInventoryMap(context: RecommendationContext): Map<string, InventoryItem> {
  return new Map(context.inventory.map((item) => [item.ingredient_id, item]));
}

function isBlockedIngredient(ingredientId: string, context: RecommendationContext): boolean {
  const setting = buildSettingMap(context).get(ingredientId);
  return setting?.is_banned === true || context.farmProfile.avoided_ingredients.includes(ingredientId);
}

function isPreferredIngredient(ingredientId: string, context: RecommendationContext, setting?: FarmIngredientSetting): boolean {
  return setting?.is_preferred === true || context.farmProfile.preferred_ingredients.includes(ingredientId);
}

function getOwnedCandidatePool(formula: Formula, context: RecommendationContext): OwnedCandidate[] {
  const settingMap = buildSettingMap(context);
  const inventoryMap = buildInventoryMap(context);

  return formula.items
    .filter((item) => !isBlockedIngredient(item.ingredient_id, context))
    .map((item) => ({
      item,
      setting: settingMap.get(item.ingredient_id),
      inventory_kg: inventoryMap.get(item.ingredient_id)?.inventory_kg ?? 0
    }))
    .filter(({ item, setting, inventory_kg }) => inventory_kg > 0 || item.inclusion_percent > 0 || setting?.is_enabled === true);
}

function pickOwnedCandidate(
  formula: Formula,
  nutrient: RecommendationIssue,
  context: RecommendationContext
): OwnedCandidate | undefined {
  return [...getOwnedCandidatePool(formula, context)]
    .sort((left, right) => {
      const rightScore =
        getItemSignal(right.item, nutrient.nutrient_key) +
        right.item.inclusion_percent * 0.2 +
        (right.inventory_kg > 0 ? 5 : 0) +
        (isPreferredIngredient(right.item.ingredient_id, context, right.setting) ? 4 : 0);
      const leftScore =
        getItemSignal(left.item, nutrient.nutrient_key) +
        left.item.inclusion_percent * 0.2 +
        (left.inventory_kg > 0 ? 5 : 0) +
        (isPreferredIngredient(left.item.ingredient_id, context, left.setting) ? 4 : 0);
      return rightScore - leftScore;
    })
    .find(({ item }) => getItemSignal(item, nutrient.nutrient_key) > 0);
}

function pickReductionCandidate(
  formula: Formula,
  nutrient: RecommendationIssue,
  context: RecommendationContext
): FormulaItem | undefined {
  return [...formula.items]
    .filter((item) => !isBlockedIngredient(item.ingredient_id, context) && item.inclusion_percent > 0)
    .sort((left, right) => {
      const rightScore = getItemSignal(right, nutrient.nutrient_key) + right.inclusion_percent * 0.4;
      const leftScore = getItemSignal(left, nutrient.nutrient_key) + left.inclusion_percent * 0.4;
      return rightScore - leftScore;
    })[0];
}

function buildSupplementalSuggestion(issue: RecommendationIssue, context: RecommendationContext) {
  const libraryCandidate = EXTERNAL_SUGGESTION_LIBRARY[issue.nutrient_key];

  if (!isBlockedIngredient(libraryCandidate.ingredient_id, context)) {
    return {
      ingredient_id: libraryCandidate.ingredient_id,
      ingredient_name: libraryCandidate.ingredient_name,
      reason: buildSupplementalReason(issue),
      caution: libraryCandidate.caution
    };
  }

  return {
    ingredient_id: `external_${issue.nutrient_key}`,
    ingredient_name: `${nutrientLabelMap[issue.nutrient_key]} 보강용 외부 원료`,
    reason: `${nutrientLabelMap[issue.nutrient_key]} 보강은 필요하지만 농장 금지 원료를 제외한 대체 후보를 별도 검토해야 합니다.`,
    caution: "금지 원료는 제외한 상태에서 외부 조달 후보를 다시 확인하세요."
  };
}

function buildAutoWarnings(evaluation: FormulaStageEvaluation): string[] {
  const warnings: string[] = [];

  if (evaluation.nutrients.some((item) => item.key === "ndf" && item.status === "deficient")) {
    warnings.push("NDF 부족 신호가 있어 반추 안정성과 산증 리스크를 우선 확인해야 합니다.");
  }

  if (evaluation.nutrients.some((item) => item.key === "tdn" && item.status === "excess")) {
    warnings.push("TDN 과잉 신호가 있어 농후사료 편중 여부를 다시 확인하는 것이 좋습니다.");
  }

  if (evaluation.nutrients.some((item) => item.key === "cp" && item.status === "deficient")) {
    warnings.push("조단백 부족으로 목표 ADG가 둔화될 수 있습니다.");
  }

  return warnings;
}

export function analyzeFormulaForStage(formula: Formula, stage: Stage): FormulaStageEvaluation {
  return buildEvaluation(formula, stage);
}

export function buildAnalysisRun(formula: Formula, preferredStage: Stage, runId: string, createdAt: string): AnalysisRun {
  const evaluation = buildEvaluation(formula, preferredStage);
  const issueCount = evaluation.deficient_count + evaluation.excess_count;

  return {
    run_id: runId,
    formula_id: formula.formula_id,
    stage: preferredStage,
    preferred_stage: preferredStage,
    nutrients: evaluation.nutrients,
    deficient_count: evaluation.deficient_count,
    adequate_count: evaluation.adequate_count,
    excess_count: evaluation.excess_count,
    auto_warnings: buildAutoWarnings(evaluation),
    summary:
      issueCount === 0
        ? `${stageLabelMap[preferredStage]} 기준에서 큰 불균형 없이 운영 가능한 상태입니다.`
        : `${stageLabelMap[preferredStage]} 기준으로 ${issueCount}개 항목이 우선 조정 대상으로 나타났습니다.`,
    created_at: createdAt
  };
}

export function compareFormulaAcrossStages(formula: Formula, preferredStage: Stage): StageComparisonResponse {
  const evaluations = STAGE_ORDER.map((stage) => buildEvaluation(formula, stage));
  const representative = evaluations.find((item) => item.stage === preferredStage);

  return stageComparisonResponseSchema.parse({
    preferred_stage: preferredStage,
    representative_run_id: undefined,
    representative: buildRepresentativeStageResult(representative ?? buildEvaluation(formula, preferredStage)),
    comparisons: evaluations.map(buildComparisonSummary)
  });
}

/**
 * 추천 엔진은 계산 결과를 입력으로 받아 별도 컨텍스트를 해석한다.
 * formula 자체에는 원료 성분과 배합 비율만 남기고,
 * 보유 원료/금지 원료/재고 여부는 RecommendationContext에서만 읽는다.
 */
export function buildRecommendation(
  formula: Formula,
  evaluation: FormulaStageEvaluation,
  runId: string,
  createdAt: string,
  context: RecommendationContext
): Recommendation {
  const issues = evaluation.nutrients
    .filter((item) => item.status !== "adequate")
    .map((item) => ({
      nutrient_key: item.key,
      status: item.status as "deficient" | "excess",
      explanation: buildIssueExplanation(item)
    }));

  const owned_ingredient_adjustments: Recommendation["owned_ingredient_adjustments"] = [];
  const supplemental_suggestions: Recommendation["supplemental_suggestions"] = [];
  const ownedIds = new Set<string>();
  const supplementalIds = new Set<string>();

  for (const issue of issues) {
    if (issue.status === "deficient") {
      const ownedCandidate = pickOwnedCandidate(formula, issue, context);

      if (ownedCandidate && !ownedIds.has(ownedCandidate.item.ingredient_id)) {
        const targetNutrient = evaluation.nutrients.find((item) => item.key === issue.nutrient_key);
        const gap = targetNutrient ? Math.abs((targetNutrient.min_target_value ?? targetNutrient.current_value) - targetNutrient.current_value) : 1;

        owned_ingredient_adjustments.push({
          ingredient_id: ownedCandidate.item.ingredient_id,
          ingredient_name: ownedCandidate.item.ingredient_name,
          action: "increase",
          reason: buildOwnedAdjustmentReason(issue),
          delta_percent: round(clamp(gap / 2, 1, 4), 1)
        });
        ownedIds.add(ownedCandidate.item.ingredient_id);
        continue;
      }

      const supplemental = buildSupplementalSuggestion(issue, context);
      if (!supplementalIds.has(supplemental.ingredient_id)) {
        supplemental_suggestions.push(supplemental);
        supplementalIds.add(supplemental.ingredient_id);
      }
      continue;
    }

    const reductionCandidate = pickReductionCandidate(formula, issue, context);
    if (reductionCandidate && !ownedIds.has(reductionCandidate.ingredient_id)) {
      const targetNutrient = evaluation.nutrients.find((item) => item.key === issue.nutrient_key);
      const excess = targetNutrient ? Math.abs(targetNutrient.current_value - (targetNutrient.max_target_value ?? targetNutrient.current_value)) : 1;

      owned_ingredient_adjustments.push({
        ingredient_id: reductionCandidate.ingredient_id,
        ingredient_name: reductionCandidate.ingredient_name,
        action: "decrease",
        reason: buildReductionReason(issue),
        delta_percent: round(clamp(excess / 2, 1, 4), 1)
      });
      ownedIds.add(reductionCandidate.ingredient_id);
    }
  }

  if (owned_ingredient_adjustments.length === 0) {
    const fallback = formula.items.find((item) => !isBlockedIngredient(item.ingredient_id, context)) ?? formula.items[0];
    if (fallback) {
      owned_ingredient_adjustments.push({
        ingredient_id: fallback.ingredient_id,
        ingredient_name: fallback.ingredient_name,
        action: "maintain",
        reason: buildMaintainReason(),
        delta_percent: 0
      });
    }
  }

  return recommendationSchema.parse({
    recommendation_id: `rec_${runId}`,
    run_id: runId,
    formula_id: formula.formula_id,
    stage: evaluation.stage,
    issues,
    owned_ingredient_adjustments,
    supplemental_suggestions,
    created_at: createdAt
  });
}

export function createStageComparisonWithRepresentative(
  formula: Formula,
  preferredStage: Stage,
  representativeRunId?: string
): StageComparisonResponse {
  const response = compareFormulaAcrossStages(formula, preferredStage);

  return {
    ...response,
    representative_run_id: representativeRunId
  };
}

export function runAnalysisWorkflow(
  formula: Formula,
  preferredStage: Stage,
  runId: string,
  createdAt: string,
  context: RecommendationContext
) {
  const evaluation = buildEvaluation(formula, preferredStage);

  return {
    analysisRun: buildAnalysisRun(formula, preferredStage, runId, createdAt),
    recommendation: buildRecommendation(formula, evaluation, runId, createdAt, context),
    stageComparison: createStageComparisonWithRepresentative(formula, preferredStage, runId)
  };
}