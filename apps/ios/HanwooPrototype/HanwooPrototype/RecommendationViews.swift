import SwiftUI

// MARK: - 추천안 화면 (증감 시뮬레이션 결과)
// 핵심 출력은 두 가지다.
//   1) 이 원료들을 +kg / −kg 하라 (총량 유지)
//   2) 그렇게 하면 영양성분이 이렇게 적정 범위에 들어온다
// 조합은 증감 시뮬레이션(교정 엔진)이 찾고, 모든 수치는 계산 엔진이 산출·검증한다.

struct AIRecommendationView: View {
    @EnvironmentObject private var store: PrototypeStore
    let formulaID: UUID

    /// AI 설명 상태. 실패는 오류 화면이 아니라 내장 설명으로 조용히 되돌아간다.
    private enum AIState: Equatable {
        case idle
        case loading
        case loaded(String)
        case unavailable
    }
    @State private var aiState: AIState = .idle

    var body: some View {
        ScrollView {
            if let formula = store.formula(for: formulaID) {
                let analysis = store.analysis(for: formula)
                let primary = defaultRecommendation(from: analysis.recommendations)
                let reference = analysis.recommendations.first(where: { $0.isReferenceOnly })

                VStack(alignment: .leading, spacing: 26) {
                    header(formula: formula, analysis: analysis)

                    if let primary {
                        switch primary.strategy {
                        case .maintenance:
                            Text("현재 배합이 기준을 만족합니다. 조정 없이 유지를 권장합니다.")
                                .font(.footnote)
                                .foregroundStyle(AppPalette.subtle)
                            resultCard(
                                title: "현재 영양성분",
                                subtitle: "\(formula.stage.title) 기준",
                                before: analysis.metrics,
                                after: analysis.metrics,
                                stage: formula.stage,
                                showBefore: false
                            )

                        case .noSolution:
                            // 긴 안내문은 접어 둔다. 화면에 먼저 보여야 할 것은 조정 내역이다.
                            LimitationNote(text: primary.reason)
                            if let reference, !reference.correctionActions.isEmpty {
                                adjustmentsCard(recommendation: reference, isReference: true, formula: formula)
                                resultCard(
                                    title: "참고안 적용 후 예상",
                                    subtitle: "",
                                    before: analysis.metrics,
                                    after: reference.simulatedMetrics,
                                    stage: formula.stage
                                )
                            }

                        default:
                            if !primary.isFullyResolved {
                                LimitationNote(text: "완전 적정까지는 못 미칩니다. 남은 항목은 아래 결과에서 확인하세요.")
                            }
                            adjustmentsCard(recommendation: primary, isReference: primary.isReferenceOnly, formula: formula)
                            resultCard(
                                title: "적용 후 영양성분",
                                subtitle: "",
                                before: analysis.metrics,
                                after: primary.simulatedMetrics,
                                stage: formula.stage
                            )
                        }

                        // 화면에 조정 내역이 표시되는 추천안을 그대로 AI에게 보낸다.
                        // noSolution일 때 primary는 조정 내역이 비어 있고 실제 내역은 참고안에 있다.
                        let explained = (primary.strategy == .noSolution ? reference : nil) ?? primary
                        let limitation = primary.strategy == .noSolution ? primary.reason : nil

                        aiExplanationSection(primary: explained, analysis: analysis, formula: formula, limitation: limitation)
                            .task {
                                // 버튼을 누르게 하지 않는다. 설명은 부가 기능이 아니라 기본 출력이다.
                                guard aiState == .idle else { return }
                                await loadAIExplanation(primary: explained, analysis: analysis, formula: formula, limitation: limitation)
                            }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
        }
        .background(AppScreenBackground())
        .navigationTitle("추천안")
    }

    // MARK: 헤더

    private func header(formula: FeedFormula, analysis: AnalysisRun) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("이렇게 바꿔보세요")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(AppPalette.ink)
            Text("\(formula.name) · 배합 내 원료만 조정")
                .font(.footnote)
                .foregroundStyle(AppPalette.subtle)
        }
    }

    // MARK: 조정안 카드 — "이 원료들을 이렇게 +/− 하세요"

    private func adjustmentsCard(recommendation: Recommendation, isReference: Bool, formula: FeedFormula) -> some View {
        let decreases = recommendation.correctionActions.filter { $0.type == .decrease }
        let increases = recommendation.correctionActions.filter { $0.type != .decrease }

        return VStack(alignment: .leading, spacing: 0) {
            Text("총량 \(numberString(recommendation.simulatedMetrics.totalAsFedKg))kg 유지")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppPalette.subtle)
                .padding(.bottom, 12)

            HairlineDivider()
            ForEach(increases) { action in
                actionRow(action, isIncrease: true, formula: formula)
                HairlineDivider()
            }
            ForEach(decreases) { action in
                actionRow(action, isIncrease: false, formula: formula)
                HairlineDivider()
            }

            costRow(recommendation: recommendation, formula: formula)
                .padding(.top, 14)
        }
    }

    // 농사로 한우 사용수준 안내.
    // 상한 %를 이 배합의 실제 kg으로 환산해 "조정 후 ○kg — 최대 △kg 이내"로 보여준다.
    // 환산은 산수이므로 코드가 직접 계산한다(AI에 위임하지 않음). 상한은 목표가 아니라
    // '넘지 말 것'이므로 권고량이 아닌 범위 확인 문구로 표현한다.
    private func usageNotes(for increases: [CorrectionAction], formula: FeedFormula) -> [String] {
        let totalKg = formula.items.reduce(0.0) { $0 + asFedKg(for: $1) }
        let concentrateKg = formula.items.reduce(0.0) { partial, item in
            guard let defID = item.definitionID,
                  let definition = store.ingredientDefinition(id: defID),
                  definition.category == .concentrate || definition.category == .agriByproduct
            else { return partial }
            return partial + asFedKg(for: item)
        }

        var seen: Set<String> = []
        return increases.compactMap { action -> String? in
            guard let id = action.ingredientID,
                  let limit = IngredientUsageLimits.limit(for: id),
                  !seen.contains(limit.name) else { return nil }
            seen.insert(limit.name)

            let originalKg = formula.items
                .filter { $0.definitionID == id }
                .reduce(0.0) { $0 + asFedKg(for: $1) }
            let afterKg = originalKg + action.amountKg

            if let maxKg = IngredientUsageLimits.maxKg(
                for: id, stage: formula.stage, totalAsFedKg: totalKg, concentrateAsFedKg: concentrateKg
            ) {
                let basisLabel: String
                if let ratio = limit.ratioOfTotal(for: formula.stage) {
                    basisLabel = "총량의 \(numberString(ratio * 100))%"
                } else if let ratio = limit.ratioOfConcentrate {
                    basisLabel = "농후사료의 \(numberString(ratio * 100))%"
                } else {
                    basisLabel = "사용수준"
                }
                return "\(limit.name): 조정 후 \(numberString(afterKg))kg — \(formula.stage.title) 사용수준 상한(\(basisLabel) = 최대 \(numberString(maxKg))kg) 이내입니다. \(limit.useLevel(for: formula.stage))"
            }
            return "\(limit.name): \(limit.useLevel(for: formula.stage))"
        }
    }

    // 조정 적용 시 원료비 변화 (원료별 단가 × 증감 kg 합산, 단가 미입력 원료는 기본단가 기준)
    private func costRow(recommendation: Recommendation, formula: FeedFormula) -> some View {
        let delta = recommendation.costDeltaKrw
        let deltaText = delta == 0 ? "변동 없음" : (delta > 0 ? "+\(krwString(delta))" : "−\(krwString(abs(delta)))")

        return VStack(alignment: .leading, spacing: 4) {
            if let currentCost = store.totalCostKrw(for: formula) {
                let afterCost = currentCost + delta
                HStack {
                    Text("총 원료비")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(krwString(currentCost))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(krwString(afterCost))
                        .font(.subheadline.monospacedDigit().bold())
                        .foregroundStyle(delta > 0 ? AppPalette.warning : AppPalette.primary)
                }
            }
        }
    }

    // 증감량뿐 아니라 "기존 → 적용 후" 실제 투입량을 함께 보여준다.
    // 현장에서 저울에 올릴 최종 kg이 바로 보여야 실행 가능하다.
    private func actionRow(_ action: CorrectionAction, isIncrease: Bool, formula: FeedFormula) -> some View {
        let beforeKg = formula.items
            .filter { $0.definitionID != nil && $0.definitionID == action.ingredientID }
            .reduce(0.0) { $0 + asFedKg(for: $1) }
        let afterKg = isIncrease ? beforeKg + action.amountKg : max(0, beforeKg - action.amountKg)

        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(action.ingredientName)
                    .font(.system(size: 15))
                    .foregroundStyle(AppPalette.ink)
                Text("\(numberString(beforeKg))kg → \(numberString(afterKg))kg")
                    .font(.system(size: 12))
                    .monospacedDigit()
                    .foregroundStyle(AppPalette.subtle)
            }

            Spacer(minLength: 8)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(isIncrease ? "+" : "−")\(numberString(action.amountKg))")
                    .font(.system(size: 17, weight: .bold))
                    .monospacedDigit()
                Text("kg")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(isIncrease ? AppPalette.primary : AppPalette.alert)
        }
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(action.ingredientName) \(numberString(beforeKg))킬로그램에서 \(numberString(afterKg))킬로그램으로 \(isIncrease ? "증량" : "감량")")
    }

    // MARK: 결과 카드 — "그러면 이렇게 적정이 됩니다"

    private func resultCard(
        title: String,
        subtitle: String,
        before: AnalysisSummaryMetrics,
        after: AnalysisSummaryMetrics,
        stage: FarmStage,
        showBefore: Bool = true
    ) -> some View {
        let statuses = store.buildStatuses(stage: stage, criteria: stage.criteria, metrics: after)

        func tone(_ nutrient: String) -> StatusTone {
            statuses.first(where: { $0.nutrient == nutrient })?.tone ?? .caution
        }

        func row(_ label: String, _ beforeValue: Double, _ afterValue: Double, unit: String = "%") -> some View {
            Group {
                if showBefore {
                    ComparisonRow(
                        title: label,
                        current: numberString(beforeValue) + unit,
                        projected: numberString(afterValue) + unit,
                        projectedTone: tone(label)
                    )
                } else {
                    HStack {
                        Text(label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(numberString(afterValue) + unit)
                            .font(.caption.monospacedDigit().bold())
                        StatusPill(title: tone(label).title, tone: tone(label))
                    }
                }
            }
        }

        return SectionCard(title: title, subtitle: subtitle) {
            VStack(spacing: 8) {
                row("CP", before.cpPctDm, after.cpPctDm)
                row("TDN", before.tdnPctDm, after.tdnPctDm)
                row("EE", before.eePctDm, after.eePctDm)
                row("NDF", before.ndfPctDm, after.ndfPctDm)
                row("ADF", before.adfPctDm, after.adfPctDm)
                row("Ca", before.caPctDm, after.caPctDm)
                row("P", before.pPctDm, after.pPctDm)
                row("Ca:P", before.caPRatio, after.caPRatio, unit: "")
                row("수분", before.moisturePct, after.moisturePct)
            }
        }
    }

    // MARK: AI 설명
    //
    // 엔진이 확정한 판정·교정 결과를 서버에 보내 농가용 문장으로 받아온다.
    // 화면에 들어오면 자동으로 불러온다. 설명은 부가 기능이 아니라 기본 출력이다.

    private func aiExplanationSection(
        primary: Recommendation,
        analysis: AnalysisRun,
        formula: FeedFormula,
        limitation: String?
    ) -> some View {
        SectionCard(title: "설명", subtitle: "") {
            VStack(alignment: .leading, spacing: 12) {
                switch aiState {
                case .idle, .loading:
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("설명을 만드는 중…")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                case .loaded(let text):
                    Text(text)
                        .font(.footnote)
                        .foregroundStyle(AppPalette.ink)
                        .fixedSize(horizontal: false, vertical: true)

                case .unavailable:
                    NoticeBanner(
                        kind: .info,
                        message: "설명을 불러오지 못했습니다."
                    )
                    Button("다시 시도") {
                        Task { await loadAIExplanation(primary: primary, analysis: analysis, formula: formula, limitation: limitation) }
                    }
                    .font(.footnote)
                }
            }
        }
    }

    private func loadAIExplanation(
        primary: Recommendation,
        analysis: AnalysisRun,
        formula: FeedFormula,
        limitation: String?
    ) async {
        aiState = .loading
        let request = AIExplanationRequest(
            recommendation: primary,
            analysis: analysis,
            formula: formula,
            asFedKg: { asFedKg(for: $0) },
            // 화면의 "적용 후 예상"과 같은 판정을 보낸다.
            afterStatuses: store.buildStatuses(
                stage: formula.stage,
                criteria: formula.stage.criteria,
                metrics: primary.simulatedMetrics
            ),
            limitationOverride: limitation
        )
        do {
            let response = try await AIExplanationService().explain(request)
            aiState = .loaded(response.text)
        } catch {
            aiState = .unavailable
        }
    }

}

// MARK: - 한계 안내
//
// 왜 완전 적정이 안 되는지는 중요하지만, 화면 맨 위를 긴 문단이 차지하면
// 정작 봐야 할 조정 내역이 밀린다. 한 줄로 접어 두고 필요할 때 펼친다.

struct LimitationNote: View {
    let text: String
    @State private var isExpanded = false

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) { isExpanded.toggle() }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text("완전 적정안을 만들지 못했습니다")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppPalette.alert)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(AppPalette.subtle)
                    Spacer()
                }
                if isExpanded {
                    Text(text)
                        .font(.system(size: 13))
                        .foregroundStyle(AppPalette.subtle)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
