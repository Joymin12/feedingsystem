package com.feedingsystem.tmr.data

/**
 * 화면은 Repository만 바라보고, Retrofit 세부사항은 이 레이어에 가둔다.
 * 나중에 mock store를 실제 DB API로 바꾸더라도 ViewModel 계약을 크게 흔들지 않기 위한 분리다.
 */
class TmrRepository(
    private val api: TmrApi = TmrApiClient.api
) {
    suspend fun loadFarmProfile(): FarmProfileDto = api.getFarmProfile()

    suspend fun updateFarmProfile(request: FarmProfileUpdateRequest): FarmProfileDto =
        api.updateFarmProfile(request)

    suspend fun loadFormulas(): List<FormulaDto> = api.listFormulas()

    suspend fun updateFormula(formulaId: String, request: SaveFormulaRequest): FormulaDto =
        api.updateFormula(formulaId, request)

    suspend fun loadStageComparison(formulaId: String): StageComparisonResponseDto =
        api.getStageComparison(formulaId)

    suspend fun runAnalysis(formulaId: String): AnalysisWorkflowResponseDto =
        api.createAnalysisRun(CreateAnalysisRunRequest(formulaId = formulaId))

    suspend fun loadAnalysisRun(runId: String): AnalysisWorkflowResponseDto =
        api.getAnalysisRun(runId)
}