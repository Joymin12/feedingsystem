import { z } from "zod";

/**
 * Stage는 제품의 기존 6단계 기준을 그대로 유지한다.
 * 이 enum이 바뀌면 farm profile, formula, analysis, recommendation, UI까지 연쇄적으로 흔들리므로
 * contracts 레이어에서 가장 먼저 고정해 두는 것이 안전하다.
 */
export const stageSchema = z.enum([
  "growing_early",
  "growing_late",
  "fattening_early",
  "fattening_mid",
  "fattening_late",
  "breeding"
]);

export type Stage = z.infer<typeof stageSchema>;

export const stageValues = stageSchema.options;

export const stageLabelMap: Record<Stage, string> = {
  growing_early: "육성기 전기",
  growing_late: "육성기 후기",
  fattening_early: "비육 전기",
  fattening_mid: "비육 중기",
  fattening_late: "비육 후기",
  breeding: "번식우"
};

export const storageLevelSchema = z.enum(["low", "medium", "high"]);
export type StorageLevel = z.infer<typeof storageLevelSchema>;

export const wetFeedPolicySchema = z.enum(["avoid", "limited", "preferred"]);
export type WetFeedPolicy = z.infer<typeof wetFeedPolicySchema>;

export const nutrientKeySchema = z.enum([
  "dm",
  "cp",
  "tdn",
  "ndf",
  "adf",
  "ca",
  "p",
  "moisture"
]);

export type NutrientKey = z.infer<typeof nutrientKeySchema>;

export const nutrientLabelMap: Record<NutrientKey, string> = {
  dm: "건물",
  cp: "조단백",
  tdn: "TDN",
  ndf: "NDF",
  adf: "ADF",
  ca: "칼슘",
  p: "인",
  moisture: "수분"
};

export const nutrientStatusSchema = z.enum(["deficient", "adequate", "excess"]);
export type NutrientStatus = z.infer<typeof nutrientStatusSchema>;

/**
 * formula.items는 배합안 자체를 표현하는 입력 레이어다.
 * 보유 여부나 금지 여부 같은 농장별 운영 정책은 여기 넣지 않고,
 * farm_ingredient_settings / inventory 레이어로 분리한다.
 */
export const formulaItemSchema = z.object({
  ingredient_id: z.string().min(1),
  ingredient_name: z.string().min(1),
  inclusion_percent: z.number().min(0).max(100),
  moisture_percent: z.number().min(0).max(100),
  cp_percent: z.number().min(0).max(100),
  tdn_percent: z.number().min(0).max(100),
  ndf_percent: z.number().min(0).max(100),
  adf_percent: z.number().min(0).max(100),
  ca_percent: z.number().min(0).max(100),
  p_percent: z.number().min(0).max(100)
});

export type FormulaItem = z.infer<typeof formulaItemSchema>;

/**
 * 농장별 원료 설정은 추천 엔진이 참고하는 운영 규칙 레이어다.
 * formula와 분리해 두면 같은 배합이라도 농장 정책에 따라 추천 결과를 바꿀 수 있다.
 */
export const farmIngredientSettingSchema = z.object({
  ingredient_id: z.string().min(1),
  ingredient_name: z.string().min(1),
  is_enabled: z.boolean(),
  is_banned: z.boolean(),
  is_preferred: z.boolean(),
  max_inclusion_percent: z.number().min(0).max(100).optional(),
  notes: z.string().optional()
});

export type FarmIngredientSetting = z.infer<typeof farmIngredientSettingSchema>;

/**
 * inventory는 현재 농장이 실제로 보유한 원료 재고를 표현한다.
 * 추천 엔진은 이 레이어를 먼저 보고 보유 원료 우선 조정안을 만든다.
 */
export const inventoryItemSchema = z.object({
  ingredient_id: z.string().min(1),
  ingredient_name: z.string().min(1),
  inventory_kg: z.number().min(0)
});

export type InventoryItem = z.infer<typeof inventoryItemSchema>;

/**
 * Formula는 내부 저장 모델 이름으로 유지한다.
 * 화면 문구에서만 "기본 TMR"로 바꿀 수 있고,
 * contracts/domain/api는 기존 모델 이름을 그대로 사용한다.
 */
export const formulaSchema = z.object({
  formula_id: z.string().min(1),
  farm_id: z.string().min(1),
  formula_name: z.string().min(1),
  stage: stageSchema,
  average_weight_kg: z.number().min(0),
  animal_count: z.number().int().min(1),
  target_adg: z.number().min(0),
  items: z.array(formulaItemSchema).min(1),
  notes: z.string().optional(),
  created_at: z.string(),
  updated_at: z.string()
});

export type Formula = z.infer<typeof formulaSchema>;

export const farmProfileSchema = z.object({
  farm_id: z.string().min(1),
  farm_name: z.string().min(1),
  storage_level: storageLevelSchema,
  wet_feed_policy: wetFeedPolicySchema,
  cost_priority: z.number().min(0).max(100),
  stability_priority: z.number().min(0).max(100),
  notes: z.string().optional(),
  preferred_ingredients: z.array(z.string()),
  avoided_ingredients: z.array(z.string()),
  preferred_stage: stageSchema
});

export type FarmProfile = z.infer<typeof farmProfileSchema>;

export const nutrientSnapshotSchema = z.object({
  key: nutrientKeySchema,
  label: z.string().min(1),
  current_value: z.number(),
  target_value: z.number().optional(),
  min_target_value: z.number().optional(),
  max_target_value: z.number().optional(),
  status: nutrientStatusSchema
});

export type NutrientSnapshot = z.infer<typeof nutrientSnapshotSchema>;

export const analysisRunSchema = z.object({
  run_id: z.string().min(1),
  formula_id: z.string().min(1),
  stage: stageSchema,
  preferred_stage: stageSchema,
  nutrients: z.array(nutrientSnapshotSchema).min(1),
  deficient_count: z.number().int().min(0),
  adequate_count: z.number().int().min(0),
  excess_count: z.number().int().min(0),
  auto_warnings: z.array(z.string()),
  summary: z.string().min(1),
  created_at: z.string()
});

export type AnalysisRun = z.infer<typeof analysisRunSchema>;

export const recommendationIssueSchema = z.object({
  nutrient_key: nutrientKeySchema,
  status: z.enum(["deficient", "excess"]),
  explanation: z.string().min(1)
});

export type RecommendationIssue = z.infer<typeof recommendationIssueSchema>;

export const ownedIngredientAdjustmentSchema = z.object({
  ingredient_id: z.string().min(1),
  ingredient_name: z.string().min(1),
  action: z.enum(["increase", "decrease", "maintain", "replace"]),
  reason: z.string().min(1),
  delta_percent: z.number().optional()
});

export type OwnedIngredientAdjustment = z.infer<typeof ownedIngredientAdjustmentSchema>;

export const supplementalSuggestionSchema = z.object({
  ingredient_id: z.string().min(1),
  ingredient_name: z.string().min(1),
  reason: z.string().min(1),
  caution: z.string().optional()
});

export type SupplementalSuggestion = z.infer<typeof supplementalSuggestionSchema>;

export const recommendationSchema = z.object({
  recommendation_id: z.string().min(1),
  run_id: z.string().min(1),
  formula_id: z.string().min(1),
  stage: stageSchema,
  issues: z.array(recommendationIssueSchema),
  owned_ingredient_adjustments: z.array(ownedIngredientAdjustmentSchema),
  supplemental_suggestions: z.array(supplementalSuggestionSchema),
  created_at: z.string()
});

export type Recommendation = z.infer<typeof recommendationSchema>;

export const representativeStageResultSchema = z.object({
  stage: stageSchema,
  nutrients: z.array(nutrientSnapshotSchema).min(1),
  deficient_count: z.number().int().min(0),
  adequate_count: z.number().int().min(0),
  excess_count: z.number().int().min(0)
});

export type RepresentativeStageResult = z.infer<typeof representativeStageResultSchema>;

export const stageComparisonSummarySchema = z.object({
  stage: stageSchema,
  deficient_count: z.number().int().min(0),
  adequate_count: z.number().int().min(0),
  excess_count: z.number().int().min(0)
});

export type StageComparisonSummary = z.infer<typeof stageComparisonSummarySchema>;

export const stageComparisonResponseSchema = z.object({
  preferred_stage: stageSchema,
  representative_run_id: z.string().optional(),
  representative: representativeStageResultSchema,
  comparisons: z.array(stageComparisonSummarySchema).min(1)
});

export type StageComparisonResponse = z.infer<typeof stageComparisonResponseSchema>;

export const formulaItemInputSchema = formulaItemSchema;

export type FormulaItemInput = z.infer<typeof formulaItemInputSchema>;

export const createFarmProfileSchema = farmProfileSchema.omit({ farm_id: true });
/**
 * PUT /farm/profile는 농장 프로필 전체를 갱신하는 흐름으로 취급한다.
 * preferred_stage를 포함한 핵심 필드는 항상 내려오도록 맞춰 두면
 * Android/Web 어느 쪽에서도 계약 해석이 흔들리지 않는다.
 */
export const updateFarmProfileSchema = createFarmProfileSchema;

export type CreateFarmProfileRequest = z.infer<typeof createFarmProfileSchema>;
export type UpdateFarmProfileRequest = z.infer<typeof updateFarmProfileSchema>;

export const createFormulaSchema = z.object({
  farm_id: z.string().min(1),
  formula_name: z.string().min(1),
  stage: stageSchema,
  average_weight_kg: z.number().min(0),
  animal_count: z.number().int().min(1),
  target_adg: z.number().min(0),
  items: z.array(formulaItemInputSchema).min(1),
  notes: z.string().optional()
});

export const updateFormulaSchema = createFormulaSchema.partial().extend({
  formula_id: z.string().min(1).optional()
});

export type CreateFormulaRequest = z.infer<typeof createFormulaSchema>;
export type UpdateFormulaRequest = z.infer<typeof updateFormulaSchema>;

export const createAnalysisRunSchema = z.object({
  formula_id: z.string().min(1)
});

export type CreateAnalysisRunRequest = z.infer<typeof createAnalysisRunSchema>;

export const analysisWorkflowResponseSchema = z.object({
  analysis_run: analysisRunSchema,
  recommendation: recommendationSchema,
  stage_comparison: stageComparisonResponseSchema
});

export type AnalysisWorkflowResponse = z.infer<typeof analysisWorkflowResponseSchema>;