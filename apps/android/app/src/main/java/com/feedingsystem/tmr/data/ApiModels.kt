package com.feedingsystem.tmr.data

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * API 계약은 apps/api와 packages/contracts의 응답 구조를 기준으로 맞춘다.
 * 안드로이드 화면은 이 DTO를 다시 계산하지 않고 그대로 표시/편집만 한다.
 */
@Serializable
enum class Stage(val label: String) {
    @SerialName("growing_early")
    GROWING_EARLY("육성기 전기"),

    @SerialName("growing_late")
    GROWING_LATE("육성기 후기"),

    @SerialName("fattening_early")
    FATTENING_EARLY("비육 전기"),

    @SerialName("fattening_mid")
    FATTENING_MID("비육 중기"),

    @SerialName("fattening_late")
    FATTENING_LATE("비육 후기"),

    @SerialName("breeding")
    BREEDING("번식우")
}

@Serializable
data class FarmProfileDto(
    @SerialName("farm_id") val farmId: String,
    @SerialName("farm_name") val farmName: String,
    @SerialName("storage_level") val storageLevel: String,
    @SerialName("wet_feed_policy") val wetFeedPolicy: String,
    @SerialName("cost_priority") val costPriority: Int,
    @SerialName("stability_priority") val stabilityPriority: Int,
    val notes: String? = null,
    @SerialName("preferred_ingredients") val preferredIngredients: List<String>,
    @SerialName("avoided_ingredients") val avoidedIngredients: List<String>,
    @SerialName("preferred_stage") val preferredStage: Stage
)

@Serializable
data class FarmProfileUpdateRequest(
    @SerialName("farm_name") val farmName: String,
    @SerialName("storage_level") val storageLevel: String,
    @SerialName("wet_feed_policy") val wetFeedPolicy: String,
    @SerialName("cost_priority") val costPriority: Int,
    @SerialName("stability_priority") val stabilityPriority: Int,
    val notes: String? = null,
    @SerialName("preferred_ingredients") val preferredIngredients: List<String>,
    @SerialName("avoided_ingredients") val avoidedIngredients: List<String>,
    @SerialName("preferred_stage") val preferredStage: Stage
)

@Serializable
data class FormulaItemDto(
    @SerialName("ingredient_id") val ingredientId: String,
    @SerialName("ingredient_name") val ingredientName: String,
    @SerialName("inclusion_percent") val inclusionPercent: Double,
    @SerialName("moisture_percent") val moisturePercent: Double,
    @SerialName("cp_percent") val cpPercent: Double,
    @SerialName("tdn_percent") val tdnPercent: Double,
    @SerialName("ndf_percent") val ndfPercent: Double,
    @SerialName("adf_percent") val adfPercent: Double,
    @SerialName("ca_percent") val caPercent: Double,
    @SerialName("p_percent") val pPercent: Double
)

@Serializable
data class FormulaDto(
    @SerialName("formula_id") val formulaId: String,
    @SerialName("farm_id") val farmId: String,
    @SerialName("formula_name") val formulaName: String,
    val stage: Stage,
    @SerialName("average_weight_kg") val averageWeightKg: Double,
    @SerialName("animal_count") val animalCount: Int,
    @SerialName("target_adg") val targetAdg: Double,
    val items: List<FormulaItemDto>,
    val notes: String? = null,
    @SerialName("created_at") val createdAt: String,
    @SerialName("updated_at") val updatedAt: String
)

@Serializable
data class SaveFormulaRequest(
    @SerialName("farm_id") val farmId: String,
    @SerialName("formula_name") val formulaName: String,
    val stage: Stage,
    @SerialName("average_weight_kg") val averageWeightKg: Double,
    @SerialName("animal_count") val animalCount: Int,
    @SerialName("target_adg") val targetAdg: Double,
    val items: List<FormulaItemDto>,
    val notes: String? = null
)

@Serializable
data class CreateAnalysisRunRequest(
    @SerialName("formula_id") val formulaId: String
)

@Serializable
data class NutrientSnapshotDto(
    val key: String,
    val label: String,
    @SerialName("current_value") val currentValue: Double,
    @SerialName("target_value") val targetValue: Double? = null,
    @SerialName("min_target_value") val minTargetValue: Double? = null,
    @SerialName("max_target_value") val maxTargetValue: Double? = null,
    val status: String
)

@Serializable
data class AnalysisRunDto(
    @SerialName("run_id") val runId: String,
    @SerialName("formula_id") val formulaId: String,
    val stage: Stage,
    @SerialName("preferred_stage") val preferredStage: Stage,
    val nutrients: List<NutrientSnapshotDto>,
    @SerialName("deficient_count") val deficientCount: Int,
    @SerialName("adequate_count") val adequateCount: Int,
    @SerialName("excess_count") val excessCount: Int,
    @SerialName("auto_warnings") val autoWarnings: List<String>,
    val summary: String,
    @SerialName("created_at") val createdAt: String
)

@Serializable
data class RecommendationIssueDto(
    @SerialName("nutrient_key") val nutrientKey: String,
    val status: String,
    val explanation: String
)

@Serializable
data class OwnedIngredientAdjustmentDto(
    @SerialName("ingredient_id") val ingredientId: String,
    @SerialName("ingredient_name") val ingredientName: String,
    val action: String,
    val reason: String,
    @SerialName("delta_percent") val deltaPercent: Double? = null
)

@Serializable
data class SupplementalSuggestionDto(
    @SerialName("ingredient_id") val ingredientId: String,
    @SerialName("ingredient_name") val ingredientName: String,
    val reason: String,
    val caution: String? = null
)

@Serializable
data class RecommendationDto(
    @SerialName("recommendation_id") val recommendationId: String,
    @SerialName("run_id") val runId: String,
    @SerialName("formula_id") val formulaId: String,
    val stage: Stage,
    val issues: List<RecommendationIssueDto>,
    @SerialName("owned_ingredient_adjustments") val ownedIngredientAdjustments: List<OwnedIngredientAdjustmentDto>,
    @SerialName("supplemental_suggestions") val supplementalSuggestions: List<SupplementalSuggestionDto>,
    @SerialName("created_at") val createdAt: String
)

@Serializable
data class RepresentativeStageResultDto(
    val stage: Stage,
    val nutrients: List<NutrientSnapshotDto>,
    @SerialName("deficient_count") val deficientCount: Int,
    @SerialName("adequate_count") val adequateCount: Int,
    @SerialName("excess_count") val excessCount: Int
)

@Serializable
data class StageComparisonSummaryDto(
    val stage: Stage,
    @SerialName("deficient_count") val deficientCount: Int,
    @SerialName("adequate_count") val adequateCount: Int,
    @SerialName("excess_count") val excessCount: Int
)

@Serializable
data class StageComparisonResponseDto(
    @SerialName("preferred_stage") val preferredStage: Stage,
    @SerialName("representative_run_id") val representativeRunId: String? = null,
    val representative: RepresentativeStageResultDto,
    val comparisons: List<StageComparisonSummaryDto>
)

@Serializable
data class AnalysisWorkflowResponseDto(
    @SerialName("analysis_run") val analysisRun: AnalysisRunDto,
    val recommendation: RecommendationDto,
    @SerialName("stage_comparison") val stageComparison: StageComparisonResponseDto
)