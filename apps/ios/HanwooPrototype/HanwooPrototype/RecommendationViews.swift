import SwiftUI

// MARK: - 추천안 화면 (증감 시뮬레이션 결과)
// 핵심 출력은 두 가지다.
//   1) 이 원료들을 +kg / −kg 하라 (총량 유지)
//   2) 그렇게 하면 영양성분이 이렇게 적정 범위에 들어온다
// 조합은 증감 시뮬레이션(교정 엔진)이 찾고, 모든 수치는 계산 엔진이 산출·검증한다.

struct AIRecommendationView: View {
    @EnvironmentObject private var store: PrototypeStore
    let formulaID: UUID
    @State private var showsExplanation = false

    var body: some View {
        ScrollView {
            if let formula = store.formula(for: formulaID) {
                let analysis = store.analysis(for: formula)
                let primary = defaultRecommendation(from: analysis.recommendations)
                let reference = analysis.recommendations.first(where: { $0.isReferenceOnly })

                VStack(alignment: .leading, spacing: 16) {
                    header(formula: formula, analysis: analysis)

                    if let primary {
                        switch primary.strategy {
                        case .maintenance:
                            NoticeBanner(kind: .info, message: "현재 배합이 \(formula.stage.title) 기준을 만족합니다. 조정 없이 유지를 권장합니다.")
                            resultCard(
                                title: "현재 영양성분",
                                subtitle: "\(formula.stage.title) 기준",
                                before: analysis.metrics,
                                after: analysis.metrics,
                                stage: formula.stage,
                                showBefore: false
                            )

                        case .noSolution:
                            NoticeBanner(kind: .warning, message: primary.reason)
                            if let reference, !reference.correctionActions.isEmpty {
                                Text("가장 가까운 참고 교정안")
                                    .font(.headline)
                                adjustmentsCard(recommendation: reference, isReference: true, formula: formula)
                                resultCard(
                                    title: "참고안 적용 후 예상",
                                    subtitle: "완전 적정에는 도달하지 못합니다",
                                    before: analysis.metrics,
                                    after: reference.simulatedMetrics,
                                    stage: formula.stage
                                )
                            }

                        default:
                            if !primary.isFullyResolved {
                                NoticeBanner(kind: .warning, message: "완전 적정까지는 못 미칩니다. 남은 항목은 아래 결과에서 확인하세요.")
                            }
                            adjustmentsCard(recommendation: primary, isReference: primary.isReferenceOnly, formula: formula)
                            resultCard(
                                title: "적용 후 영양성분",
                                subtitle: "\(formula.stage.title) 기준, 조정 전 → 조정 후",
                                before: analysis.metrics,
                                after: primary.simulatedMetrics,
                                stage: formula.stage
                            )
                        }

                        explanationSection(primary: primary, analysis: analysis, stage: formula.stage)
                    }
                }
                .padding(20)
            }
        }
        .background(AppScreenBackground())
        .navigationTitle("추천안")
    }

    // MARK: 헤더

    private func header(formula: FeedFormula, analysis: AnalysisRun) -> some View {
        SectionCard(title: "증감 시뮬레이션 결과", subtitle: formula.name) {
            VStack(alignment: .leading, spacing: 8) {
                if formula.isTestFormula {
                    StatusPill(title: "테스트 배합", tone: .caution)
                }
                Text("배합 내 원료의 증감 시뮬레이션으로 찾은 교정 조합입니다. 모든 영양성분값은 계산 엔진이 산출·검증했습니다.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: 조정안 카드 — "이 원료들을 이렇게 +/− 하세요"

    private func adjustmentsCard(recommendation: Recommendation, isReference: Bool, formula: FeedFormula) -> some View {
        let decreases = recommendation.correctionActions.filter { $0.type == .decrease }
        let increases = recommendation.correctionActions.filter { $0.type != .decrease }

        return SectionCard(
            title: isReference ? "참고 조정안" : "이렇게 조정하세요",
            subtitle: "적용 후 총량 \(numberString(recommendation.simulatedMetrics.totalAsFedKg))kg 그대로 유지"
        ) {
            VStack(spacing: 10) {
                ForEach(increases) { action in
                    actionRow(action, isIncrease: true)
                }
                ForEach(decreases) { action in
                    actionRow(action, isIncrease: false)
                }

                Divider()
                costRow(recommendation: recommendation, formula: formula)

                // 증량 원료 중 사양학 사용수준 주의사항이 있는 것만 안내
                let notes = usageNotes(for: increases)
                if !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(notes, id: \.self) { note in
                            NoticeBanner(kind: .info, message: note)
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
    }

    // 농사로 한우 사용수준 원문 기반 안내. 엔진은 이 상한 안에서만 증감하지만,
    // 사용자가 배경을 알 수 있도록 문구로도 보여준다.
    private func usageNotes(for increases: [CorrectionAction]) -> [String] {
        var seen: Set<String> = []
        return increases.compactMap { action -> String? in
            guard let id = action.ingredientID,
                  let limit = IngredientUsageLimits.limit(for: id),
                  !seen.contains(limit.useLevel) else { return nil }
            seen.insert(limit.useLevel)
            return "\(limit.name): \(limit.useLevel)"
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
            HStack {
                Text("원료비 변동")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(deltaText)
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(delta > 0 ? AppPalette.warning : (delta < 0 ? AppPalette.primary : Color.secondary))
            }
        }
    }

    private func actionRow(_ action: CorrectionAction, isIncrease: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: isIncrease ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                .font(.title3)
                .foregroundStyle(isIncrease ? AppPalette.primary : AppPalette.warning)
            Text(action.ingredientName)
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text("\(isIncrease ? "+" : "−")\(numberString(action.amountKg))kg")
                .font(.headline.monospacedDigit())
                .foregroundStyle(isIncrease ? AppPalette.primary : AppPalette.warning)
        }
        .padding(.vertical, 2)
        .accessibilityLabel("\(action.ingredientName) \(isIncrease ? "증량" : "감량") \(numberString(action.amountKg))킬로그램")
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

    // MARK: 산출 근거 (접힘)

    private func explanationSection(primary: Recommendation, analysis: AnalysisRun, stage: FarmStage) -> some View {
        DisclosureGroup(isExpanded: $showsExplanation) {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(RecommendationExplanationBuilder.sections(
                    for: primary,
                    beforeMetrics: analysis.metrics,
                    beforeStatuses: analysis.statuses,
                    stage: stage
                )) { section in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(section.title)
                            .font(.subheadline.weight(.semibold))
                        Text(section.body)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.top, 12)
        } label: {
            Text("왜 이렇게 추천했나")
                .font(.headline)
                .foregroundStyle(AppPalette.ink)
        }
        .padding(16)
        .cardSurface()
    }
}
