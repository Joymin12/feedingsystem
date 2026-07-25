import SwiftUI

// MARK: - 계산 엔진 브릿지
// PrototypeStore는 IngredientProviding을 만족하며, 실제 계산은 순수 CalculationEngine에 위임한다.
// 기존 호출부(analysis, CorrectionEngine, RegressionSuite)의 시그니처를 그대로 유지하기 위한 얇은 위임 계층.

extension PrototypeStore: IngredientProviding {}

extension PrototypeStore {
    var calculationEngine: CalculationEngine { CalculationEngine(provider: self) }

    func calculateMetrics(for formula: FeedFormula) -> (metrics: AnalysisSummaryMetrics, missingIngredients: [String]) {
        calculationEngine.calculateMetrics(for: formula)
    }

    func simulateApplying(actions: [CorrectionAction], to formula: FeedFormula) -> (formula: FeedFormula, metrics: AnalysisSummaryMetrics)? {
        calculationEngine.simulateApplying(actions: actions, to: formula)
    }

    func buildSummary(stage: FarmStage, metrics: AnalysisSummaryMetrics, missingIngredients: [String], totalIngredients: Int) -> String {
        calculationEngine.buildSummary(stage: stage, metrics: metrics, missingIngredients: missingIngredients, totalIngredients: totalIngredients)
    }

    func buildStatuses(stage: FarmStage, criteria: StageCriteria, metrics: AnalysisSummaryMetrics) -> [NutrientStatus] {
        calculationEngine.buildStatuses(stage: stage, criteria: criteria, metrics: metrics)
    }
}
