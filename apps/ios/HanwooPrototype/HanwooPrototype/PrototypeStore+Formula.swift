import SwiftUI

// MARK: - PrototypeStore 배합 책임
// 배합 CRUD, 원가 계산, 분석 실행(계산·판정·추천 엔진 호출 브릿지).

extension PrototypeStore {
    var recentAnalyses: [AnalysisRun] {
        formulas
            .map { analysis(for: $0) }
            .sorted(by: { $0.checkedAt > $1.checkedAt })
    }

    var userFacingFormulas: [FeedFormula] {
        let visible = currentUser?.isAdmin == true ? formulas : formulas.filter { !$0.isTestFormula }
        return visible.sorted(by: { $0.checkedAt > $1.checkedAt })
    }

    var userFacingAnalyses: [AnalysisRun] {
        userFacingFormulas
            .map { analysis(for: $0) }
            .sorted(by: { $0.checkedAt > $1.checkedAt })
    }

    var regressionFormulas: [FeedFormula] {
        formulas
            .filter(\.isTestFormula)
            .sorted(by: { $0.checkedAt > $1.checkedAt })
    }

    func updateFormula(_ formula: FeedFormula) {
        guard let index = formulas.firstIndex(where: { $0.id == formula.id }) else { return }
        formulas[index] = formula
    }

    func addIngredient(to formulaID: UUID, definition: IngredientDefinition, amount: Double = 10) {
        guard let index = formulas.firstIndex(where: { $0.id == formulaID }) else { return }
        formulas[index].items.append(IngredientLine(
            name: definition.name,
            definitionID: definition.id,
            amount: amount
        ))
    }

    func effectivePricePerKg(for item: IngredientLine) -> Int? {
        if let override = item.priceOverrideKrwPerKg { return override }
        guard let defID = item.definitionID else { return nil }
        return ingredientDefinition(id: defID)?.defaultPriceKrwPerKg
    }

    func totalCostKrw(for formula: FeedFormula) -> Int? {
        var total = 0
        var hasAnyPrice = false
        for item in formula.items {
            guard let price = effectivePricePerKg(for: item) else { continue }
            let kg = asFedKg(for: item)
            total += Int(kg * Double(price))
            hasAnyPrice = true
        }
        return hasAnyPrice ? total : nil
    }

    func removeIngredient(from formulaID: UUID, ingredientID: UUID) {
        guard let index = formulas.firstIndex(where: { $0.id == formulaID }) else { return }
        formulas[index].items.removeAll(where: { $0.id == ingredientID })
    }

    func formula(for id: UUID) -> FeedFormula? {
        formulas.first(where: { $0.id == id })
    }

    func preferredSelectedFormulaID() -> UUID {
        if let selected = formula(for: selectedFormulaID),
           currentUser?.isAdmin == true || !selected.isTestFormula {
            return selected.id
        }

        if let firstVisible = userFacingFormulas.first {
            return firstVisible.id
        }

        return selectedFormulaID
    }

    func analysis(for formula: FeedFormula) -> AnalysisRun {
        let stage = formula.stage
        let criteria = stage.criteria
        let calculation = calculateMetrics(for: formula)
        let metrics = calculation.metrics
        let statuses = buildStatuses(stage: stage, criteria: criteria, metrics: metrics)
        let recommendations = buildRecommendations(formula: formula, stage: stage, metrics: metrics)
        let summary = buildSummary(stage: stage, metrics: metrics, missingIngredients: calculation.missingIngredients, totalIngredients: formula.items.count)

        return AnalysisRun(
            formulaId: formula.id,
            formulaName: formula.name,
            stage: stage,
            checkedAt: formula.checkedAt,
            summary: summary,
            metrics: metrics,
            statuses: statuses,
            recommendations: recommendations
        )
    }
}
