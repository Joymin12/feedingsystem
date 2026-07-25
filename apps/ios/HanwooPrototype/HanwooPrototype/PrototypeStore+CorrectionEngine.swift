import SwiftUI

// MARK: - 교정/추천 엔진 브릿지
// 추천 생성은 순수 CorrectionEngine에 위임한다. 엔진은 원료 조회(provider)와
// 원료 카탈로그, 그리고 CalculationEngine만 의존하므로 스토어 상태와 분리되어 있다.

extension PrototypeStore {
    var correctionEngine: CorrectionEngine {
        CorrectionEngine(provider: self, ingredientDefinitions: ingredientDefinitions)
    }

    func buildRecommendations(
        formula: FeedFormula,
        stage: FarmStage,
        metrics: AnalysisSummaryMetrics,
        constraints: SimulationConstraints = .none
    ) -> [Recommendation] {
        correctionEngine.buildRecommendations(formula: formula, stage: stage, metrics: metrics, constraints: constraints)
    }
}
