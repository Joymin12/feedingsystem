import Foundation

// MARK: - 추천 설명 엔진
// 엔진 산출물(Recommendation)을 사용자 친화적인 5단 구조로 변환한다.
// 원칙: 수치를 새로 만들지 않는다. 전부 계산 엔진이 산출한 값을 인용만 한다.
// 이 구조는 향후 서버 LLM 설명 계층의 입력 계약(JSON)과 동일한 형태를 유지한다.
// (IMPLEMENTATION_PLAN.md "AI의 의미와 향후 도입 계획" 참고)

struct ExplanationSection: Identifiable {
    let id = UUID()
    var title: String
    var body: String
}

@MainActor
enum RecommendationExplanationBuilder {

    static func sections(
        for recommendation: Recommendation,
        beforeMetrics: AnalysisSummaryMetrics,
        beforeStatuses: [NutrientStatus],
        stage: FarmStage
    ) -> [ExplanationSection] {
        var sections: [ExplanationSection] = []

        // 1. 핵심 문제
        let issues = beforeStatuses.filter { $0.tone != .adequate }
        if issues.isEmpty {
            sections.append(ExplanationSection(
                title: "현재 상태",
                body: "\(stage.title) 기준의 모든 항목이 적정 범위에 있습니다."
            ))
        } else {
            let lines = issues.map { "\($0.nutrient) \($0.currentValue) — \($0.tone.title) (기준 \($0.targetValue))" }
            sections.append(ExplanationSection(
                title: "무엇이 문제인가",
                body: lines.joined(separator: "\n")
            ))
        }

        // 2. 조정 내용
        let decreases = recommendation.correctionActions.filter { $0.type == .decrease }
        let increases = recommendation.correctionActions.filter { $0.type != .decrease }
        if !recommendation.correctionActions.isEmpty {
            var body = ""
            if !decreases.isEmpty {
                body += "줄이기: " + decreases.map { "\($0.ingredientName) −\(numberString($0.amountKg))kg" }.joined(separator: ", ")
            }
            if !increases.isEmpty {
                if !body.isEmpty { body += "\n" }
                body += "늘리기: " + increases.map { "\($0.ingredientName) +\(numberString($0.amountKg))kg" }.joined(separator: ", ")
            }
            body += "\n적용 후 총량은 입력한 총 \(numberString(beforeMetrics.totalAsFedKg))kg 그대로 유지됩니다."
            sections.append(ExplanationSection(title: "어떻게 조정하나", body: body))
        }

        // 3. 교차 영향 (전→후 변화가 있는 축만)
        let after = recommendation.simulatedMetrics
        if !recommendation.correctionActions.isEmpty {
            var changes: [String] = []
            func note(_ label: String, _ before: Double, _ current: Double, unit: String = "%") {
                guard abs(before - current) >= 0.1 else { return }
                changes.append("\(label) \(numberString(before))\(unit) → \(numberString(current))\(unit)")
            }
            note("CP", beforeMetrics.cpPctDm, after.cpPctDm)
            note("TDN", beforeMetrics.tdnPctDm, after.tdnPctDm)
            note("EE", beforeMetrics.eePctDm, after.eePctDm)
            note("NDF", beforeMetrics.ndfPctDm, after.ndfPctDm)
            note("ADF", beforeMetrics.adfPctDm, after.adfPctDm)
            note("Ca", beforeMetrics.caPctDm, after.caPctDm)
            note("P", beforeMetrics.pPctDm, after.pPctDm)
            note("Ca:P", beforeMetrics.caPRatio, after.caPRatio, unit: "")
            note("수분", beforeMetrics.moisturePct, after.moisturePct)
            if !changes.isEmpty {
                sections.append(ExplanationSection(
                    title: "적용 후 예상 변화",
                    body: changes.joined(separator: "\n") + "\n한 원료를 조정하면 여러 영양소가 함께 움직이므로, 위 값은 전체 조정을 한꺼번에 적용한 결과입니다."
                ))
            }
        }

        // 4. 남은 한계
        if !recommendation.isFullyResolved {
            let body = recommendation.cons.isEmpty
                ? recommendation.reason
                : recommendation.cons.joined(separator: "\n")
            sections.append(ExplanationSection(title: "남은 한계", body: body))
        }

        // 5. 계산 방식
        sections.append(ExplanationSection(
            title: "이 추천이 만들어진 방식",
            body: "앱의 최적화 엔진이 배합에 이미 들어 있는 원료만 증감하며 수천 가지 조합을 시뮬레이션했고, 모든 수치는 앱 계산 엔진이 산출했습니다. 같은 입력에는 항상 같은 결과가 나옵니다. (엔진 버전 \(recommendation.algorithmVersion))\n이 결과는 의사결정 보조 정보입니다. 실제 급여 변경 전에 사양 전문가와 상의하세요."
        ))

        return sections
    }
}
