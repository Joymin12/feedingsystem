export const USER_ROLES = ["owner", "member"] as const;
export const FARM_MEMBER_STATUSES = ["active", "invited"] as const;
export const STORAGE_LEVELS = ["low", "medium", "high"] as const;
export const WET_FEED_POLICIES = ["allowed", "seasonal", "avoid"] as const;
export const OBJECTIVES = [
  "growth",
  "cost_reduction",
  "moisture_support",
  "stability_first",
] as const;
export const FORMULA_STATUSES = ["draft", "active", "archived"] as const;
export const INGREDIENT_CATEGORIES = [
  "energy",
  "protein",
  "roughage",
  "byproduct",
  "mineral",
  "supplement",
] as const;
export const STAGES = [
  "growing_early",
  "growing_late",
  "fattening_early",
  "fattening_mid",
  "fattening_late",
  "breeding",
] as const;
export const PRICE_SOURCES = [
  "farm_setting",
  "manual_override",
  "market_default",
] as const;
export const ACTION_TYPES = ["add", "reduce", "replace", "remove"] as const;
export const NUTRIENT_STATUSES = ["deficient", "adequate", "excess"] as const;
export const WARNING_SEVERITIES = ["info", "warning", "critical"] as const;
export const ANALYSIS_MODES = ["formula", "adhoc"] as const;
export const PREFERENCE_TYPES = ["preferred", "avoided"] as const;

export type UserRole = (typeof USER_ROLES)[number];
export type FarmMemberStatus = (typeof FARM_MEMBER_STATUSES)[number];
export type StorageLevel = (typeof STORAGE_LEVELS)[number];
export type WetFeedPolicy = (typeof WET_FEED_POLICIES)[number];
export type Objective = (typeof OBJECTIVES)[number];
export type FormulaStatus = (typeof FORMULA_STATUSES)[number];
export type IngredientCategory = (typeof INGREDIENT_CATEGORIES)[number];
export type Stage = (typeof STAGES)[number];
export type PriceSource = (typeof PRICE_SOURCES)[number];
export type ActionType = (typeof ACTION_TYPES)[number];
export type NutrientStatus = (typeof NUTRIENT_STATUSES)[number];
export type WarningSeverity = (typeof WARNING_SEVERITIES)[number];
export type AnalysisMode = (typeof ANALYSIS_MODES)[number];
export type PreferenceType = (typeof PREFERENCE_TYPES)[number];
