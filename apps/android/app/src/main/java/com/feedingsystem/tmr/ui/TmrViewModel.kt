package com.feedingsystem.tmr.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.feedingsystem.tmr.data.AnalysisWorkflowResponseDto
import com.feedingsystem.tmr.data.FarmProfileDto
import com.feedingsystem.tmr.data.FarmProfileUpdateRequest
import com.feedingsystem.tmr.data.FormulaDto
import com.feedingsystem.tmr.data.FormulaItemDto
import com.feedingsystem.tmr.data.SaveFormulaRequest
import com.feedingsystem.tmr.data.Stage
import com.feedingsystem.tmr.data.StageComparisonResponseDto
import com.feedingsystem.tmr.data.TmrRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

enum class TmrTab(val title: String) {
    HOME("홈"),
    FORMULA("배합"),
    RECOMMEND("추천"),
    COMMUNITY("커뮤니티"),
    FARM("농장")
}

data class FarmProfileDraft(
    val farmName: String = "",
    val storageLevel: String = "medium",
    val wetFeedPolicy: String = "limited",
    val costPriority: String = "0",
    val stabilityPriority: String = "0",
    val preferredStage: Stage = Stage.FATTENING_MID,
    val preferredIngredientsText: String = "",
    val avoidedIngredientsText: String = "",
    val notes: String = ""
)

data class FormulaItemDraft(
    val ingredientId: String,
    val ingredientName: String,
    val inclusionPercent: String,
    val moisturePercent: String,
    val cpPercent: String,
    val tdnPercent: String,
    val ndfPercent: String,
    val adfPercent: String,
    val caPercent: String,
    val pPercent: String
)

data class FormulaDraft(
    val formulaId: String = "",
    val farmId: String = "",
    val formulaName: String = "",
    val stage: Stage = Stage.FATTENING_MID,
    val averageWeightKg: String = "0",
    val animalCount: String = "0",
    val targetAdg: String = "0",
    val notes: String = "",
    val items: List<FormulaItemDraft> = emptyList()
)

data class CommunityPost(
    val category: String,
    val title: String,
    val body: String,
    val author: String,
    val timeLabel: String,
    val accent: Long,
    val badge: String? = null,
    val stats: String
)

data class TmrUiState(
    val currentTab: TmrTab = TmrTab.HOME,
    val isLoading: Boolean = true,
    val errorMessage: String? = null,
    val farmProfile: FarmProfileDto? = null,
    val formulas: List<FormulaDto> = emptyList(),
    val selectedFormula: FormulaDto? = null,
    val stageComparison: StageComparisonResponseDto? = null,
    val workflow: AnalysisWorkflowResponseDto? = null,
    val farmDraft: FarmProfileDraft = FarmProfileDraft(),
    val formulaDraft: FormulaDraft = FormulaDraft(),
    val communityPosts: List<CommunityPost> = communitySeedPosts
)

class TmrViewModel(
    private val repository: TmrRepository = TmrRepository()
) : ViewModel() {
    private val _uiState = MutableStateFlow(TmrUiState())
    val uiState: StateFlow<TmrUiState> = _uiState

    init {
        refreshAll()
    }

    fun changeTab(tab: TmrTab) {
        _uiState.update { it.copy(currentTab = tab) }
    }

    fun refreshAll() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, errorMessage = null) }
            runCatching {
                val profile = repository.loadFarmProfile()
                val formulas = repository.loadFormulas()
                val selectedFormula = formulas.firstOrNull()
                val stageComparison = selectedFormula?.let { repository.loadStageComparison(it.formulaId) }
                val workflow = stageComparison?.representativeRunId?.let { repository.loadAnalysisRun(it) }

                _uiState.update {
                    it.copy(
                        isLoading = false,
                        farmProfile = profile,
                        formulas = formulas,
                        selectedFormula = selectedFormula,
                        stageComparison = stageComparison,
                        workflow = workflow,
                        farmDraft = profile.toDraft(),
                        formulaDraft = selectedFormula?.toDraft() ?: FormulaDraft(farmId = profile.farmId)
                    )
                }
            }.onFailure { error ->
                _uiState.update {
                    it.copy(isLoading = false, errorMessage = error.message ?: "API 연결에 실패했습니다.")
                }
            }
        }
    }

    fun updateFarmDraft(transform: FarmProfileDraft.() -> FarmProfileDraft) {
        _uiState.update { it.copy(farmDraft = it.farmDraft.transform()) }
    }

    fun saveFarmProfile() {
        viewModelScope.launch {
            val draft = _uiState.value.farmDraft
            _uiState.update { it.copy(isLoading = true, errorMessage = null) }
            runCatching {
                val updated = repository.updateFarmProfile(draft.toRequest())
                val selectedFormula = _uiState.value.selectedFormula
                val stageComparison = selectedFormula?.let { repository.loadStageComparison(it.formulaId) }
                val workflow = stageComparison?.representativeRunId?.let { repository.loadAnalysisRun(it) }

                _uiState.update {
                    it.copy(
                        isLoading = false,
                        farmProfile = updated,
                        farmDraft = updated.toDraft(),
                        stageComparison = stageComparison,
                        workflow = workflow,
                        currentTab = TmrTab.HOME
                    )
                }
            }.onFailure { error ->
                _uiState.update { it.copy(isLoading = false, errorMessage = error.message ?: "농장 설정 저장 실패") }
            }
        }
    }

    fun updateFormulaDraft(transform: FormulaDraft.() -> FormulaDraft) {
        _uiState.update { it.copy(formulaDraft = it.formulaDraft.transform()) }
    }

    fun addFormulaItem() {
        _uiState.update {
            it.copy(
                formulaDraft = it.formulaDraft.copy(
                    items = it.formulaDraft.items + FormulaItemDraft(
                        ingredientId = "new_ingredient",
                        ingredientName = "신규 원료",
                        inclusionPercent = "0",
                        moisturePercent = "12",
                        cpPercent = "0",
                        tdnPercent = "0",
                        ndfPercent = "0",
                        adfPercent = "0",
                        caPercent = "0",
                        pPercent = "0"
                    )
                )
            )
        }
    }

    fun updateFormulaItem(index: Int, transform: FormulaItemDraft.() -> FormulaItemDraft) {
        _uiState.update {
            it.copy(
                formulaDraft = it.formulaDraft.copy(
                    items = it.formulaDraft.items.mapIndexed { itemIndex, item ->
                        if (itemIndex == index) item.transform() else item
                    }
                )
            )
        }
    }

    fun removeFormulaItem(index: Int) {
        _uiState.update {
            it.copy(
                formulaDraft = it.formulaDraft.copy(
                    items = it.formulaDraft.items.filterIndexed { itemIndex, _ -> itemIndex != index }
                )
            )
        }
    }

    fun saveFormulaAndAnalyze() {
        viewModelScope.launch {
            val draft = _uiState.value.formulaDraft
            if (draft.formulaId.isBlank()) {
                _uiState.update { it.copy(errorMessage = "수정할 기본 TMR 데이터가 없습니다.") }
                return@launch
            }

            _uiState.update { it.copy(isLoading = true, errorMessage = null) }
            runCatching {
                val savedFormula = repository.updateFormula(draft.formulaId, draft.toRequest())
                val workflow = repository.runAnalysis(savedFormula.formulaId)
                val stageComparison = repository.loadStageComparison(savedFormula.formulaId)

                _uiState.update {
                    it.copy(
                        isLoading = false,
                        selectedFormula = savedFormula,
                        formulas = listOf(savedFormula) + it.formulas.filterNot { formula -> formula.formulaId == savedFormula.formulaId },
                        formulaDraft = savedFormula.toDraft(),
                        workflow = workflow,
                        stageComparison = stageComparison,
                        currentTab = TmrTab.RECOMMEND
                    )
                }
            }.onFailure { error ->
                _uiState.update { it.copy(isLoading = false, errorMessage = error.message ?: "분석 실행 실패") }
            }
        }
    }
}

private fun FarmProfileDto.toDraft(): FarmProfileDraft = FarmProfileDraft(
    farmName = farmName,
    storageLevel = storageLevel,
    wetFeedPolicy = wetFeedPolicy,
    costPriority = costPriority.toString(),
    stabilityPriority = stabilityPriority.toString(),
    preferredStage = preferredStage,
    preferredIngredientsText = preferredIngredients.joinToString(", "),
    avoidedIngredientsText = avoidedIngredients.joinToString(", "),
    notes = notes.orEmpty()
)

private fun FarmProfileDraft.toRequest(): FarmProfileUpdateRequest = FarmProfileUpdateRequest(
    farmName = farmName,
    storageLevel = storageLevel,
    wetFeedPolicy = wetFeedPolicy,
    costPriority = costPriority.toIntOrNull() ?: 0,
    stabilityPriority = stabilityPriority.toIntOrNull() ?: 0,
    preferredStage = preferredStage,
    preferredIngredients = preferredIngredientsText.split(",").map { it.trim() }.filter { it.isNotBlank() },
    avoidedIngredients = avoidedIngredientsText.split(",").map { it.trim() }.filter { it.isNotBlank() },
    notes = notes.ifBlank { null }
)

private fun FormulaDto.toDraft(): FormulaDraft = FormulaDraft(
    formulaId = formulaId,
    farmId = farmId,
    formulaName = formulaName,
    stage = stage,
    averageWeightKg = averageWeightKg.toString(),
    animalCount = animalCount.toString(),
    targetAdg = targetAdg.toString(),
    notes = notes.orEmpty(),
    items = items.map { it.toDraft() }
)

private fun FormulaItemDto.toDraft(): FormulaItemDraft = FormulaItemDraft(
    ingredientId = ingredientId,
    ingredientName = ingredientName,
    inclusionPercent = inclusionPercent.toString(),
    moisturePercent = moisturePercent.toString(),
    cpPercent = cpPercent.toString(),
    tdnPercent = tdnPercent.toString(),
    ndfPercent = ndfPercent.toString(),
    adfPercent = adfPercent.toString(),
    caPercent = caPercent.toString(),
    pPercent = pPercent.toString()
)

private fun FormulaDraft.toRequest(): SaveFormulaRequest = SaveFormulaRequest(
    farmId = farmId,
    formulaName = formulaName,
    stage = stage,
    averageWeightKg = averageWeightKg.toDoubleOrNull() ?: 0.0,
    animalCount = animalCount.toIntOrNull() ?: 1,
    targetAdg = targetAdg.toDoubleOrNull() ?: 0.0,
    notes = notes.ifBlank { null },
    items = items.map { it.toDto() }
)

private fun FormulaItemDraft.toDto(): FormulaItemDto = FormulaItemDto(
    ingredientId = ingredientId,
    ingredientName = ingredientName,
    inclusionPercent = inclusionPercent.toDoubleOrNull() ?: 0.0,
    moisturePercent = moisturePercent.toDoubleOrNull() ?: 0.0,
    cpPercent = cpPercent.toDoubleOrNull() ?: 0.0,
    tdnPercent = tdnPercent.toDoubleOrNull() ?: 0.0,
    ndfPercent = ndfPercent.toDoubleOrNull() ?: 0.0,
    adfPercent = adfPercent.toDoubleOrNull() ?: 0.0,
    caPercent = caPercent.toDoubleOrNull() ?: 0.0,
    pPercent = pPercent.toDoubleOrNull() ?: 0.0
)

private val communitySeedPosts = listOf(
    CommunityPost(
        category = "배합 노하우",
        title = "고급육 출현율 높이는 조사료 관리법",
        body = "사일리지 수분 편차가 큰 날에는 급여량보다 건물 기준을 먼저 맞추는 편이 안정적이었습니다. 실제 현장 적용 사례를 공유합니다.",
        author = "영천하우",
        timeLabel = "25분 전",
        accent = 0xFF48714F,
        badge = "HOT",
        stats = "24   8   5"
    ),
    CommunityPost(
        category = "자유",
        title = "송아지 초기 적응 TMR 급여 경험",
        body = "초기 구간에서 조사료를 너무 급하게 올리면 섭취량이 흔들릴 때가 있었습니다. 비슷한 경험 있으신가요?",
        author = "경북한우",
        timeLabel = "2시간 전",
        accent = 0xFF5E81D6,
        badge = null,
        stats = "12   14   3"
    ),
    CommunityPost(
        category = "질병·건강",
        title = "대두박 vs 면실박 선택 기준 공유",
        body = "가격, 기호성, 분변 상태까지 같이 보면서 번갈아 쓰는 기준 정리했습니다.",
        author = "한우마스터",
        timeLabel = "어제",
        accent = 0xFFEC8735,
        badge = null,
        stats = "18   6   9"
    )
)