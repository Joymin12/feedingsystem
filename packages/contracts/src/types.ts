import type {
  ActionType,
  AnalysisMode,
  FarmMemberStatus,
  FormulaStatus,
  IngredientCategory,
  NutrientStatus,
  Objective,
  PreferenceType,
  PriceSource,
  Stage,
  StorageLevel,
  UserRole,
  WarningSeverity,
  WetFeedPolicy,
} from "./enums.js";

export interface ApiErrorResponse {
  code: string;
  message: string;
  details?: string[];
  trace_id?: string;
}

export interface ApiListResponse<T> {
  items: T[];
  page?: number;
  limit?: number;
  total?: number;
}

export interface CurrentUser {
  user_id: string;
  email: string;
  name: string;
  farm_id: string;
  farm_name: string;
  role: UserRole;
}

export interface LoginRequest {
  email: string;
  password: string;
}

export interface LoginResponse {
  user: CurrentUser;
  session_token?: string;
}

export interface FarmProfile {
  farm_id: string;
  farm_name: string;
  storage_level: StorageLevel;
  wet_feed_policy: WetFeedPolicy;
  cost_priority: number;
  stability_priority: number;
  notes?: string | undefined;
  preferred_ingredients: string[];
  avoided_ingredients: string[];
}

export interface UpdateFarmProfileRequest {
  farm_name?: string | undefined;
  storage_level: StorageLevel;
  wet_feed_policy: WetFeedPolicy;
  cost_priority: number;
  stability_priority: number;
  notes?: string | undefined;
  preferred_ingredient_ids?: string[] | undefined;
  avoided_ingredient_ids?: string[] | undefined;
}

export interface FarmMember {
  user_id: string;
  email: string;
  name: string;
  role: UserRole;
  status: FarmMemberStatus;
}

export interface InviteFarmMemberRequest {
  email: string;
  name: string;
  role: UserRole;
}

export interface IngredientNutritionSnapshot {
  moisture_pct: number;
  dm_pct: number;
  ash_pct_dm: number;
  cp_pct_dm: number;
  tdn_pct_dm: number;
  ndf_pct_dm: number;
  adf_pct_dm: number;
  nfc_pct_dm: number;
  ee_pct_dm: number;
  ca_pct_dm: number;
  p_pct_dm: number;
  nfc_source: "api" | "derived";
  source: string;
  source_version: string;
  analyzed_at: string;
  trust_level: string;
}

export interface IngredientAiProfile {
  benefits: string[];
  cautions: string[];
  storage_note: string;
  palatability_note: string;
  tags: string[];
}

export interface Ingredient {
  ingredient_id: string;
  code: string;
  name_ko: string;
  category: IngredientCategory;
  default_price_krw_per_kg: number;
  description: string;
  current_nutrition: IngredientNutritionSnapshot;
  ai_profile: IngredientAiProfile;
}

export interface FarmIngredientSetting {
  ingredient_id: string;
  is_enabled: boolean;
  is_banned: boolean;
  preferred: boolean;
  avoided: boolean;
  custom_price_krw_per_kg?: number | undefined;
  inventory_kg?: number | undefined;
  price_source: PriceSource;
  note?: string | undefined;
}

export interface UpdateFarmIngredientSettingRequest {
  is_enabled?: boolean | undefined;
  is_banned?: boolean | undefined;
  preferred?: boolean | undefined;
  avoided?: boolean | undefined;
  custom_price_krw_per_kg?: number | undefined;
  inventory_kg?: number | undefined;
  price_source?: PriceSource | undefined;
  note?: string | undefined;
}

export interface FormulaItem {
  ingredient_id: string;
  as_fed_kg_per_head_day: number;
  price_override_krw_per_kg?: number | undefined;
  price_source: PriceSource;
}

export interface Formula {
  formula_id: string;
  name: string;
  stage: Stage;
  avg_weight_kg: number;
  head_count: number;
  objective: Objective;
  target_adg?: number | undefined;
  status: FormulaStatus;
  items: FormulaItem[];
  created_at?: string | undefined;
  updated_at?: string | undefined;
}

export interface CreateFormulaRequest {
  name: string;
  stage: Stage;
  avg_weight_kg: number;
  head_count: number;
  objective: Objective;
  target_adg?: number | undefined;
  status?: FormulaStatus | undefined;
  items: FormulaItem[];
}

export type UpdateFormulaRequest = CreateFormulaRequest;

export interface AnalysisInventoryItem {
  ingredient_id: string;
  available_kg: number;
}

export interface AnalysisRunFromFormulaRequest {
  mode: "formula";
  formula_id: string;
}

export interface AnalysisRunAdHocRequest {
  mode: "adhoc";
  stage: Stage;
  avg_weight_kg: number;
  head_count: number;
  objective: Objective;
  target_adg?: number | undefined;
  measured_moisture_pct?: number | undefined;
  banned_ingredient_ids?: string[] | undefined;
  inventory_items?: AnalysisInventoryItem[] | undefined;
  items: FormulaItem[];
}

export type AnalysisRunRequest =
  | AnalysisRunFromFormulaRequest
  | AnalysisRunAdHocRequest;

export interface RequirementProfile {
  id: string;
  stage: Stage;
  min_weight_kg: number;
  max_weight_kg: number;
  min_adg?: number | undefined;
  max_adg?: number | undefined;
  target_cp_pct_dm: number;
  target_tdn_pct_dm: number;
  target_ndf_min_pct_dm: number;
  target_ndf_max_pct_dm: number;
  target_adf_min_pct_dm: number;
  target_adf_max_pct_dm: number;
  target_ca_pct_dm: number;
  target_p_pct_dm: number;
  version: string;
  is_current: boolean;
}

export interface AnalysisTargets {
  target_cp_pct_dm: number;
  target_tdn_pct_dm: number;
  target_ndf_min_pct_dm: number;
  target_ndf_max_pct_dm: number;
  target_adf_min_pct_dm: number;
  target_adf_max_pct_dm: number;
  target_ca_pct_dm: number;
  target_p_pct_dm: number;
}

export interface AnalysisStatuses {
  status_cp: NutrientStatus;
  status_tdn: NutrientStatus;
  status_ndf: NutrientStatus;
  status_adf: NutrientStatus;
  status_ca: NutrientStatus;
  status_p: NutrientStatus;
  status_ca_p_ratio: NutrientStatus;
  status_moisture: NutrientStatus;
}

export interface AnalysisWarning {
  code: string;
  message: string;
  severity: WarningSeverity;
}

export interface AnalysisSummary {
  total_as_fed_kg: number;
  total_dm_kg: number;
  moisture_pct: number;
  cp_pct_dm: number;
  tdn_pct_dm: number;
  ndf_pct_dm: number;
  adf_pct_dm: number;
  nfc_pct_dm: number;
  ee_pct_dm: number;
  ca_pct_dm: number;
  p_pct_dm: number;
  ca_p_ratio: number;
  cost_per_head_day: number;
  cost_per_kg: number;
}

export interface Recommendation {
  recommendation_id: string;
  rank: number;
  action_type: ActionType;
  ingredient_id: string;
  suggested_delta_as_fed_kg: number;
  suggested_delta_dm_kg: number;
  estimated_cost_delta: number;
  estimated_changes?: Record<string, number> | undefined;
  score: number;
  reason_text: string;
  caution_text: string;
  alternative_text: string;
}

export interface RecommendationMemo {
  memo_id: string;
  recommendation_id: string;
  applied: boolean;
  memo: string;
  created_by: string;
  created_at: string;
}

export interface CreateRecommendationMemoRequest {
  applied: boolean;
  memo: string;
}

export interface AnalysisInputSnapshot {
  stage: Stage;
  avg_weight_kg: number;
  head_count: number;
  objective: Objective;
  target_adg?: number | undefined;
  season_code: string;
  items: Array<
    FormulaItem & {
      ingredient_name: string;
      used_price_krw_per_kg: number;
      source_version: string;
      nutrition_snapshot: IngredientNutritionSnapshot;
    }
  >;
  farm_profile_summary: {
    storage_level: StorageLevel;
    wet_feed_policy: WetFeedPolicy;
    cost_priority: number;
    stability_priority: number;
  };
  banned_ingredient_ids: string[];
  inventory_items: AnalysisInventoryItem[];
}

export interface AnalysisRun {
  run_id: string;
  formula_id?: string | undefined;
  mode: AnalysisMode;
  summary: AnalysisSummary;
  statuses: AnalysisStatuses;
  targets: AnalysisTargets;
  warnings: AnalysisWarning[];
  recommendations: Recommendation[];
  input_snapshot: AnalysisInputSnapshot;
  created_at: string;
}

export interface SeedIngredientRecord {
  code: string;
  name_ko: string;
  category: IngredientCategory;
  default_price_krw_per_kg: number;
  description: string;
  nutrition: IngredientNutritionSnapshot;
  ai_profile: IngredientAiProfile;
}

export interface FarmIngredientPreferenceRecord {
  ingredient_id: string;
  preference_type: PreferenceType;
}
