import SwiftUI

// MARK: - PrototypeStore 엔진 회귀 검증 책임
// 테스트 배합 시나리오 평가 및 디버그 덤프.

extension PrototypeStore {
    func dumpRegressionRecommendationsIfNeeded() {
        let processInfo = ProcessInfo.processInfo
        let shouldDumpFromEnv = processInfo.environment["DEBUG_RECOMMENDATION_DUMP"] == "1"
        let shouldDumpFromArgs = processInfo.arguments.contains("DEBUG_RECOMMENDATION_DUMP")
        guard shouldDumpFromEnv || shouldDumpFromArgs else { return }

        let targetNames = [
            "농가 배합 테스트",
            "경기TMR 3000kg 테스트 배합",
            "엔진검증 - CP 과잉",
            "엔진검증 - TDN 과잉",
            "엔진검증 - CP 부족",
            "엔진검증 - EE 과잉 + CP 부족"
        ]

        var lines: [String] = []
        for name in targetNames {
            guard let formula = formulas.first(where: { $0.name == name }) else { continue }
            let analysis = analysis(for: formula)
            let recommendation = defaultRecommendation(from: analysis.recommendations) ?? analysis.recommendations.first
            lines.append("=== REGRESSION \(name) ===")
            lines.append("summary=\(analysis.summary)")
            if let recommendation {
                lines.append("strategy=\(recommendation.strategy.rawValue) resolved=\(recommendation.isFullyResolved) rate=\(String(format: "%.2f", recommendation.resolutionRate)) cost=\(recommendation.costDeltaKrw)")
                for action in recommendation.correctionActions {
                    lines.append("action=\(action.type) \(action.ingredientName) \(String(format: "%.1f", action.amountKg))kg")
                }
                lines.append("reason=\(recommendation.reason)")
            } else {
                lines.append("strategy=none")
            }
            for other in analysis.recommendations where other.isReferenceOnly {
                lines.append("reference rate=\(String(format: "%.2f", other.resolutionRate)) totalAsFed=\(String(format: "%.1f", other.simulatedMetrics.totalAsFedKg))kg")
                for action in other.correctionActions {
                    lines.append("  ref-action=\(action.type) \(action.ingredientName) \(String(format: "%.1f", action.amountKg))kg")
                }
            }
            lines.append("")
        }

        let text = lines.joined(separator: "\n")
        debugLogger.notice("\(text)")
        print(text)
        if let data = text.data(using: .utf8) {
            let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("recommendation-dump.txt")
            try? data.write(to: tempURL, options: .atomic)
            if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let documentsDumpURL = documentsURL.appendingPathComponent("recommendation-dump.txt")
                try? data.write(to: documentsDumpURL, options: .atomic)
            }
            if let explicitDumpPath = processInfo.environment["DEBUG_RECOMMENDATION_DUMP_PATH"],
               !explicitDumpPath.isEmpty {
                let explicitDumpURL = URL(fileURLWithPath: explicitDumpPath)
                try? data.write(to: explicitDumpURL, options: .atomic)
            }
        }
    }

    func regressionSuiteResults() -> [RegressionScenarioResult] {
        regressionFormulas.map { formula in
            let analysis = analysis(for: formula)
            let primary = defaultRecommendation(from: analysis.recommendations)
            let projectedStatuses = primary.map {
                buildStatuses(stage: formula.stage, criteria: formula.stage.criteria, metrics: $0.simulatedMetrics)
            } ?? []
            return evaluateRegressionScenario(
                formula: formula,
                analysis: analysis,
                primaryRecommendation: primary,
                projectedStatuses: projectedStatuses
            )
        }
    }

    private func evaluateRegressionScenario(
        formula: FeedFormula,
        analysis: AnalysisRun,
        primaryRecommendation: Recommendation?,
        projectedStatuses: [NutrientStatus]
    ) -> RegressionScenarioResult {
        let currentIssues = issueLabels(from: analysis.statuses)
        let nextIssues = issueLabels(from: projectedStatuses)
        let checks = regressionChecks(
            formula: formula,
            analysis: analysis,
            primaryRecommendation: primaryRecommendation,
            projectedStatuses: projectedStatuses
        )

        return RegressionScenarioResult(
            formula: formula,
            analysis: analysis,
            primaryRecommendation: primaryRecommendation,
            projectedStatuses: projectedStatuses,
            expectationSummary: regressionExpectationSummary(for: formula),
            currentIssues: currentIssues,
            projectedIssues: nextIssues,
            checks: checks
        )
    }

    private func regressionExpectationSummary(for formula: FeedFormula) -> String {
        switch formula.name {
        case "경기TMR 3000kg 테스트 배합":
            return "사용자 제공 3000kg 테스트 배합 기준으로 복합 교정안과 광물질 보정까지 함께 검증합니다."
        case "엔진검증 - CP 과잉":
            return "단백질원 감량이 우선으로 나와야 하며, 감량 후 TDN과 섬유가 크게 무너지지 않아야 합니다."
        case "엔진검증 - TDN 과잉":
            return "에너지 기여가 큰 곡류와 당밀 감량이 먼저 제안되고, 조사료 부족으로 즉시 무너지지 않아야 합니다."
        case "엔진검증 - CP 부족":
            return "단백질 보강이 우선으로 나와야 하며, 조사료 부족이나 EE 과잉을 새로 만들지 않아야 합니다."
        case "엔진검증 - EE 과잉 + CP 부족":
            return "고지방 원료 감량 후 단백질 보강으로 이어지는 복합교정안이 나와야 합니다."
        default:
            return ""
        }
    }

    private func issueLabels(from statuses: [NutrientStatus]) -> [String] {
        statuses.compactMap { status in
            switch status.tone {
            case .adequate:
                return nil
            case .caution:
                return "\(status.nutrient) 주의"
            case .deficient:
                return "\(status.nutrient) 부족"
            case .excess:
                return "\(status.nutrient) 과잉"
            }
        }
    }

    private func regressionChecks(
        formula: FeedFormula,
        analysis: AnalysisRun,
        primaryRecommendation: Recommendation?,
        projectedStatuses: [NutrientStatus]
    ) -> [RegressionCheck] {
        guard let recommendation = primaryRecommendation else {
            return [
                RegressionCheck(
                    title: "추천안 생성",
                    passed: false,
                    detail: "대표 추천안이 생성되지 않았습니다."
                )
            ]
        }

        let correctionActions = recommendation.correctionActions
        let issueImproved = severityScore(for: projectedStatuses) < severityScore(for: analysis.statuses)
        var checks: [RegressionCheck] = [
            RegressionCheck(
                title: "복합교정안 형태",
                passed: correctionActions.count >= 2,
                detail: correctionActions.count >= 2
                    ? "교정 액션 \(correctionActions.count)개로 복합교정안 형태를 만족합니다."
                    : "현재 교정 액션이 \(correctionActions.count)개라 단일 조정에 가깝습니다."
            ),
            RegressionCheck(
                title: "적용 후 예상 개선",
                passed: issueImproved,
                detail: issueImproved
                    ? "적용 후 예상 이탈 점수가 줄어들었습니다."
                    : "적용 후 예상 이탈 점수가 충분히 줄지 않았습니다."
            )
        ]

        switch formula.name {
        case "엔진검증 - CP 과잉":
            let hasProteinDecrease = hasDecreaseAction(in: correctionActions, ingredientIDs: proteinSourceIDs)
            checks.append(
                RegressionCheck(
                    title: "단백질원 감량",
                    passed: hasProteinDecrease,
                    detail: hasProteinDecrease
                        ? "단백질 기여 원료 감량이 포함되었습니다."
                        : "단백질 기여 원료 감량이 추천안에 보이지 않습니다."
                )
            )
        case "엔진검증 - TDN 과잉":
            let hasEnergyDecrease = hasDecreaseAction(in: correctionActions, ingredientIDs: energySourceIDs)
            checks.append(
                RegressionCheck(
                    title: "에너지원 감량",
                    passed: hasEnergyDecrease,
                    detail: hasEnergyDecrease
                        ? "고에너지 원료 감량이 포함되었습니다."
                        : "고에너지 원료 감량이 추천안에 보이지 않습니다."
                )
            )
        case "엔진검증 - CP 부족":
            let hasProteinIncrease = hasIncreaseAction(in: correctionActions, ingredientIDs: proteinSourceIDs)
            checks.append(
                RegressionCheck(
                    title: "단백질원 보강",
                    passed: hasProteinIncrease,
                    detail: hasProteinIncrease
                        ? "단백질원 보강 액션이 포함되었습니다."
                        : "단백질원 보강 액션이 추천안에 보이지 않습니다."
                )
            )
        case "엔진검증 - EE 과잉 + CP 부족":
            let hasFatDecrease = hasDecreaseAction(in: correctionActions, ingredientIDs: fatHeavySourceIDs)
            let hasProteinIncrease = hasIncreaseAction(in: correctionActions, ingredientIDs: proteinSourceIDs)
            checks.append(
                RegressionCheck(
                    title: "고지방 원료 감량",
                    passed: hasFatDecrease,
                    detail: hasFatDecrease
                        ? "고지방 원료 감량이 포함되었습니다."
                        : "고지방 원료 감량이 추천안에 보이지 않습니다."
                )
            )
            checks.append(
                RegressionCheck(
                    title: "단백질원 보강 연결",
                    passed: hasProteinIncrease,
                    detail: hasProteinIncrease
                        ? "감량 후 단백질 보강이 연결되었습니다."
                        : "감량 후 단백질 보강 액션이 부족합니다."
                )
            )
        case "경기TMR 3000kg 테스트 배합":
            let caPRatioImproved = projectedStatuses.first(where: { $0.nutrient == "Ca:P" })?.tone != .deficient
            checks.append(
                RegressionCheck(
                    title: "Ca:P 우선 개선",
                    passed: caPRatioImproved,
                    detail: caPRatioImproved
                        ? "적용 후 예상에서 Ca:P 상태가 개선되었습니다."
                        : "Ca:P 비율 개선이 충분하지 않습니다."
                )
            )
        default:
            break
        }

        return checks
    }

    private func severityScore(for statuses: [NutrientStatus]) -> Int {
        statuses.reduce(0) { partial, status in
            switch status.tone {
            case .adequate:
                partial
            case .caution:
                partial + 1
            case .deficient, .excess:
                partial + 2
            }
        }
    }

    private func hasDecreaseAction(in actions: [CorrectionAction], ingredientIDs: Set<String>) -> Bool {
        actions.contains { action in
            guard action.type == .decrease, let ingredientID = action.ingredientID else { return false }
            return ingredientIDs.contains(ingredientID)
        }
    }

    private func hasIncreaseAction(in actions: [CorrectionAction], ingredientIDs: Set<String>) -> Bool {
        actions.contains { action in
            guard action.type != .decrease, let ingredientID = action.ingredientID else { return false }
            return ingredientIDs.contains(ingredientID)
        }
    }
}
