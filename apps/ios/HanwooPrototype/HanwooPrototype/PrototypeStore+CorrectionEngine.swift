import SwiftUI

// MARK: - 교정 엔진 전용 타입

// 문제 패턴 분류
private enum ProblemPattern {
    case maintenance               // 모든 기준 충족
    case cpAndTdnExcess            // CP과잉 + TDN과잉
    case cpExcess                  // CP과잉 단독
    case tdnExcess                 // TDN과잉 단독
    case eeExcess                  // EE과잉 단독
    case eeExcessWithCpDeficit     // EE과잉 + CP부족
    case ndfExcess                 // NDF과잉 단독
    case ndfExcessWithTdnDeficit   // NDF과잉 + TDN부족
    case adfExcess                 // ADF과잉 단독
    case cpAndTdnDeficit           // CP+TDN 동시 부족
    case cpDeficit                 // CP부족 단독
    case tdnDeficit                // TDN부족 단독
    case fiberDeficit              // NDF/ADF 부족 (조사료 부족)
    case complex                   // 복합 문제 → 순차 교정 fallback
}

// 패턴 기반 교정 플랜 (다중 액션 묶음)
private struct PatternPlan {
    var actions: [CorrectionAction]
    var simulatedFormula: FeedFormula
    var simulatedMetrics: AnalysisSummaryMetrics
    var costDeltaKrw: Int
    var patternLabel: String    // 예: "CP+TDN 과잉"
    var strategyLabel: String   // 예: "단백질원 감량 + 에너지원 감량"
    var resolutionRate: Double
    var isFullyResolved: Bool   // 9축 전부 적정
    var isPrimaryResolved: Bool // 핵심 교정 기준 충족 (CP/TDN/EE/Ca:P/NDF최소/ADF최소/수분hard max)
    var pros: [String]
    var cons: [String]
}

private struct BeamState {
    var actions: [CorrectionAction]
    var formula: FeedFormula
    var metrics: AnalysisSummaryMetrics
    var gap: Double
    var fullyResolved: Bool
    var primaryResolved: Bool
    var viable: Bool
    var costDeltaKrw: Int
}

// 과잉 성분 종류 (감량 헬퍼용)
private enum OverageNutrientKind: String {
    case cp, tdn, ee, ndf, adf, ca, p
}

// 원료 기여도 (원료 + 해당 영양소 절대량)
private struct NutrientContributor {
    let definition: IngredientDefinition
    let nutrientKgValue: Double
}

// MARK: - 교정 엔진

extension PrototypeStore {

    // MARK: - Public Entry

    func buildRecommendations(
        formula: FeedFormula,
        stage: FarmStage,
        metrics: AnalysisSummaryMetrics
    ) -> [Recommendation] {
        guard metrics.totalDmKg > 0 else {
            return [noSolutionRecommendation(metrics: metrics)]
        }

        let criteria = stage.criteria
        let pattern = classifyPattern(metrics: metrics, criteria: criteria)

        if case .maintenance = pattern {
            return [maintenanceRecommendation(metrics: metrics)]
        }

        let plans = generatePlans(pattern: pattern, formula: formula, stage: stage, metrics: metrics)
        let viable = plans.filter { isPlanViable($0.simulatedMetrics, criteria: criteria) }

        #if DEBUG
        if formula.isTestFormula {
            let results = viable.isEmpty ? plans : viable
            print("=== [REGRESSION] \(formula.name) | pattern=\(pattern) ===")
            print("  before: CP=\(String(format:"%.1f",metrics.cpPctDm)) TDN=\(String(format:"%.1f",metrics.tdnPctDm)) EE=\(String(format:"%.1f",metrics.eePctDm)) NDF=\(String(format:"%.1f",metrics.ndfPctDm)) moisture=\(String(format:"%.1f",metrics.moisturePct))")
            for (i, plan) in results.prefix(3).enumerated() {
                let actStr = plan.actions.map { "\($0.type)==\($0.ingredientName) \(String(format:"%.1f",$0.amountKg))kg" }.joined(separator: ", ")
                print("  plan[\(i)] full=\(plan.isFullyResolved) primary=\(plan.isPrimaryResolved) gap=\(String(format:"%.2f",totalCoreGap(metrics:plan.simulatedMetrics,criteria:criteria))) | \(actStr)")
                print("         after: CP=\(String(format:"%.1f",plan.simulatedMetrics.cpPctDm)) TDN=\(String(format:"%.1f",plan.simulatedMetrics.tdnPctDm)) EE=\(String(format:"%.1f",plan.simulatedMetrics.eePctDm)) NDF=\(String(format:"%.1f",plan.simulatedMetrics.ndfPctDm)) moisture=\(String(format:"%.1f",plan.simulatedMetrics.moisturePct))")
            }
            if results.isEmpty { print("  → 플랜 없음 (noSolution)") }
        }
        #endif

        if !viable.isEmpty {
            return selectTopRecommendations(from: viable, originalMetrics: metrics, stage: stage)
        }

        if case .complex = pattern {
            return plans.isEmpty
                ? [noSolutionRecommendation(metrics: metrics)]
                : selectTopRecommendations(from: plans, originalMetrics: metrics, stage: stage)
        }

        let fallbackPlans = generateSequentialFallbackPlan(formula: formula, stage: stage, metrics: metrics)
        let fallbackViable = fallbackPlans.filter { isPlanViable($0.simulatedMetrics, criteria: criteria) }
        if !fallbackViable.isEmpty {
            return selectTopRecommendations(from: fallbackViable, originalMetrics: metrics, stage: stage)
        }

        let bestEffortPlans = fallbackPlans.isEmpty ? plans : (plans + fallbackPlans)
        guard !bestEffortPlans.isEmpty else {
            return [noSolutionRecommendation(metrics: metrics)]
        }
        return selectTopRecommendations(from: bestEffortPlans, originalMetrics: metrics, stage: stage)
    }

    // MARK: - 패턴 분류

    private func classifyPattern(
        metrics: AnalysisSummaryMetrics,
        criteria: StageCriteria
    ) -> ProblemPattern {
        let sig = 0.2  // 유의미한 이탈 기준 (미묘한 이탈은 maintenance로)

        let cpOver  = max(0, metrics.cpPctDm  - criteria.cpMaximumPctDm)
        let tdnOver = max(0, metrics.tdnPctDm - criteria.tdnMaximumPctDm)
        let eeOver  = max(0, metrics.eePctDm  - criteria.eeMaxPctDm)
        let ndfOver = max(0, metrics.ndfPctDm - criteria.ndfMaxPctDm)
        let adfOver = max(0, metrics.adfPctDm - criteria.adfMaxPctDm)
        let cpShort  = max(0, criteria.cpMinimumPctDm  - metrics.cpPctDm)
        let tdnShort = max(0, criteria.tdnMinimumPctDm - metrics.tdnPctDm)
        let ndfShort = max(0, criteria.ndfMinPctDm - metrics.ndfPctDm)
        let adfShort = max(0, criteria.adfMinPctDm - metrics.adfPctDm)

        // 복합 패턴 (우선 매칭)
        if cpOver > sig && tdnOver > sig { return .cpAndTdnExcess }
        if eeOver > sig && cpShort > sig { return .eeExcessWithCpDeficit }
        if ndfOver > sig && tdnShort > sig { return .ndfExcessWithTdnDeficit }
        if cpShort > sig && tdnShort > sig { return .cpAndTdnDeficit }

        // 단일 과잉
        if cpOver  > sig { return .cpExcess }
        if tdnOver > sig { return .tdnExcess }
        if eeOver  > sig { return .eeExcess }
        if ndfOver > sig { return .ndfExcess }
        if adfOver > sig { return .adfExcess }

        // 단일 부족
        if cpShort  > sig { return .cpDeficit }
        if tdnShort > sig { return .tdnDeficit }
        if ndfShort > sig || adfShort > sig { return .fiberDeficit }

        // 미묘한 복합 이탈 → complex
        let issueCount = [cpOver, tdnOver, eeOver, ndfOver, adfOver,
                          cpShort, tdnShort, ndfShort, adfShort].filter { $0 > 0.05 }.count
        return issueCount >= 3 ? .complex : .maintenance
    }

    // MARK: - 패턴별 플랜 생성 분기

    private func generatePlans(
        pattern: ProblemPattern,
        formula: FeedFormula,
        stage: FarmStage,
        metrics: AnalysisSummaryMetrics
    ) -> [PatternPlan] {
        switch pattern {
        case .maintenance:
            return []
        case .cpAndTdnExcess:
            return generateCpTdnExcessPlans(formula: formula, stage: stage, metrics: metrics)
        case .cpExcess:
            return generateSingleExcessPlans(formula: formula, stage: stage, metrics: metrics, kind: .cp)
        case .tdnExcess:
            return generateSingleExcessPlans(formula: formula, stage: stage, metrics: metrics, kind: .tdn)
        case .eeExcess:
            return generateEeRelatedPlans(formula: formula, stage: stage, metrics: metrics, withCpDeficit: false)
        case .eeExcessWithCpDeficit:
            return generateEeRelatedPlans(formula: formula, stage: stage, metrics: metrics, withCpDeficit: true)
        case .ndfExcess:
            return generateSingleExcessPlans(formula: formula, stage: stage, metrics: metrics, kind: .ndf)
        case .ndfExcessWithTdnDeficit:
            return generateNdfExcessTdnDeficitPlans(formula: formula, stage: stage, metrics: metrics)
        case .adfExcess:
            return generateSingleExcessPlans(formula: formula, stage: stage, metrics: metrics, kind: .adf)
        case .cpAndTdnDeficit:
            return generateCpTdnDeficitPlans(formula: formula, stage: stage, metrics: metrics)
        case .cpDeficit:
            return generateSingleDeficitPlans(formula: formula, stage: stage, metrics: metrics, isCP: true)
        case .tdnDeficit:
            return generateSingleDeficitPlans(formula: formula, stage: stage, metrics: metrics, isCP: false)
        case .fiberDeficit:
            return generateFiberDeficitPlans(formula: formula, stage: stage, metrics: metrics)
        case .complex:
            return generateSequentialFallbackPlan(formula: formula, stage: stage, metrics: metrics)
        }
    }

    // MARK: - 패턴별 플랜 생성기

    // CP+TDN 동시 과잉: 단백질원 감량 + 에너지원 감량 조합
    private func generateCpTdnExcessPlans(
        formula: FeedFormula,
        stage: FarmStage,
        metrics: AnalysisSummaryMetrics
    ) -> [PatternPlan] {
        let criteria = stage.criteria
        let cpContribs  = topNutrientContributors(formula: formula, nutritionPath: \.cpPctDm)
        let tdnContribs = topNutrientContributors(formula: formula, nutritionPath: \.tdnPctDm)
        let cpTargetPct  = max(criteria.cpMinimumPctDm,  criteria.cpMaximumPctDm  - 0.5)
        let tdnTargetPct = max(criteria.tdnMinimumPctDm, criteria.tdnMaximumPctDm - 0.5)

        var plans: [PatternPlan] = []

        // Plan A·B: CP i순위 × TDN j순위 조합 (최대 2×2=4가지)
        for cpTarget in cpContribs.prefix(2) {
            let cpRed = bestReductionKg(formula: formula, stage: stage, metrics: metrics,
                                        definition: cpTarget.definition, kind: .cp, targetPctDm: cpTargetPct)
            for tdnTarget in tdnContribs.prefix(2) {
                var actions: [CorrectionAction] = []
                if let r = cpRed {
                    actions.append(makeDecreaseAction(definition: cpTarget.definition, amountKg: r))
                }
                // CP와 TDN 기여 원료가 다를 때만 TDN 감량 액션 추가
                if tdnTarget.definition.id != cpTarget.definition.id {
                    if let r = bestReductionKg(formula: formula, stage: stage, metrics: metrics,
                                               definition: tdnTarget.definition, kind: .tdn, targetPctDm: tdnTargetPct) {
                        actions.append(makeDecreaseAction(definition: tdnTarget.definition, amountKg: r))
                    }
                }
                guard !actions.isEmpty else { continue }
                let label = actions.count == 1
                    ? "\(actions[0].ingredientName) 감량"
                    : "\(cpTarget.definition.name) 감량 + \(tdnTarget.definition.name) 감량"
                if let plan = buildPlan(formula: formula, stage: stage, actions: actions,
                                        originalMetrics: metrics,
                                        patternLabel: "CP+TDN 과잉",
                                        strategyLabel: label) {
                    plans.append(plan)
                }
            }
        }

        // Plan C: 감량 후 NDF 부족이 생기면 조사료 소량 보완
        if let firstPlan = plans.first, !firstPlan.isFullyResolved {
            let post = firstPlan.simulatedMetrics
            let ndfShort = max(0, criteria.ndfMinPctDm - post.ndfPctDm)
            if ndfShort > 1.5 {
                let roughages = bestRoughageCandidates(formula: formula, stage: stage)
                if let roughage = roughages.first {
                    let ndfShortKg = post.totalDmKg * ndfShort / 100
                    let addKg = computeBoostKg(definition: roughage, deficitKg: ndfShortKg, nutritionPath: \.ndfPctDm)
                    let addAct = makeAddOrIncreaseAction(definition: roughage, formula: formula, amountKg: addKg)
                    let combined = firstPlan.actions + [addAct]
                    if let plan = buildPlan(formula: formula, stage: stage, actions: combined,
                                            originalMetrics: metrics,
                                            patternLabel: "CP+TDN 과잉",
                                            strategyLabel: "감량 후 \(roughage.name) 조사료 보완") {
                        plans.append(plan)
                    }
                }
            }
        }

        return plans
    }

    // EE과잉 (단독 또는 CP부족 동반)
    private func generateEeRelatedPlans(
        formula: FeedFormula,
        stage: FarmStage,
        metrics: AnalysisSummaryMetrics,
        withCpDeficit: Bool
    ) -> [PatternPlan] {
        let criteria = stage.criteria
        let eeContribs = topNutrientContributors(formula: formula, nutritionPath: \.eePctDm)
        let eeTargetPct = criteria.eeMaxPctDm
        var plans: [PatternPlan] = []

        for eeTarget in eeContribs.prefix(3) {
            guard let eeRed = bestReductionKg(formula: formula, stage: stage, metrics: metrics,
                                              definition: eeTarget.definition, kind: .ee, targetPctDm: eeTargetPct) else { continue }
            let eeAct = makeDecreaseAction(definition: eeTarget.definition, amountKg: eeRed)

            if withCpDeficit {
                // EE과잉 + CP부족: 고지방 원료 감량 후 저지방 고단백 원료 보완
                let cpCandidates = bestBoostCandidates(formula: formula, stage: stage,
                                                       filter: {
                                                           $0.nutrition.cpPctDm > 18 &&
                                                           $0.nutrition.eePctDm < criteria.eeMaxPctDm
                                                       })
                guard let reduced = simulateApplying(actions: [eeAct], to: formula) else { continue }
                let cpShortKg = reduced.metrics.totalDmKg * cpDeficit(metrics: reduced.metrics, criteria: criteria) / 100

                for cpBoost in cpCandidates.prefix(3) {
                    let boostKg = computeBoostKg(definition: cpBoost, deficitKg: max(cpShortKg, reduced.metrics.totalDmKg * 0.005),
                                                  nutritionPath: \.cpPctDm)
                    let cpAct = makeAddOrIncreaseAction(definition: cpBoost, formula: formula, amountKg: boostKg)
                    if let plan = buildPlan(formula: formula, stage: stage, actions: [eeAct, cpAct],
                                            originalMetrics: metrics,
                                            patternLabel: "EE과잉+CP부족",
                                            strategyLabel: "\(eeTarget.definition.name) 감량 + \(cpBoost.name) 보완") {
                        plans.append(plan)
                    }
                }
            } else {
                // EE과잉 단독
                if let plan = buildPlan(formula: formula, stage: stage, actions: [eeAct],
                                        originalMetrics: metrics,
                                        patternLabel: "EE 과잉",
                                        strategyLabel: "\(eeTarget.definition.name) 감량") {
                    plans.append(plan)
                }
                // EE 감량 후 NDF 부족이 생기면 조사료 보완
                if let reduced = simulateApplying(actions: [eeAct], to: formula) {
                    let ndfShort = max(0, criteria.ndfMinPctDm - reduced.metrics.ndfPctDm)
                    if ndfShort > 1.0, let roughage = bestRoughageCandidates(formula: formula, stage: stage).first {
                        let roughageKg = computeBoostKg(definition: roughage,
                                                         deficitKg: reduced.metrics.totalDmKg * ndfShort / 100,
                                                         nutritionPath: \.ndfPctDm)
                        let rAct = makeAddOrIncreaseAction(definition: roughage, formula: formula, amountKg: roughageKg)
                        if let plan = buildPlan(formula: formula, stage: stage, actions: [eeAct, rAct],
                                                originalMetrics: metrics,
                                                patternLabel: "EE 과잉",
                                                strategyLabel: "\(eeTarget.definition.name) 감량 + 조사료 보완") {
                            plans.append(plan)
                        }
                    }
                }
            }
        }
        return plans
    }

    // NDF과잉 + TDN부족: 조사료 감량 + 에너지 농후사료 증량
    private func generateNdfExcessTdnDeficitPlans(
        formula: FeedFormula,
        stage: FarmStage,
        metrics: AnalysisSummaryMetrics
    ) -> [PatternPlan] {
        let criteria = stage.criteria
        let ndfContribs = topNutrientContributors(formula: formula, nutritionPath: \.ndfPctDm)
        let energyCandidates = bestBoostCandidates(formula: formula, stage: stage,
            filter: { $0.nutrition.tdnPctDm > 70 && ($0.category == .concentrate || $0.category == .agriByproduct) })
        var plans: [PatternPlan] = []

        for ndfTarget in ndfContribs.prefix(2) {
            guard let ndfRed = bestReductionKg(formula: formula, stage: stage, metrics: metrics,
                                               definition: ndfTarget.definition, kind: .ndf,
                                               targetPctDm: criteria.ndfMaxPctDm) else { continue }
            let reduceAct = makeDecreaseAction(definition: ndfTarget.definition, amountKg: ndfRed)

            // NDF 감량 단독
            if let plan = buildPlan(formula: formula, stage: stage, actions: [reduceAct],
                                    originalMetrics: metrics,
                                    patternLabel: "NDF과잉+TDN부족",
                                    strategyLabel: "\(ndfTarget.definition.name) 감량") {
                plans.append(plan)
            }

            // NDF 감량 + 에너지 보완
            guard let reduced = simulateApplying(actions: [reduceAct], to: formula) else { continue }
            let tdnShortKg = reduced.metrics.totalDmKg * tdnDeficit(metrics: reduced.metrics, criteria: criteria) / 100

            for energyBoost in energyCandidates.prefix(2) {
                let boostKg = computeBoostKg(definition: energyBoost,
                                              deficitKg: max(tdnShortKg, reduced.metrics.totalDmKg * 0.005),
                                              nutritionPath: \.tdnPctDm)
                let boostAct = makeAddOrIncreaseAction(definition: energyBoost, formula: formula, amountKg: boostKg)
                if let plan = buildPlan(formula: formula, stage: stage, actions: [reduceAct, boostAct],
                                        originalMetrics: metrics,
                                        patternLabel: "NDF과잉+TDN부족",
                                        strategyLabel: "\(ndfTarget.definition.name) 감량 + \(energyBoost.name) 보완") {
                    plans.append(plan)
                }
            }
        }
        return plans
    }

    // CP+TDN 동시 부족: 단백질원 + 에너지원 동시 보완
    private func generateCpTdnDeficitPlans(
        formula: FeedFormula,
        stage: FarmStage,
        metrics: AnalysisSummaryMetrics
    ) -> [PatternPlan] {
        let criteria = stage.criteria
        let cpCandidates  = bestBoostCandidates(formula: formula, stage: stage,
                                                 filter: { $0.nutrition.cpPctDm > 15 })
        let tdnCandidates = bestBoostCandidates(formula: formula, stage: stage,
                                                 filter: { $0.nutrition.tdnPctDm > 68 && $0.category != .roughage })
        let cpShortKg  = metrics.totalDmKg * cpDeficit(metrics: metrics, criteria: criteria) / 100
        let tdnShortKg = metrics.totalDmKg * tdnDeficit(metrics: metrics, criteria: criteria) / 100
        var plans: [PatternPlan] = []

        // Plan A: 단백질원 + 에너지원 동시 보완 (2×2 조합)
        for cpBoost in cpCandidates.prefix(2) {
            let cpKg = computeBoostKg(definition: cpBoost, deficitKg: cpShortKg, nutritionPath: \.cpPctDm)
            let cpAct = makeAddOrIncreaseAction(definition: cpBoost, formula: formula, amountKg: cpKg)

            for tdnBoost in tdnCandidates.prefix(2) {
                if tdnBoost.id == cpBoost.id { continue }
                let tdnKg  = computeBoostKg(definition: tdnBoost, deficitKg: tdnShortKg, nutritionPath: \.tdnPctDm)
                let tdnAct = makeAddOrIncreaseAction(definition: tdnBoost, formula: formula, amountKg: tdnKg)
                if let plan = buildPlan(formula: formula, stage: stage, actions: [cpAct, tdnAct],
                                        originalMetrics: metrics,
                                        patternLabel: "CP+TDN 부족",
                                        strategyLabel: "\(cpBoost.name) + \(tdnBoost.name) 동시 보완") {
                    plans.append(plan)
                }
            }

            // 단독 보완도 후보로
            if let plan = buildPlan(formula: formula, stage: stage, actions: [cpAct],
                                    originalMetrics: metrics,
                                    patternLabel: "CP+TDN 부족",
                                    strategyLabel: "\(cpBoost.name) 단독 보완") {
                plans.append(plan)
            }
        }

        // Plan B: 에너지원 단독 (TDN+CP 동반 개선 가능 원료)
        for tdnBoost in tdnCandidates.prefix(2) {
            let tdnKg = computeBoostKg(definition: tdnBoost, deficitKg: tdnShortKg, nutritionPath: \.tdnPctDm)
            let tdnAct = makeAddOrIncreaseAction(definition: tdnBoost, formula: formula, amountKg: tdnKg)
            if let plan = buildPlan(formula: formula, stage: stage, actions: [tdnAct],
                                    originalMetrics: metrics,
                                    patternLabel: "CP+TDN 부족",
                                    strategyLabel: "\(tdnBoost.name) 단독 보완") {
                plans.append(plan)
            }
        }
        return plans
    }

    // 단일 과잉 (CP/TDN/EE/NDF/ADF): 상위 기여 원료 감량 후보 생성
    private func generateSingleExcessPlans(
        formula: FeedFormula,
        stage: FarmStage,
        metrics: AnalysisSummaryMetrics,
        kind: OverageNutrientKind
    ) -> [PatternPlan] {
        let criteria  = stage.criteria
        let targetPct = overageTargetPct(kind: kind, criteria: criteria)
        let contribs  = topNutrientContributors(formula: formula, nutritionPath: nutritionKeyPath(for: kind))
        let patternLabel = "\(nutrientDisplayName(kind)) 과잉"
        var plans: [PatternPlan] = []

        for target in contribs.prefix(3) {
            guard let rKg = bestReductionKg(formula: formula, stage: stage, metrics: metrics,
                                             definition: target.definition, kind: kind, targetPctDm: targetPct) else { continue }
            let act = makeDecreaseAction(definition: target.definition, amountKg: rKg)
            let reduced = simulateApplying(actions: [act], to: formula)

            if let plan = buildPlan(formula: formula, stage: stage, actions: [act],
                                    originalMetrics: metrics,
                                    patternLabel: patternLabel,
                                    strategyLabel: "\(target.definition.name) 감량") {
                plans.append(plan)
            }

            guard let reduced else { continue }
            let cpShort = cpDeficit(metrics: reduced.metrics, criteria: criteria)
            let tdnShort = tdnDeficit(metrics: reduced.metrics, criteria: criteria)
            let ndfShort = max(0, criteria.ndfMinPctDm - reduced.metrics.ndfPctDm)

            if cpShort > 0.1 || tdnShort > 0.1 {
                let isCP = cpShort >= tdnShort
                let filter: (IngredientDefinition) -> Bool = isCP
                    ? { $0.nutrition.cpPctDm > 15 }
                    : { $0.nutrition.tdnPctDm > 68 && $0.category != .roughage }
                if let boostDef = bestBoostCandidates(formula: formula, stage: stage, filter: filter).first {
                    let shortKg = reduced.metrics.totalDmKg * max(cpShort, tdnShort) / 100
                    let boostKg = computeBoostKg(
                        definition: boostDef,
                        deficitKg: max(shortKg, reduced.metrics.totalDmKg * 0.004),
                        nutritionPath: isCP ? \.cpPctDm : \.tdnPctDm
                    )
                    let boostAct = makeAddOrIncreaseAction(definition: boostDef, formula: formula, amountKg: boostKg)
                    if let plan = buildPlan(
                        formula: formula,
                        stage: stage,
                        actions: [act, boostAct],
                        originalMetrics: metrics,
                        patternLabel: patternLabel,
                        strategyLabel: "\(target.definition.name) 감량 + \(boostDef.name) 보완"
                    ) {
                        plans.append(plan)
                    }
                }
            }

            if ndfShort > 0.8,
               let roughage = bestRoughageCandidates(formula: formula, stage: stage).first {
                let roughageKg = computeBoostKg(
                    definition: roughage,
                    deficitKg: reduced.metrics.totalDmKg * ndfShort / 100,
                    nutritionPath: \.ndfPctDm
                )
                let roughageAct = makeAddOrIncreaseAction(definition: roughage, formula: formula, amountKg: roughageKg)
                if let plan = buildPlan(
                    formula: formula,
                    stage: stage,
                    actions: [act, roughageAct],
                    originalMetrics: metrics,
                    patternLabel: patternLabel,
                    strategyLabel: "\(target.definition.name) 감량 + \(roughage.name) 보완"
                ) {
                    plans.append(plan)
                }
            }
        }

        // 감량 후 CP 또는 TDN이 부족해지면 보완 후보 추가
        if let firstPlan = plans.first {
            let post = firstPlan.simulatedMetrics
            let cpShort  = cpDeficit(metrics: post, criteria: criteria)
            let tdnShort = tdnDeficit(metrics: post, criteria: criteria)
            let primaryShort = max(cpShort, tdnShort)
            if primaryShort > 0.5 {
                let isCP = cpShort >= tdnShort
                let filter: (IngredientDefinition) -> Bool = isCP
                    ? { $0.nutrition.cpPctDm > 15 }
                    : { $0.nutrition.tdnPctDm > 68 && $0.category != .roughage }
                if let boostDef = bestBoostCandidates(formula: formula, stage: stage, filter: filter).first {
                    let shortKg = post.totalDmKg * primaryShort / 100
                    let boostKg = computeBoostKg(definition: boostDef, deficitKg: shortKg,
                                                  nutritionPath: isCP ? \.cpPctDm : \.tdnPctDm)
                    let boostAct = makeAddOrIncreaseAction(definition: boostDef, formula: formula, amountKg: boostKg)
                    if let plan = buildPlan(formula: formula, stage: stage,
                                            actions: firstPlan.actions + [boostAct],
                                            originalMetrics: metrics,
                                            patternLabel: patternLabel,
                                            strategyLabel: "\(firstPlan.strategyLabel) + \(boostDef.name) 보완") {
                        plans.append(plan)
                    }
                }
            }
        }
        return plans
    }

    // 단일 부족 (CP 또는 TDN): 보완 원료 후보 생성
    private func generateSingleDeficitPlans(
        formula: FeedFormula,
        stage: FarmStage,
        metrics: AnalysisSummaryMetrics,
        isCP: Bool
    ) -> [PatternPlan] {
        let criteria = stage.criteria
        let deficitPct = isCP
            ? cpDeficit(metrics: metrics, criteria: criteria)
            : tdnDeficit(metrics: metrics, criteria: criteria)
        let deficitKg = metrics.totalDmKg * deficitPct / 100
        let nutritionPath: KeyPath<IngredientNutritionProfile, Double> = isCP ? \.cpPctDm : \.tdnPctDm
        let filter: (IngredientDefinition) -> Bool = isCP
            ? { $0.nutrition.cpPctDm > 15 }
            : { $0.nutrition.tdnPctDm > 68 && $0.category != .roughage }
        let candidates = bestBoostCandidates(formula: formula, stage: stage, filter: filter)
        let patternLabel = isCP ? "CP 부족" : "TDN 부족"
        return candidates.prefix(4).compactMap { candidate in
            let boostKg = computeBoostKg(definition: candidate, deficitKg: deficitKg, nutritionPath: nutritionPath)
            let act = makeAddOrIncreaseAction(definition: candidate, formula: formula, amountKg: boostKg)
            return buildPlan(formula: formula, stage: stage, actions: [act],
                             originalMetrics: metrics,
                             patternLabel: patternLabel,
                             strategyLabel: "\(candidate.name) 보완")
        }
    }

    // NDF/ADF 부족: 조사료 보완
    private func generateFiberDeficitPlans(
        formula: FeedFormula,
        stage: FarmStage,
        metrics: AnalysisSummaryMetrics
    ) -> [PatternPlan] {
        let criteria = stage.criteria
        let ndfShort = max(0, criteria.ndfMinPctDm - metrics.ndfPctDm)
        let adfShort = max(0, criteria.adfMinPctDm - metrics.adfPctDm)
        let targetShort = max(ndfShort, adfShort)
        let deficitKg = metrics.totalDmKg * targetShort / 100
        let roughages = bestRoughageCandidates(formula: formula, stage: stage)
        return roughages.prefix(3).compactMap { roughage in
            let boostKg = computeBoostKg(definition: roughage, deficitKg: deficitKg, nutritionPath: \.ndfPctDm)
            let act = makeAddOrIncreaseAction(definition: roughage, formula: formula, amountKg: boostKg)
            return buildPlan(formula: formula, stage: stage, actions: [act],
                             originalMetrics: metrics,
                             patternLabel: "섬유(NDF/ADF) 부족",
                             strategyLabel: "\(roughage.name) 보완")
        }
    }

    // 복합 문제 → 순차 교정 fallback (M1.8 방식)
    private func generateSequentialFallbackPlan(
        formula: FeedFormula,
        stage: FarmStage,
        metrics: AnalysisSummaryMetrics
    ) -> [PatternPlan] {
        let criteria = stage.criteria
        var workFormula  = formula
        var workMetrics  = metrics
        var actions: [CorrectionAction] = []

        for _ in 0..<3 {
            guard let over = mostSevereOverage(formula: workFormula, stage: stage, metrics: workMetrics) else { break }
            let contribs = topNutrientContributors(formula: workFormula, nutritionPath: over.nutritionPath)
            guard let target = contribs.first,
                  let rKg = bestReductionKg(formula: workFormula, stage: stage, metrics: workMetrics,
                                             definition: target.definition, kind: over.kind,
                                             targetPctDm: over.targetPctDm),
                  let result = simulateApplying(actions: [makeDecreaseAction(definition: target.definition, amountKg: rKg)],
                                                to: workFormula) else { break }
            actions.append(makeDecreaseAction(definition: target.definition, amountKg: rKg))
            workFormula = result.formula
            workMetrics = result.metrics
        }

        // 보완
        let cpShort  = cpDeficit(metrics: workMetrics, criteria: criteria)
        let tdnShort = tdnDeficit(metrics: workMetrics, criteria: criteria)
        if max(cpShort, tdnShort) > 0.5 {
            let isCP = cpShort >= tdnShort
            let filter: (IngredientDefinition) -> Bool = isCP
                ? { $0.nutrition.cpPctDm > 15 }
                : { $0.nutrition.tdnPctDm > 68 }
            if let boostDef = bestBoostCandidates(formula: workFormula, stage: stage, filter: filter).first {
                let shortKg = workMetrics.totalDmKg * max(cpShort, tdnShort) / 100
                let boostKg = computeBoostKg(definition: boostDef, deficitKg: shortKg,
                                              nutritionPath: isCP ? \.cpPctDm : \.tdnPctDm)
                actions.append(makeAddOrIncreaseAction(definition: boostDef, formula: formula, amountKg: boostKg))
            }
        }

        guard !actions.isEmpty,
              let plan = buildPlan(formula: formula, stage: stage, actions: actions,
                                   originalMetrics: metrics,
                                   patternLabel: "복합 문제",
                                   strategyLabel: "순차 감량 후 보완") else { return [] }
        return [plan]
    }

    // MARK: - 재료 선택 헬퍼

    private func topNutrientContributors(
        formula: FeedFormula,
        nutritionPath: KeyPath<IngredientNutritionProfile, Double>,
        maxCount: Int = 4
    ) -> [NutrientContributor] {
        formula.items.compactMap { item -> NutrientContributor? in
            guard let defID = item.definitionID,
                  let def = ingredientDefinition(id: defID) else { return nil }
            let asFed = asFedKg(for: item)
            let dmKg  = asFed * (def.nutrition.dmPct / 100)
            let nKg   = nutrientKg(dmKg: dmKg, pctDm: def.nutrition[keyPath: nutritionPath])
            return nKg > 0.01 ? NutrientContributor(definition: def, nutrientKgValue: nKg) : nil
        }
        .sorted { $0.nutrientKgValue > $1.nutrientKgValue }
        .prefix(maxCount)
        .map { $0 }
    }

    // 보완 후보 원료 (기존 배합 원료 우선, 그 다음 신규, 가격 낮은 순)
    private func bestBoostCandidates(
        formula: FeedFormula,
        stage: FarmStage,
        filter: (IngredientDefinition) -> Bool
    ) -> [IngredientDefinition] {
        let currentIDs = Set(formula.items.compactMap(\.definitionID))
        let existing = ingredientDefinitions
            .filter { $0.selectionGroup == .tmr && currentIDs.contains($0.id) && filter($0) }
            .sorted { $0.defaultPriceKrwPerKg < $1.defaultPriceKrwPerKg }
        let newOnes = ingredientDefinitions
            .filter { $0.selectionGroup == .tmr && !currentIDs.contains($0.id) && filter($0) }
            .sorted { $0.defaultPriceKrwPerKg < $1.defaultPriceKrwPerKg }
        return existing + newOnes
    }

    private func bestRoughageCandidates(formula: FeedFormula, stage: FarmStage = .growing) -> [IngredientDefinition] {
        bestBoostCandidates(formula: formula, stage: stage, filter: { $0.category == .roughage })
    }

    // 부족분 기준 필요 증량 계산 (as-fed kg)
    private func computeBoostKg(
        definition: IngredientDefinition,
        deficitKg: Double,
        nutritionPath: KeyPath<IngredientNutritionProfile, Double>
    ) -> Double {
        let profile = definition.nutrition
        let nutrientPerKgAsFed = (profile.dmPct / 100) * (profile[keyPath: nutritionPath] / 100)
        guard nutrientPerKgAsFed > 0.001, deficitKg > 0 else { return 0.5 }
        return max(deficitKg / nutrientPerKgAsFed, 0.3)
    }

    private func computeSpecificNutrientBoostKg(
        definition: IngredientDefinition,
        requiredKg: Double,
        nutritionPath: KeyPath<IngredientNutritionProfile, Double>,
        lower: Double
    ) -> Double {
        let profile = definition.nutrition
        let nutrientPerKgAsFed = (profile.dmPct / 100) * (profile[keyPath: nutritionPath] / 100)
        guard nutrientPerKgAsFed > 0.0001, requiredKg > 0 else { return 0 }
        return max(requiredKg / nutrientPerKgAsFed, lower)
    }

    // 감량 액션에 쓸 최적 감량량 (역산 → fallback 순, 안전 검증 포함)
    private func bestReductionKg(
        formula: FeedFormula,
        stage: FarmStage,
        metrics: AnalysisSummaryMetrics,
        definition: IngredientDefinition,
        kind: OverageNutrientKind,
        targetPctDm: Double
    ) -> Double? {
        guard let item = formula.items.first(where: { $0.definitionID == definition.id }) else { return nil }
        let currentAmountKg = asFedKg(for: item)
        guard currentAmountKg > 1.05 else { return nil }

        let maxPct = maxPctDm(for: kind, criteria: stage.criteria)
        let candidates = reductionAmountCandidates(
            formula: formula, metrics: metrics, stage: stage,
            definition: definition, currentAmountKg: currentAmountKg,
            nutritionPath: nutritionKeyPath(for: kind),
            metricsPath: metricsKeyPath(for: kind),
            maxPctDm: maxPct, targetPctDm: targetPctDm
        )
        for rKg in candidates {
            let act = makeDecreaseAction(definition: definition, amountKg: rKg)
            guard let result = simulateApplying(actions: [act], to: formula) else { continue }
            if isAcceptableReduction(before: metrics, after: result.metrics,
                                     targetNutrient: kind, criteria: stage.criteria) {
                return rKg
            }
        }
        return nil
    }

    // MARK: - 액션 생성 헬퍼

    private func makeDecreaseAction(definition: IngredientDefinition, amountKg: Double) -> CorrectionAction {
        CorrectionAction(ingredientID: definition.id, ingredientName: definition.name,
                         type: .decrease, amountKg: amountKg,
                         displayAmount: "약 \(numberString(amountKg))kg")
    }

    private func makeAddOrIncreaseAction(
        definition: IngredientDefinition,
        formula: FeedFormula,
        amountKg: Double
    ) -> CorrectionAction {
        let isAlreadyIn = formula.items.contains(where: { $0.definitionID == definition.id })
        return CorrectionAction(ingredientID: definition.id, ingredientName: definition.name,
                                type: isAlreadyIn ? .increase : .add, amountKg: amountKg,
                                displayAmount: "약 \(numberString(amountKg))kg")
    }

    // MARK: - 플랜 조립

    private func buildPlan(
        formula: FeedFormula,
        stage: FarmStage,
        actions: [CorrectionAction],
        originalMetrics: AnalysisSummaryMetrics,
        patternLabel: String,
        strategyLabel: String
    ) -> PatternPlan? {
        guard !actions.isEmpty,
              let normalized = normalizePlanActions(formula: formula, stage: stage, baseActions: actions) else { return nil }
        let finalActions = normalized.actions
        let result = normalized.result

        let costDelta = finalActions.reduce(0) { acc, act -> Int in
            guard let defID = act.ingredientID, let def = ingredientDefinition(id: defID) else { return acc }
            let price = effectivePricePerKgInFormula(for: def, within: formula)
            let delta = Int((Double(price) * act.amountKg).rounded())
            switch act.type {
            case .decrease:        return acc - delta
            case .increase, .add:  return acc + delta
            }
        }

        let resolutionRate = overallResolutionRate(before: originalMetrics, after: result.metrics,
                                                   criteria: stage.criteria)
        let isFullyResolved   = allCoreTargetsSatisfied(metrics: result.metrics, criteria: stage.criteria)
        let isPrimaryResolved = primaryTargetsSatisfied(metrics: result.metrics, criteria: stage.criteria)
        let pros = buildPatternPros(originalMetrics: originalMetrics, metrics: result.metrics,
                                    actions: finalActions, criteria: stage.criteria)
        let cons = buildPatternCons(originalMetrics: originalMetrics, metrics: result.metrics,
                                    actions: finalActions, criteria: stage.criteria, costDelta: costDelta)

        return PatternPlan(
            actions: finalActions,
            simulatedFormula: result.formula,
            simulatedMetrics: result.metrics,
            costDeltaKrw: costDelta,
            patternLabel: patternLabel,
            strategyLabel: strategyLabel,
            resolutionRate: resolutionRate,
            isFullyResolved: isFullyResolved,
            isPrimaryResolved: isPrimaryResolved,
            pros: pros,
            cons: cons
        )
    }

    private func normalizePlanActions(
        formula: FeedFormula,
        stage: FarmStage,
        baseActions: [CorrectionAction]
    ) -> (actions: [CorrectionAction], result: (formula: FeedFormula, metrics: AnalysisSummaryMetrics))? {
        beamNormalizePlanActions(formula: formula, stage: stage, baseActions: baseActions)
    }

    private func beamNormalizePlanActions(
        formula: FeedFormula,
        stage: FarmStage,
        baseActions: [CorrectionAction],
        width: Int = 8,
        maxSteps: Int = 8
    ) -> (actions: [CorrectionAction], result: (formula: FeedFormula, metrics: AnalysisSummaryMetrics))? {
        guard let initialState = makeBeamState(
            actions: baseActions,
            originalFormula: formula,
            stage: stage
        ) else { return nil }

        var beams: [BeamState] = [initialState]
        var bestResolved: BeamState? = initialState.fullyResolved ? initialState : nil

        for _ in 0..<maxSteps {
            var nextStates = beams

            for beam in beams {
                if beam.fullyResolved {
                    bestResolved = betterBeamState(bestResolved, beam)
                    continue
                }

                let candidates = candidateNextActions(
                    formula: beam.formula,
                    stage: stage,
                    metrics: beam.metrics
                )

                guard !candidates.isEmpty else { continue }

                for candidate in candidates {
                    guard let nextState = makeBeamState(
                        actions: beam.actions + [candidate],
                        originalFormula: formula,
                        stage: stage
                    ) else { continue }
                    nextStates.append(nextState)
                    if nextState.fullyResolved {
                        bestResolved = betterBeamState(bestResolved, nextState)
                    }
                }
            }

            beams = pruneBeamStates(nextStates, originalFormula: formula, width: width)
            if let resolved = beams.first(where: \.fullyResolved) {
                bestResolved = betterBeamState(bestResolved, resolved)
                break
            }
        }

        let finalState = bestResolved ?? pruneBeamStates(beams, originalFormula: formula, width: 1).first
        guard let finalState else { return nil }
        return (finalState.actions, (finalState.formula, finalState.metrics))
    }

    private func buildSupplementalCorrectionActions(
        formula: FeedFormula,
        stage: FarmStage,
        metrics: AnalysisSummaryMetrics,
        originalFormula: FeedFormula? = nil,
        currentFormula: FeedFormula? = nil
    ) -> [CorrectionAction] {
        Array(candidateNextActions(formula: formula, stage: stage, metrics: metrics).prefix(1))
    }

    private func candidateNextActions(
        formula: FeedFormula,
        stage: FarmStage,
        metrics: AnalysisSummaryMetrics
    ) -> [CorrectionAction] {
        let criteria = stage.criteria
        var actions: [CorrectionAction] = []

        if cpDeficit(metrics: metrics, criteria: criteria) > 0.1 {
            let eeIsOver = metrics.eePctDm > criteria.eeMaxPctDm
            actions += bestSupplementCandidates(
                formula: formula,
                stage: stage,
                metrics: metrics,
                deficitPct: cpDeficit(metrics: metrics, criteria: criteria),
                nutritionPath: \.cpPctDm,
                filter: {
                    $0.nutrition.cpPctDm > 15 &&
                    (!eeIsOver || $0.nutrition.eePctDm < criteria.eeMaxPctDm)
                },
                limit: 2
            )
        }

        if tdnDeficit(metrics: metrics, criteria: criteria) > 0.1 {
            actions += bestSupplementCandidates(
                formula: formula,
                stage: stage,
                metrics: metrics,
                deficitPct: tdnDeficit(metrics: metrics, criteria: criteria),
                nutritionPath: \.tdnPctDm,
                filter: { $0.nutrition.tdnPctDm > 68 && $0.category != .roughage },
                limit: 2
            )
        }

        let fiberShort = max(ndfGap(metrics: metrics, criteria: criteria), adfGap(metrics: metrics, criteria: criteria))
        if fiberShort > 0.3 {
            actions += bestSupplementCandidates(
                formula: formula,
                stage: stage,
                metrics: metrics,
                deficitPct: fiberShort,
                nutritionPath: adfGap(metrics: metrics, criteria: criteria) > ndfGap(metrics: metrics, criteria: criteria)
                    ? \.adfPctDm
                    : \.ndfPctDm,
                filter: {
                    $0.category == .roughage &&
                    ($0.nutrition.ndfPctDm > 20 || $0.nutrition.adfPctDm > 12)
                },
                limit: 2
            )
        }

        if metrics.moisturePct < criteria.moistureMinimumPct - 0.1 {
            actions += bestMoistureSupplementCandidates(
                formula: formula,
                stage: stage,
                metrics: metrics,
                limit: 2
            )
        }

        if metrics.moisturePct > criteria.moistureMaximumPct + 0.1 {
            actions += bestMoistureReductionCandidates(
                formula: formula,
                stage: stage,
                metrics: metrics,
                limit: 2
            )
        }

        if metrics.cpPctDm > criteria.cpMaximumPctDm + 0.1 {
            actions += bestReductionCandidates(
                formula: formula,
                stage: stage,
                metrics: metrics,
                kind: .cp,
                targetPctDm: max(criteria.cpMinimumPctDm, criteria.cpMaximumPctDm - 0.2),
                limit: 2
            )
        }

        if metrics.tdnPctDm > criteria.tdnMaximumPctDm + 0.1 {
            actions += bestReductionCandidates(
                formula: formula,
                stage: stage,
                metrics: metrics,
                kind: .tdn,
                targetPctDm: max(criteria.tdnMinimumPctDm, criteria.tdnMaximumPctDm - 0.2),
                limit: 2
            )
        }

        if metrics.eePctDm > criteria.eeMaxPctDm + 0.1 {
            actions += bestReductionCandidates(
                formula: formula,
                stage: stage,
                metrics: metrics,
                kind: .ee,
                targetPctDm: criteria.eeMaxPctDm,
                limit: 2
            )
        }

        if metrics.ndfPctDm > criteria.ndfMaxPctDm + 0.2 {
            actions += bestReductionCandidates(
                formula: formula,
                stage: stage,
                metrics: metrics,
                kind: .ndf,
                targetPctDm: criteria.ndfMaxPctDm,
                limit: 2
            )
        }

        if metrics.adfPctDm > criteria.adfMaxPctDm + 0.2 {
            actions += bestReductionCandidates(
                formula: formula,
                stage: stage,
                metrics: metrics,
                kind: .adf,
                targetPctDm: criteria.adfMaxPctDm,
                limit: 2
            )
        }

        if metrics.caPctDm > criteria.caMaxPctDm + 0.03 {
            actions += bestReductionCandidates(
                formula: formula,
                stage: stage,
                metrics: metrics,
                kind: .ca,
                targetPctDm: criteria.caMaxPctDm,
                limit: 2
            )
        }

        let pOver = max(0, metrics.pPctDm - criteria.pMaxPctDm)
        let ratioLow = metrics.caPRatio < criteria.caPRatioMin
        if pOver > 0.05 || ratioLow {
            actions += bestReductionCandidates(
                formula: formula,
                stage: stage,
                metrics: metrics,
                kind: .p,
                targetPctDm: max(criteria.pMinPctDm, criteria.pMaxPctDm - 0.05),
                limit: 2
            )
        }

        actions += buildMineralCorrectionActions(formula: formula, stage: stage, metrics: metrics)
        return deduplicateActionCandidates(actions)
    }

    private func bestSupplementAction(
        formula: FeedFormula,
        stage: FarmStage,
        metrics: AnalysisSummaryMetrics,
        deficitPct: Double,
        nutritionPath: KeyPath<IngredientNutritionProfile, Double>,
        filter: (IngredientDefinition) -> Bool,
        preferredLabel: String
    ) -> CorrectionAction? {
        bestSupplementCandidates(
            formula: formula,
            stage: stage,
            metrics: metrics,
            deficitPct: deficitPct,
            nutritionPath: nutritionPath,
            filter: filter,
            limit: 1
        ).first
    }

    private func bestSupplementCandidates(
        formula: FeedFormula,
        stage: FarmStage,
        metrics: AnalysisSummaryMetrics,
        deficitPct: Double,
        nutritionPath: KeyPath<IngredientNutritionProfile, Double>,
        filter: (IngredientDefinition) -> Bool,
        limit: Int
    ) -> [CorrectionAction] {
        let deficitKg = metrics.totalDmKg * deficitPct / 100
        let candidates = bestBoostCandidates(formula: formula, stage: stage, filter: filter).prefix(8)
        let criteria = stage.criteria

        let ranked = candidates.compactMap { definition -> (CorrectionAction, Double)? in
            let amountKg = computeBoostKg(
                definition: definition,
                deficitKg: max(deficitKg, metrics.totalDmKg * 0.003),
                nutritionPath: nutritionPath
            )
            guard amountKg >= 0.1 else { return nil }
            let action = makeAddOrIncreaseAction(definition: definition, formula: formula, amountKg: amountKg)
            guard let simulated = simulateApplying(actions: [action], to: formula) else { return nil }
            let score = totalCoreGap(metrics: simulated.metrics, criteria: criteria)
            return (action, score)
        }

        return ranked
            .sorted(by: { lhs, rhs in
                if abs(lhs.1 - rhs.1) > 0.001 { return lhs.1 < rhs.1 }
                return lhs.0.amountKg < rhs.0.amountKg
            })
            .prefix(limit)
            .map(\.0)
    }

    private func bestReductionCandidates(
        formula: FeedFormula,
        stage: FarmStage,
        metrics: AnalysisSummaryMetrics,
        kind: OverageNutrientKind,
        targetPctDm: Double,
        limit: Int
    ) -> [CorrectionAction] {
        let criteria = stage.criteria
        let ranked = topNutrientContributors(
            formula: formula,
            nutritionPath: nutritionKeyPath(for: kind),
            maxCount: 5
        ).compactMap { contributor -> (CorrectionAction, Double)? in
            guard let amountKg = bestReductionKg(
                formula: formula,
                stage: stage,
                metrics: metrics,
                definition: contributor.definition,
                kind: kind,
                targetPctDm: targetPctDm
            ) else { return nil }
            let action = makeDecreaseAction(definition: contributor.definition, amountKg: amountKg)
            guard let simulated = simulateApplying(actions: [action], to: formula) else { return nil }
            return (action, totalCoreGap(metrics: simulated.metrics, criteria: criteria))
        }

        return ranked
            .sorted(by: { lhs, rhs in
                if abs(lhs.1 - rhs.1) > 0.001 { return lhs.1 < rhs.1 }
                return lhs.0.amountKg < rhs.0.amountKg
            })
            .prefix(limit)
            .map(\.0)
    }

    private func bestMoistureSupplementCandidates(
        formula: FeedFormula,
        stage: FarmStage,
        metrics: AnalysisSummaryMetrics,
        limit: Int
    ) -> [CorrectionAction] {
        let targetMoisture = (stage.criteria.moistureMinimumPct + stage.criteria.moistureMaximumPct) / 2
        let targetDmFraction = (100 - targetMoisture) / 100
        let criteria = stage.criteria

        let ranked = ingredientDefinitions
            .filter { $0.selectionGroup == .tmr && ($0.nutrition.dmPct / 100) < targetDmFraction }
            .compactMap { definition -> (CorrectionAction, Double)? in
                let amountKg = moistureAdjustmentKgForAddition(
                    definition: definition,
                    metrics: metrics,
                    targetMoisturePct: targetMoisture
                )
                guard amountKg >= 0.1 else { return nil }
                let action = makeAddOrIncreaseAction(definition: definition, formula: formula, amountKg: amountKg)
                guard let simulated = simulateApplying(actions: [action], to: formula) else { return nil }
                return (action, totalCoreGap(metrics: simulated.metrics, criteria: criteria))
            }

        return ranked
            .sorted(by: { lhs, rhs in
                if abs(lhs.1 - rhs.1) > 0.001 { return lhs.1 < rhs.1 }
                return lhs.0.amountKg < rhs.0.amountKg
            })
            .prefix(limit)
            .map(\.0)
    }

    private func bestMoistureReductionCandidates(
        formula: FeedFormula,
        stage: FarmStage,
        metrics: AnalysisSummaryMetrics,
        limit: Int
    ) -> [CorrectionAction] {
        let targetMoisture = (stage.criteria.moistureMinimumPct + stage.criteria.moistureMaximumPct) / 2
        let criteria = stage.criteria

        let ranked = formula.items.compactMap { item -> (CorrectionAction, Double)? in
            guard let defID = item.definitionID,
                  let definition = ingredientDefinition(id: defID) else { return nil }
            let amountKg = moistureAdjustmentKgForReduction(
                item: item,
                definition: definition,
                metrics: metrics,
                targetMoisturePct: targetMoisture
            )
            guard amountKg >= 0.1 else { return nil }
            let action = makeDecreaseAction(definition: definition, amountKg: amountKg)
            guard let simulated = simulateApplying(actions: [action], to: formula) else { return nil }
            return (action, totalCoreGap(metrics: simulated.metrics, criteria: criteria))
        }

        return ranked
            .sorted(by: { lhs, rhs in
                if abs(lhs.1 - rhs.1) > 0.001 { return lhs.1 < rhs.1 }
                return lhs.0.amountKg < rhs.0.amountKg
            })
            .prefix(limit)
            .map(\.0)
    }

    private func moistureAdjustmentKgForAddition(
        definition: IngredientDefinition,
        metrics: AnalysisSummaryMetrics,
        targetMoisturePct: Double
    ) -> Double {
        let targetDmFraction = (100 - targetMoisturePct) / 100
        let ingredientDmFraction = definition.nutrition.dmPct / 100
        let numerator = metrics.totalDmKg - (targetDmFraction * metrics.totalAsFedKg)
        let denominator = targetDmFraction - ingredientDmFraction
        guard denominator > 0.0001, numerator > 0 else { return 0 }
        return max(numerator / denominator, 0.1)
    }

    private func moistureAdjustmentKgForReduction(
        item: IngredientLine,
        definition: IngredientDefinition,
        metrics: AnalysisSummaryMetrics,
        targetMoisturePct: Double
    ) -> Double {
        let currentAmountKg = asFedKg(for: item)
        let targetDmFraction = (100 - targetMoisturePct) / 100
        let ingredientDmFraction = definition.nutrition.dmPct / 100
        let numerator = (targetDmFraction * metrics.totalAsFedKg) - metrics.totalDmKg
        let denominator = targetDmFraction - ingredientDmFraction
        guard denominator > 0.0001, numerator > 0 else { return 0 }
        return min(max(numerator / denominator, 0.1), max(0, currentAmountKg - 1.0))
    }

    private func deduplicateActionCandidates(_ actions: [CorrectionAction]) -> [CorrectionAction] {
        var seen: Set<String> = []
        return actions.filter { action in
            let amountKey = String(format: "%.1f", action.amountKg)
            let key = "\(action.ingredientID ?? action.ingredientName)|\(action.type)|\(amountKey)"
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
    }

    private func makeBeamState(
        actions: [CorrectionAction],
        originalFormula: FeedFormula,
        stage: FarmStage
    ) -> BeamState? {
        let consolidated = consolidateActions(actions, originalFormula: originalFormula)
        guard let result = simulateApplying(actions: consolidated, to: originalFormula) else { return nil }
        let costDelta = consolidated.reduce(0) { acc, act -> Int in
            guard let defID = act.ingredientID, let def = ingredientDefinition(id: defID) else { return acc }
            let price = effectivePricePerKgInFormula(for: def, within: originalFormula)
            let delta = Int((Double(price) * act.amountKg).rounded())
            switch act.type {
            case .decrease: return acc - delta
            case .increase, .add: return acc + delta
            }
        }
        return BeamState(
            actions: consolidated,
            formula: result.formula,
            metrics: result.metrics,
            gap: totalCoreGap(metrics: result.metrics, criteria: stage.criteria),
            fullyResolved: allCoreTargetsSatisfied(metrics: result.metrics, criteria: stage.criteria),
            primaryResolved: primaryTargetsSatisfied(metrics: result.metrics, criteria: stage.criteria),
            viable: isPlanViable(result.metrics, criteria: stage.criteria),
            costDeltaKrw: costDelta
        )
    }

    private func pruneBeamStates(
        _ states: [BeamState],
        originalFormula: FeedFormula,
        width: Int
    ) -> [BeamState] {
        var bestBySignature: [String: BeamState] = [:]
        for state in states {
            let signature = beamSignature(for: state.actions, originalFormula: originalFormula)
            if let existing = bestBySignature[signature] {
                bestBySignature[signature] = betterBeamState(existing, state)
            } else {
                bestBySignature[signature] = state
            }
        }
        return bestBySignature.values
            .sorted(by: beamStateSort)
            .prefix(width)
            .map { $0 }
    }

    private func beamSignature(
        for actions: [CorrectionAction],
        originalFormula: FeedFormula
    ) -> String {
        consolidateActions(actions, originalFormula: originalFormula)
            .map {
                let amountKey = String(format: "%.1f", $0.amountKg)
                return "\($0.ingredientID ?? $0.ingredientName)|\($0.type)|\(amountKey)"
            }
            .sorted()
            .joined(separator: ",")
    }

    private func betterBeamState(_ lhs: BeamState?, _ rhs: BeamState) -> BeamState {
        guard let lhs else { return rhs }
        return beamStateSort(lhs, rhs) ? lhs : rhs
    }

    private func beamStateSort(_ lhs: BeamState, _ rhs: BeamState) -> Bool {
        if lhs.fullyResolved != rhs.fullyResolved { return lhs.fullyResolved && !rhs.fullyResolved }
        if lhs.primaryResolved != rhs.primaryResolved { return lhs.primaryResolved && !rhs.primaryResolved }
        if lhs.viable != rhs.viable { return lhs.viable && !rhs.viable }
        if abs(lhs.gap - rhs.gap) > 0.001 { return lhs.gap < rhs.gap }
        if lhs.actions.count != rhs.actions.count { return lhs.actions.count < rhs.actions.count }
        return abs(lhs.costDeltaKrw) < abs(rhs.costDeltaKrw)
    }

    private func consolidateActions(
        _ actions: [CorrectionAction],
        originalFormula: FeedFormula
    ) -> [CorrectionAction] {
        var grouped: [String: CorrectionAction] = [:]
        let existingIDs = Set(originalFormula.items.compactMap(\.definitionID))

        for action in actions where action.amountKg >= 0.05 {
            let normalizedType: CorrectionActionType
            switch action.type {
            case .decrease:
                normalizedType = .decrease
            case .add, .increase:
                normalizedType = existingIDs.contains(action.ingredientID ?? "") ? .increase : .add
            }

            let key = "\(action.ingredientID ?? action.ingredientName)|\(normalizedType)"
            if var existing = grouped[key] {
                existing.amountKg += action.amountKg
                existing.displayAmount = "약 \(numberString(existing.amountKg))kg"
                grouped[key] = existing
            } else {
                grouped[key] = CorrectionAction(
                    ingredientID: action.ingredientID,
                    ingredientName: action.ingredientName,
                    type: normalizedType,
                    amountKg: action.amountKg,
                    displayAmount: "약 \(numberString(action.amountKg))kg"
                )
            }
        }

        return grouped.values.sorted {
            if $0.type == $1.type { return $0.ingredientName < $1.ingredientName }
            return actionSortOrder($0.type) < actionSortOrder($1.type)
        }
    }

    private func actionSortOrder(_ type: CorrectionActionType) -> Int {
        switch type {
        case .decrease: return 0
        case .increase: return 1
        case .add: return 2
        }
    }

    private func buildMineralCorrectionActions(
        formula: FeedFormula,
        stage: FarmStage,
        metrics: AnalysisSummaryMetrics
    ) -> [CorrectionAction] {
        let criteria = stage.criteria
        var actions: [CorrectionAction] = []

        let totalCaKg = metrics.totalDmKg * metrics.caPctDm / 100
        let totalPKg = metrics.totalDmKg * metrics.pPctDm / 100
        let requiredCaKg = max(
            max(0, metrics.totalDmKg * criteria.caMinPctDm / 100 - totalCaKg),
            max(0, totalPKg * criteria.caPRatioMin - totalCaKg)
        )

        if requiredCaKg > 0.005,
           let limestone = ingredientDefinition(id: "FEED_109") {
            let amountKg = computeSpecificNutrientBoostKg(
                definition: limestone,
                requiredKg: requiredCaKg,
                nutritionPath: \.caPctDm,
                lower: 0.1
            )
            if amountKg > 0.05 {
                actions.append(makeAddOrIncreaseAction(definition: limestone, formula: formula, amountKg: amountKg))
            }
        }

        let requiredPKg = max(
            max(0, metrics.totalDmKg * criteria.pMinPctDm / 100 - totalPKg),
            max(0, totalCaKg / criteria.caPRatioMax - totalPKg)
        )

        if requiredPKg > 0.003,
           let phosphate = ingredientDefinition(id: "FEED_111") {
            let amountKg = computeSpecificNutrientBoostKg(
                definition: phosphate,
                requiredKg: requiredPKg,
                nutritionPath: \.pPctDm,
                lower: 0.1
            )
            if amountKg > 0.05 {
                actions.append(makeAddOrIncreaseAction(definition: phosphate, formula: formula, amountKg: amountKg))
            }
        }

        return actions
    }

    private func isPlanViable(_ metrics: AnalysisSummaryMetrics, criteria: StageCriteria) -> Bool {
        guard metrics.moisturePct <= criteria.moistureHardMaximumPct else { return false }
        let minHardRatio = max(0.8, criteria.caPRatioCautionMin - 0.25)
        let maxHardRatio = criteria.caPRatioCautionMax + 0.5
        return metrics.caPRatio >= minHardRatio && metrics.caPRatio <= maxHardRatio
    }

    // MARK: - 플랜 선정 → Recommendation 변환

    private func selectTopRecommendations(
        from plans: [PatternPlan],
        originalMetrics: AnalysisSummaryMetrics,
        stage: FarmStage
    ) -> [Recommendation] {
        let deduplicated = deduplicatePlans(plans)
        let fullyResolved   = deduplicated.filter(\.isFullyResolved)
        let primaryResolved = deduplicated.filter(\.isPrimaryResolved)
        let isPrimaryFallback = fullyResolved.isEmpty && !primaryResolved.isEmpty
        guard !fullyResolved.isEmpty || !primaryResolved.isEmpty else {
            return [noSolutionRecommendation(metrics: originalMetrics)]
        }
        let unique = isPrimaryFallback ? primaryResolved : fullyResolved

        // ownedFirst: 기존 배합 원료만 사용 (add 액션 없음) 중 resolutionRate 최고
        let ownedOnly = unique.filter { $0.actions.allSatisfy { $0.type != .add } }
        let ownedBest = (ownedOnly.isEmpty ? unique : ownedOnly)
            .max(by: { $0.resolutionRate < $1.resolutionRate })

        // costEffective: resolution 충분 (≥0.3)한 플랜 중 costDelta 최소
        let costBest = unique
            .sorted { lhs, rhs in
                let lhsOk = lhs.resolutionRate >= 0.3
                let rhsOk = rhs.resolutionRate >= 0.3
                if lhsOk != rhsOk { return lhsOk }
                return lhs.costDeltaKrw < rhs.costDeltaKrw
            }.first

        var results: [Recommendation] = []
        var usedKeys: Set<String> = []

        if isPrimaryFallback {
            results.append(noSolutionRecommendation(metrics: originalMetrics))
        }

        func addIfUnique(_ plan: PatternPlan?, strategy: RecommendationStrategy, referenceOnly: Bool) {
            guard let plan else { return }
            let key = plan.actions
                .map { "\($0.ingredientID ?? "")|\($0.type)|\(String(format: "%.2f", $0.amountKg))" }
                .sorted().joined(separator: ",")
            guard !usedKeys.contains(key) else { return }
            usedKeys.insert(key)
            results.append(planToRecommendation(plan: plan, strategy: strategy,
                                                originalMetrics: originalMetrics, stage: stage,
                                                referenceOnly: referenceOnly))
        }

        addIfUnique(ownedBest, strategy: .ownedFirst, referenceOnly: isPrimaryFallback)
        addIfUnique(costBest, strategy: .costEffective, referenceOnly: isPrimaryFallback)

        return results.isEmpty ? [noSolutionRecommendation(metrics: originalMetrics)] : results
    }

    private func deduplicatePlans(_ plans: [PatternPlan]) -> [PatternPlan] {
        var seen: Set<String> = []
        return plans.filter { plan in
            let key = plan.actions
                .map { "\($0.ingredientID ?? "x")|\($0.type)|\(String(format: "%.2f", $0.amountKg))" }
                .sorted().joined(separator: ",")
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
    }

    private func planToRecommendation(
        plan: PatternPlan,
        strategy: RecommendationStrategy,
        originalMetrics: AnalysisSummaryMetrics,
        stage: FarmStage,
        referenceOnly: Bool = false
    ) -> Recommendation {
        let actionLabel = plan.actions.map(correctionActionLabel).joined(separator: ", ")
        let primaryAction = plan.actions.first
        let primaryDef = primaryAction?.ingredientID.flatMap { ingredientDefinition(id: $0) }
        let reason = buildPatternReason(plan: plan, stage: stage, originalMetrics: originalMetrics)

        return Recommendation(
            strategy: strategy,
            title: strategy.title,
            ingredientID: primaryAction?.ingredientID,
            ingredient: primaryDef?.name ?? primaryAction?.ingredientName ?? "배합 교정",
            action: actionLabel,
            reason: reason,
            suggestedAmount: primaryAction?.displayAmount,
            amountNote: plan.strategyLabel,
            trialAmountKg: plan.actions.filter { $0.type != .decrease }.reduce(0) { $0 + $1.amountKg },
            simulatedMetrics: plan.simulatedMetrics,
            costDeltaKrw: plan.costDeltaKrw,
            isAlreadyInFormula: primaryAction?.type == .increase,
            correctionActions: plan.actions,
            pros: Array(plan.pros.prefix(3)),
            cons: Array(plan.cons.prefix(3)),
            resolutionRate: plan.resolutionRate,
            isFullyResolved: plan.isFullyResolved,
            isReferenceOnly: referenceOnly
        )
    }

    // MARK: - Pros / Cons / Reason 생성

    private func buildPatternPros(
        originalMetrics: AnalysisSummaryMetrics,
        metrics: AnalysisSummaryMetrics,
        actions: [CorrectionAction],
        criteria: StageCriteria
    ) -> [String] {
        var pros: [String] = []
        if metrics.cpPctDm > originalMetrics.cpPctDm && cpDeficit(metrics: originalMetrics, criteria: criteria) > 0 {
            pros.append("CP 개선")
        }
        if metrics.tdnPctDm > originalMetrics.tdnPctDm && tdnDeficit(metrics: originalMetrics, criteria: criteria) > 0 {
            pros.append("TDN 개선")
        }
        if metrics.cpPctDm < originalMetrics.cpPctDm && originalMetrics.cpPctDm > criteria.cpMaximumPctDm {
            pros.append("CP 과잉 완화")
        }
        if metrics.tdnPctDm < originalMetrics.tdnPctDm && originalMetrics.tdnPctDm > criteria.tdnMaximumPctDm {
            pros.append("TDN 과잉 완화")
        }
        if metrics.eePctDm < originalMetrics.eePctDm && originalMetrics.eePctDm > criteria.eeMaxPctDm {
            pros.append("EE 과잉 완화")
        }
        let ndfBefore = rangeDistance(originalMetrics.ndfPctDm, minimum: criteria.ndfMinPctDm, maximum: criteria.ndfMaxPctDm)
        let ndfAfter  = rangeDistance(metrics.ndfPctDm, minimum: criteria.ndfMinPctDm, maximum: criteria.ndfMaxPctDm)
        if ndfAfter < ndfBefore - 0.5 { pros.append("NDF 균형 개선") }
        if allCoreTargetsSatisfied(metrics: metrics, criteria: criteria) { pros.append("핵심 기준 전체 충족") }
        if actions.allSatisfy({ $0.type != .add }) { pros.append("현재 보유 원료만 활용") }
        return pros
    }

    private func buildPatternCons(
        originalMetrics: AnalysisSummaryMetrics,
        metrics: AnalysisSummaryMetrics,
        actions: [CorrectionAction],
        criteria: StageCriteria,
        costDelta: Int
    ) -> [String] {
        var cons: [String] = []
        if metrics.cpPctDm < criteria.cpMinimumPctDm { cons.append("CP 부족 주의") }
        if metrics.tdnPctDm < criteria.tdnMinimumPctDm { cons.append("TDN 부족 주의") }
        if metrics.ndfPctDm > criteria.ndfMaxPctDm { cons.append("NDF 과잉 주의") }
        if metrics.adfPctDm > criteria.adfMaxPctDm { cons.append("ADF 과잉 주의") }
        if actions.contains(where: { $0.type == .add }) { cons.append("신규 원료 구매 필요") }
        if costDelta > 5000 { cons.append("원료비 증가 예상") }
        return cons
    }

    // reason 필드 = 감지된 문제 수치만 (구조적 팩트).
    // 자연어 설명은 AI(LLM) 담당. simulatedMetrics / correctionActions / resolutionRate / isFullyResolved로 충분.
    private func buildPatternReason(
        plan: PatternPlan,
        stage: FarmStage,
        originalMetrics: AnalysisSummaryMetrics
    ) -> String {
        buildProblemNumerics(metrics: originalMetrics, criteria: stage.criteria, patternLabel: plan.patternLabel)
    }

    // 패턴별 문제 수치 설명 (예: "CP 18.5%(목표 12~15%)로 과잉입니다.")
    private func buildProblemNumerics(
        metrics: AnalysisSummaryMetrics,
        criteria: StageCriteria,
        patternLabel: String
    ) -> String {
        var issues: [String] = []

        let cpOver  = metrics.cpPctDm  - criteria.cpMaximumPctDm
        let cpShort = criteria.cpMinimumPctDm - metrics.cpPctDm
        let tdnOver  = metrics.tdnPctDm - criteria.tdnMaximumPctDm
        let tdnShort = criteria.tdnMinimumPctDm - metrics.tdnPctDm
        let eeOver   = metrics.eePctDm - criteria.eeMaxPctDm
        let ndfOver  = metrics.ndfPctDm - criteria.ndfMaxPctDm
        let ndfShort = criteria.ndfMinPctDm - metrics.ndfPctDm
        let adfOver  = metrics.adfPctDm - criteria.adfMaxPctDm

        let cp  = String(format: "%.1f", metrics.cpPctDm)
        let tdn = String(format: "%.1f", metrics.tdnPctDm)
        let ee  = String(format: "%.1f", metrics.eePctDm)
        let ndf = String(format: "%.1f", metrics.ndfPctDm)
        let adf = String(format: "%.1f", metrics.adfPctDm)

        if cpOver  > 0.1 { issues.append("CP \(cp)%(목표 \(fmt(criteria.cpMinimumPctDm))~\(fmt(criteria.cpMaximumPctDm))%) 과잉") }
        if cpShort > 0.1 { issues.append("CP \(cp)%(목표 \(fmt(criteria.cpMinimumPctDm))~\(fmt(criteria.cpMaximumPctDm))%) 부족") }
        if tdnOver  > 0.1 { issues.append("TDN \(tdn)%(목표 \(fmt(criteria.tdnMinimumPctDm))~\(fmt(criteria.tdnMaximumPctDm))%) 과잉") }
        if tdnShort > 0.1 { issues.append("TDN \(tdn)%(목표 \(fmt(criteria.tdnMinimumPctDm))~\(fmt(criteria.tdnMaximumPctDm))%) 부족") }
        if eeOver  > 0.1 { issues.append("EE \(ee)%(목표 \(fmt(criteria.eeMaxPctDm))% 이하) 과잉") }
        if ndfOver  > 0.1 { issues.append("NDF \(ndf)%(목표 \(fmt(criteria.ndfMinPctDm))~\(fmt(criteria.ndfMaxPctDm))%) 과잉") }
        if ndfShort > 0.1 { issues.append("NDF \(ndf)%(목표 \(fmt(criteria.ndfMinPctDm))~\(fmt(criteria.ndfMaxPctDm))%) 부족") }
        if adfOver  > 0.1 { issues.append("ADF \(adf)%(목표 \(fmt(criteria.adfMinPctDm))~\(fmt(criteria.adfMaxPctDm))%) 과잉") }

        guard !issues.isEmpty else { return "" }
        return issues.joined(separator: ", ") + "."
    }

    private func fmt(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }

    // MARK: - 과잉 판단 헬퍼 (sequential fallback용)

    private struct OverageSpec {
        let kind: OverageNutrientKind
        let nutritionPath: KeyPath<IngredientNutritionProfile, Double>
        let excess: Double
        let targetPctDm: Double
    }

    private func mostSevereOverage(
        formula: FeedFormula,
        stage: FarmStage,
        metrics: AnalysisSummaryMetrics
    ) -> OverageSpec? {
        let c = stage.criteria
        let candidates: [OverageSpec] = [
            OverageSpec(kind: .cp,  nutritionPath: \.cpPctDm,
                        excess: max(0, metrics.cpPctDm  - c.cpMaximumPctDm),
                        targetPctDm: max(c.cpMinimumPctDm,  c.cpMaximumPctDm  - 0.5)),
            OverageSpec(kind: .tdn, nutritionPath: \.tdnPctDm,
                        excess: max(0, metrics.tdnPctDm - c.tdnMaximumPctDm),
                        targetPctDm: max(c.tdnMinimumPctDm, c.tdnMaximumPctDm - 0.5)),
            OverageSpec(kind: .ee,  nutritionPath: \.eePctDm,
                        excess: max(0, metrics.eePctDm  - c.eeMaxPctDm),
                        targetPctDm: c.eeMaxPctDm),
            OverageSpec(kind: .ndf, nutritionPath: \.ndfPctDm,
                        excess: max(0, metrics.ndfPctDm - c.ndfMaxPctDm),
                        targetPctDm: c.ndfMaxPctDm),
            OverageSpec(kind: .adf, nutritionPath: \.adfPctDm,
                        excess: max(0, metrics.adfPctDm - c.adfMaxPctDm),
                        targetPctDm: c.adfMaxPctDm),
        ]
        return candidates.filter { $0.excess > 0.1 }.max(by: { $0.excess < $1.excess })
    }

    // 감량 후 핵심 성분 붕괴 여부 체크
    private func isAcceptableReduction(
        before: AnalysisSummaryMetrics,
        after: AnalysisSummaryMetrics,
        targetNutrient: OverageNutrientKind,
        criteria: StageCriteria
    ) -> Bool {
        guard moistureTone(after.moisturePct, criteria: criteria) != .excess else { return false }
        if targetNutrient != .cp, before.cpPctDm >= criteria.cpMinimumPctDm,
           after.cpPctDm < (criteria.cpMinimumPctDm - 1.5) { return false }
        if targetNutrient != .tdn, before.tdnPctDm >= criteria.tdnMinimumPctDm,
           after.tdnPctDm < (criteria.tdnMinimumPctDm - 1.5) { return false }
        return true
    }

    // MARK: - 감량량 계산 (역산 + fallback)

    private func reductionAmountCandidates(
        formula: FeedFormula,
        metrics: AnalysisSummaryMetrics,
        stage: FarmStage,
        definition: IngredientDefinition,
        currentAmountKg: Double,
        nutritionPath: KeyPath<IngredientNutritionProfile, Double>,
        metricsPath: KeyPath<AnalysisSummaryMetrics, Double>,
        maxPctDm: Double,
        targetPctDm: Double
    ) -> [Double] {
        let minimumRemainingKg = 1.0
        let maximumReductionKg = max(0, currentAmountKg - minimumRemainingKg)
        guard maximumReductionKg >= 0.1 else { return [] }

        let preferred = preferredReductionAmount(
            formula: formula, metrics: metrics, definition: definition,
            currentAmountKg: currentAmountKg, nutritionPath: nutritionPath,
            metricsPath: metricsPath, maxPctDm: maxPctDm, targetPctDm: targetPctDm
        )
        var seen: Set<String> = []
        return [preferred, maximumReductionKg * 0.5, maximumReductionKg * 0.25]
            .map { min(max($0, 0.1), maximumReductionKg) }
            .filter { candidate in
                guard candidate >= 0.1 else { return false }
                let key = String(format: "%.3f", candidate)
                if seen.contains(key) { return false }
                seen.insert(key)
                return true
            }
            .sorted(by: >)
    }

    // 이진 탐색으로 목표 수준까지 감량하는 최소량 역산
    private func preferredReductionAmount(
        formula: FeedFormula,
        metrics: AnalysisSummaryMetrics,
        definition: IngredientDefinition,
        currentAmountKg: Double,
        nutritionPath: KeyPath<IngredientNutritionProfile, Double>,
        metricsPath: KeyPath<AnalysisSummaryMetrics, Double>,
        maxPctDm: Double,
        targetPctDm: Double
    ) -> Double {
        let minimumRemainingKg = 1.0
        let maximumReductionKg = max(0, currentAmountKg - minimumRemainingKg)
        guard maximumReductionKg >= 0.1 else { return 0 }

        var low = 0.0, high = maximumReductionKg, best = maximumReductionKg
        for _ in 0..<14 {
            let candidate = max(0.05, (low + high) / 2)
            let act = CorrectionAction(ingredientID: definition.id, ingredientName: definition.name,
                                       type: .decrease, amountKg: candidate, displayAmount: "")
            guard let result = simulateApplying(actions: [act], to: formula) else { high = candidate; continue }
            best = candidate
            if result.metrics[keyPath: metricsPath] <= targetPctDm { high = candidate } else { low = candidate }
        }
        return min(max(best, 0.1), maximumReductionKg)
    }

    // MARK: - 영양소 키패스 / 기준값 맵핑

    private func nutritionKeyPath(for kind: OverageNutrientKind) -> KeyPath<IngredientNutritionProfile, Double> {
        switch kind {
        case .cp:  return \.cpPctDm
        case .tdn: return \.tdnPctDm
        case .ee:  return \.eePctDm
        case .ndf: return \.ndfPctDm
        case .adf: return \.adfPctDm
        case .ca:  return \.caPctDm
        case .p:   return \.pPctDm
        }
    }

    private func metricsKeyPath(for kind: OverageNutrientKind) -> KeyPath<AnalysisSummaryMetrics, Double> {
        switch kind {
        case .cp:  return \.cpPctDm
        case .tdn: return \.tdnPctDm
        case .ee:  return \.eePctDm
        case .ndf: return \.ndfPctDm
        case .adf: return \.adfPctDm
        case .ca:  return \.caPctDm
        case .p:   return \.pPctDm
        }
    }

    private func maxPctDm(for kind: OverageNutrientKind, criteria: StageCriteria) -> Double {
        switch kind {
        case .cp:  return criteria.cpMaximumPctDm
        case .tdn: return criteria.tdnMaximumPctDm
        case .ee:  return criteria.eeMaxPctDm
        case .ndf: return criteria.ndfMaxPctDm
        case .adf: return criteria.adfMaxPctDm
        case .ca:  return criteria.caMaxPctDm
        case .p:   return criteria.pMaxPctDm
        }
    }

    private func overageTargetPct(kind: OverageNutrientKind, criteria: StageCriteria) -> Double {
        switch kind {
        case .cp:  return max(criteria.cpMinimumPctDm,  criteria.cpMaximumPctDm  - 0.5)
        case .tdn: return max(criteria.tdnMinimumPctDm, criteria.tdnMaximumPctDm - 0.5)
        case .ee:  return criteria.eeMaxPctDm
        case .ndf: return criteria.ndfMaxPctDm
        case .adf: return criteria.adfMaxPctDm
        case .ca:  return max(criteria.caMinPctDm, criteria.caMaxPctDm - 0.03)
        case .p:   return max(criteria.pMinPctDm, criteria.pMaxPctDm - 0.05)
        }
    }

    private func nutrientDisplayName(_ kind: OverageNutrientKind) -> String {
        switch kind {
        case .cp:  return "CP"
        case .tdn: return "TDN"
        case .ee:  return "조지방(EE)"
        case .ndf: return "NDF"
        case .adf: return "ADF"
        case .ca:  return "칼슘(Ca)"
        case .p:   return "인(P)"
        }
    }

    // MARK: - 고정 추천안 (유지 / 해결 불가)

    private func maintenanceRecommendation(metrics: AnalysisSummaryMetrics) -> Recommendation {
        Recommendation(
            strategy: .maintenance,
            title: RecommendationStrategy.maintenance.title,
            ingredientID: nil,
            ingredient: "현재 배합",
            action: "유지",
            reason: "현재 배합이 단계 기준을 만족합니다. 급격한 변경보다 현재 구조를 유지하며 사육일지로 경과를 확인하는 편이 안전합니다.",
            suggestedAmount: nil,
            amountNote: "현 상태 유지",
            trialAmountKg: 0,
            simulatedMetrics: metrics,
            costDeltaKrw: 0,
            isAlreadyInFormula: true,
            correctionActions: [],
            pros: ["핵심 기준 충족", "추가 비용 없음"],
            cons: [],
            resolutionRate: 1,
            isFullyResolved: true,
            isReferenceOnly: false
        )
    }

    private func noSolutionRecommendation(metrics: AnalysisSummaryMetrics) -> Recommendation {
        Recommendation(
            strategy: .noSolution,
            title: RecommendationStrategy.noSolution.title,
            ingredientID: nil,
            ingredient: "추가 교정",
            action: "추가 교정 필요",
            reason: "현재 원료 DB와 제약 조건 안에서는 완전 적정안이 아직 만들어지지 않았습니다. 핵심 축과 부족 항목을 다시 보면서 교정 범위를 더 넓혀야 합니다.",
            suggestedAmount: nil,
            amountNote: "원료 증감 폭이나 교정 순서를 더 조정해야 합니다.",
            trialAmountKg: 0,
            simulatedMetrics: metrics,
            costDeltaKrw: 0,
            isAlreadyInFormula: false,
            correctionActions: [],
            pros: [],
            cons: ["현재 조건에서는 완전 적정 범위까지 바로 수렴하지 않습니다."],
            resolutionRate: 0,
            isFullyResolved: false,
            isReferenceOnly: false
        )
    }

    // MARK: - 공통 유틸리티

    // 운영 가능 교정안 판정 (핵심 축만 체크)
    // CP/TDN/EE 적정 + Ca:P caution 이내 + NDF/ADF 최소선 + 수분 hard max
    private func primaryTargetsSatisfied(metrics: AnalysisSummaryMetrics, criteria: StageCriteria) -> Bool {
        rangeDistance(metrics.cpPctDm,  minimum: criteria.cpMinimumPctDm,  maximum: criteria.cpMaximumPctDm)  == 0 &&
        rangeDistance(metrics.tdnPctDm, minimum: criteria.tdnMinimumPctDm, maximum: criteria.tdnMaximumPctDm) == 0 &&
        metrics.eePctDm <= criteria.eeMaxPctDm &&
        metrics.caPRatio >= criteria.caPRatioCautionMin && metrics.caPRatio <= criteria.caPRatioCautionMax &&
        metrics.ndfPctDm >= criteria.ndfCautionMinPctDm &&
        metrics.adfPctDm >= criteria.adfCautionMinPctDm &&
        metrics.moisturePct <= criteria.moistureHardMaximumPct
    }

    private func allCoreTargetsSatisfied(metrics: AnalysisSummaryMetrics, criteria: StageCriteria) -> Bool {
        rangeDistance(metrics.cpPctDm,  minimum: criteria.cpMinimumPctDm,  maximum: criteria.cpMaximumPctDm)  == 0 &&
        rangeDistance(metrics.tdnPctDm, minimum: criteria.tdnMinimumPctDm, maximum: criteria.tdnMaximumPctDm) == 0 &&
        metrics.eePctDm <= criteria.eeMaxPctDm &&
        rangeDistance(metrics.caPctDm, minimum: criteria.caMinPctDm, maximum: criteria.caMaxPctDm) == 0 &&
        rangeDistance(metrics.pPctDm,  minimum: criteria.pMinPctDm,  maximum: criteria.pMaxPctDm)  == 0 &&
        rangeDistance(metrics.ndfPctDm, minimum: criteria.ndfMinPctDm, maximum: criteria.ndfMaxPctDm) == 0 &&
        rangeDistance(metrics.adfPctDm, minimum: criteria.adfMinPctDm, maximum: criteria.adfMaxPctDm) == 0 &&
        caPRatioDistance(metrics.caPRatio, criteria: criteria) == 0 &&
        rangeDistance(metrics.moisturePct, minimum: criteria.moistureMinimumPct, maximum: criteria.moistureMaximumPct) == 0
    }

    private func cpDeficit(metrics: AnalysisSummaryMetrics, criteria: StageCriteria) -> Double {
        max(0, criteria.cpMinimumPctDm - metrics.cpPctDm)
    }

    private func tdnDeficit(metrics: AnalysisSummaryMetrics, criteria: StageCriteria) -> Double {
        max(0, criteria.tdnMinimumPctDm - metrics.tdnPctDm)
    }

    private func ndfGap(metrics: AnalysisSummaryMetrics, criteria: StageCriteria) -> Double {
        rangeDistance(metrics.ndfPctDm, minimum: criteria.ndfMinPctDm, maximum: criteria.ndfMaxPctDm)
    }

    private func adfGap(metrics: AnalysisSummaryMetrics, criteria: StageCriteria) -> Double {
        rangeDistance(metrics.adfPctDm, minimum: criteria.adfMinPctDm, maximum: criteria.adfMaxPctDm)
    }

    private func effectivePricePerKgInFormula(for definition: IngredientDefinition, within formula: FeedFormula) -> Int {
        if let existingItem = formula.items.first(where: { $0.definitionID == definition.id }),
           let override = effectivePricePerKg(for: existingItem) {
            return override
        }
        return definition.defaultPriceKrwPerKg
    }

    private func overallResolutionRate(
        before: AnalysisSummaryMetrics,
        after: AnalysisSummaryMetrics,
        criteria: StageCriteria
    ) -> Double {
        var resolutions: [Double] = []

        func addResolution(gapBefore: Double, gapAfter: Double) {
            guard gapBefore > 0.01 else { return }
            resolutions.append(clamp((gapBefore - gapAfter) / gapBefore, lower: 0, upper: 1))
        }

        addResolution(
            gapBefore: rangeDistance(before.cpPctDm, minimum: criteria.cpMinimumPctDm, maximum: criteria.cpMaximumPctDm),
            gapAfter:  rangeDistance(after.cpPctDm,  minimum: criteria.cpMinimumPctDm, maximum: criteria.cpMaximumPctDm))
        addResolution(
            gapBefore: rangeDistance(before.tdnPctDm, minimum: criteria.tdnMinimumPctDm, maximum: criteria.tdnMaximumPctDm),
            gapAfter:  rangeDistance(after.tdnPctDm,  minimum: criteria.tdnMinimumPctDm, maximum: criteria.tdnMaximumPctDm))
        addResolution(
            gapBefore: max(0, before.eePctDm - criteria.eeMaxPctDm),
            gapAfter:  max(0, after.eePctDm  - criteria.eeMaxPctDm))
        addResolution(
            gapBefore: rangeDistance(before.ndfPctDm, minimum: criteria.ndfMinPctDm, maximum: criteria.ndfMaxPctDm),
            gapAfter:  rangeDistance(after.ndfPctDm,  minimum: criteria.ndfMinPctDm, maximum: criteria.ndfMaxPctDm))
        addResolution(
            gapBefore: rangeDistance(before.adfPctDm, minimum: criteria.adfMinPctDm, maximum: criteria.adfMaxPctDm),
            gapAfter:  rangeDistance(after.adfPctDm,  minimum: criteria.adfMinPctDm, maximum: criteria.adfMaxPctDm))
        addResolution(
            gapBefore: rangeDistance(before.caPctDm, minimum: criteria.caMinPctDm, maximum: criteria.caMaxPctDm),
            gapAfter:  rangeDistance(after.caPctDm,  minimum: criteria.caMinPctDm, maximum: criteria.caMaxPctDm))
        addResolution(
            gapBefore: rangeDistance(before.pPctDm, minimum: criteria.pMinPctDm, maximum: criteria.pMaxPctDm),
            gapAfter:  rangeDistance(after.pPctDm,  minimum: criteria.pMinPctDm, maximum: criteria.pMaxPctDm))
        addResolution(
            gapBefore: caPRatioDistance(before.caPRatio, criteria: criteria),
            gapAfter:  caPRatioDistance(after.caPRatio,  criteria: criteria))
        addResolution(
            gapBefore: rangeDistance(before.moisturePct, minimum: criteria.moistureMinimumPct, maximum: criteria.moistureMaximumPct),
            gapAfter:  rangeDistance(after.moisturePct,  minimum: criteria.moistureMinimumPct, maximum: criteria.moistureMaximumPct))

        guard !resolutions.isEmpty else { return 1 }
        return resolutions.min() ?? 0
    }

    private func totalCoreGap(metrics: AnalysisSummaryMetrics, criteria: StageCriteria) -> Double {
        rangeDistance(metrics.cpPctDm, minimum: criteria.cpMinimumPctDm, maximum: criteria.cpMaximumPctDm) * 2.5 +
        rangeDistance(metrics.tdnPctDm, minimum: criteria.tdnMinimumPctDm, maximum: criteria.tdnMaximumPctDm) * 2.5 +
        max(0, metrics.eePctDm - criteria.eeMaxPctDm) * 1.5 +
        ndfGap(metrics: metrics, criteria: criteria) * 1.0 +
        adfGap(metrics: metrics, criteria: criteria) * 1.0 +
        rangeDistance(metrics.caPctDm, minimum: criteria.caMinPctDm, maximum: criteria.caMaxPctDm) * 1.2 +
        rangeDistance(metrics.pPctDm, minimum: criteria.pMinPctDm, maximum: criteria.pMaxPctDm) * 1.2 +
        caPRatioDistance(metrics.caPRatio, criteria: criteria) * 2.0 +
        rangeDistance(metrics.moisturePct, minimum: criteria.moistureMinimumPct, maximum: criteria.moistureMaximumPct) * 0.8
    }
}
