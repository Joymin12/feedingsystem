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

    /// 주의: 배합 수만큼 교정 엔진을 돌리므로 비싸다.
    /// 목록 화면에서는 쓰지 말고, 정말 전체 결과가 필요할 때만 쓴다.
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

    /// 배합 내용이 같으면 이전 결과를 그대로 돌려준다.
    /// 원료 구성, 투입량, 단위, 단가, 성장단계 중 하나라도 바뀌면 키가 달라져 다시 계산한다.
    private func analysisCacheKey(for formula: FeedFormula) -> String {
        let items = formula.items
            .map { "\($0.definitionID ?? $0.name):\($0.amount):\($0.unit.rawValue)" }
            .joined(separator: "|")
        return "\(formula.id)|\(formula.stage.rawValue)|\(items)"
    }

    func analysis(for formula: FeedFormula) -> AnalysisRun {
        let cacheKey = analysisCacheKey(for: formula)
        if let cached = analysisCache[cacheKey] { return cached }

        let stage = formula.stage
        let criteria = stage.criteria
        let calculation = calculateMetrics(for: formula)
        let metrics = calculation.metrics
        let statuses = buildStatuses(stage: stage, criteria: criteria, metrics: metrics)
        let recommendations = buildRecommendations(formula: formula, stage: stage, metrics: metrics)
        let summary = buildSummary(stage: stage, metrics: metrics, missingIngredients: calculation.missingIngredients, totalIngredients: formula.items.count)

        let run = AnalysisRun(
            formulaId: formula.id,
            formulaName: formula.name,
            stage: stage,
            checkedAt: formula.checkedAt,
            summary: summary,
            metrics: metrics,
            statuses: statuses,
            recommendations: recommendations
        )
        // 캐시가 무한정 커지지 않도록 적당한 선에서 비운다.
        if analysisCache.count > 24 { analysisCache.removeAll(keepingCapacity: true) }
        analysisCache[cacheKey] = run
        return run
    }

    /// 판정만 필요할 때 쓰는 가벼운 경로.
    /// 교정 엔진을 돌리지 않으므로 목록이나 요약 화면에서 안전하게 쓸 수 있다.
    func statusesOnly(for formula: FeedFormula) -> (metrics: AnalysisSummaryMetrics, statuses: [NutrientStatus]) {
        let metrics = calculateMetrics(for: formula).metrics
        let statuses = buildStatuses(stage: formula.stage, criteria: formula.stage.criteria, metrics: metrics)
        return (metrics, statuses)
    }

    // MARK: - 분석 이력 (저장/복제/삭제)

    // 현재 분석을 스냅샷으로 저장한다. 배합 사본과 엔진 버전을 함께 기록해
    // 이후 엔진이 갱신되어도 저장 당시 값 그대로 재현된다.
    @discardableResult
    func saveAnalysisSnapshot(for formula: FeedFormula) -> SavedAnalysis {
        let run = analysis(for: formula)
        let record = SavedAnalysis(
            savedAt: .now,
            algorithmVersion: CorrectionAlgorithm.version,
            formula: formula,
            summary: run.summary,
            metrics: run.metrics,
            statuses: run.statuses,
            recommendations: run.recommendations
        )
        savedAnalyses.insert(record, at: 0)
        return record
    }

    func deleteSavedAnalysis(id: UUID) {
        savedAnalyses.removeAll { $0.id == id }
    }

    @discardableResult
    func duplicateSavedAnalysis(id: UUID) -> SavedAnalysis? {
        guard let original = savedAnalyses.first(where: { $0.id == id }) else { return nil }
        var copy = original
        copy.id = UUID()
        copy.savedAt = .now
        savedAnalyses.insert(copy, at: 0)
        return copy
    }

    // 저장된 배합을 현재 배합 목록으로 복제한다(새 이름·새 ID).
    @discardableResult
    func restoreFormula(from record: SavedAnalysis) -> FeedFormula {
        var restored = record.formula
        restored = FeedFormula(
            name: restored.name + " (복원)",
            stage: restored.stage,
            items: restored.items,
            checkedAt: .now
        )
        formulas.insert(restored, at: 0)
        selectedFormulaID = restored.id
        return restored
    }
}
