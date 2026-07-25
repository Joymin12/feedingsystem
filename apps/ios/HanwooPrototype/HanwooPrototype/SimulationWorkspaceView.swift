import SwiftUI

// MARK: - 증감 시뮬레이션 워크스페이스
// 원료 투입량을 직접 조정하며 영양값 변화를 실시간으로 확인하고,
// 원료 잠금 상태를 반영한 엔진 자동 최적화를 실행할 수 있다.
// 이 화면의 조정은 "실제 배합에 반영"을 누르기 전까지 저장되지 않는다.

struct SimulationWorkspaceView: View {
    @EnvironmentObject private var store: PrototypeStore
    @Environment(\.dismiss) private var dismiss

    let baseFormula: FeedFormula

    @State private var working: FeedFormula
    @State private var lockedIDs: Set<String> = []
    @State private var optimizeSummary: String?
    @State private var showApplyConfirm = false
    @State private var showResetConfirm = false
    @State private var isOptimizing = false

    init(formula: FeedFormula) {
        self.baseFormula = formula
        var kgFormula = formula
        for index in kgFormula.items.indices {
            kgFormula.items[index].amount = asFedKg(for: kgFormula.items[index])
            kgFormula.items[index].unit = .kg
        }
        _working = State(initialValue: kgFormula)
    }

    private var baseMetrics: AnalysisSummaryMetrics {
        store.calculateMetrics(for: baseFormula).metrics
    }

    private var metrics: AnalysisSummaryMetrics {
        store.calculateMetrics(for: working).metrics
    }

    private var statuses: [NutrientStatus] {
        store.buildStatuses(stage: working.stage, criteria: working.stage.criteria, metrics: metrics)
    }

    var body: some View {
        ZStack {
            AppScreenBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    NoticeBanner(kind: .info, message: "여기서의 조정은 '실제 배합에 반영'을 누르기 전까지 저장되지 않습니다. 모든 값은 조정 즉시 다시 계산됩니다.")

                    totalsCard
                    statusCard
                    ingredientsCard
                    optimizeCard
                    actionButtons
                }
                .padding(20)
            }
        }
        .navigationTitle("증감 시뮬레이션")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("시뮬레이션 값을 실제 배합에 반영할까요?", isPresented: $showApplyConfirm, titleVisibility: .visible) {
            Button("반영", role: .destructive) {
                store.updateFormula(working)
                dismiss()
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("'\(baseFormula.name)' 배합의 원료 투입량이 시뮬레이션 값으로 바뀝니다.")
        }
        .confirmationDialog("조정을 처음 상태로 되돌릴까요?", isPresented: $showResetConfirm, titleVisibility: .visible) {
            Button("초기화", role: .destructive) { reset() }
            Button("취소", role: .cancel) {}
        }
    }

    // MARK: 카드들

    private var totalsCard: some View {
        SectionCard(title: "총량", subtitle: "원물 기준 실시간 합계") {
            HStack(spacing: 12) {
                MetricTile(
                    title: "총 원물",
                    value: "\(numberString(metrics.totalAsFedKg))kg",
                    accent: AppPalette.ink
                )
                MetricTile(
                    title: "총 건물",
                    value: "\(numberString(metrics.totalDmKg))kg",
                    accent: AppPalette.ink
                )
                if let cost = store.totalCostKrw(for: working) {
                    MetricTile(title: "원료비", value: krwString(cost), accent: AppPalette.primary)
                }
            }
            if abs(metrics.totalAsFedKg - baseMetrics.totalAsFedKg) > 0.05 {
                Text("처음 총량 \(numberString(baseMetrics.totalAsFedKg))kg 대비 \(numberString(metrics.totalAsFedKg - baseMetrics.totalAsFedKg))kg 변동")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statusCard: some View {
        SectionCard(title: "판정", subtitle: "\(working.stage.title) 기준, 조정 전 → 조정 후") {
            VStack(spacing: 8) {
                comparisonRow("CP", baseMetrics.cpPctDm, metrics.cpPctDm, "%")
                comparisonRow("TDN", baseMetrics.tdnPctDm, metrics.tdnPctDm, "%")
                comparisonRow("EE", baseMetrics.eePctDm, metrics.eePctDm, "%")
                comparisonRow("NDF", baseMetrics.ndfPctDm, metrics.ndfPctDm, "%")
                comparisonRow("ADF", baseMetrics.adfPctDm, metrics.adfPctDm, "%")
                comparisonRow("Ca", baseMetrics.caPctDm, metrics.caPctDm, "%")
                comparisonRow("P", baseMetrics.pPctDm, metrics.pPctDm, "%")
                comparisonRow("Ca:P", baseMetrics.caPRatio, metrics.caPRatio, "")
                comparisonRow("수분", baseMetrics.moisturePct, metrics.moisturePct, "%")
            }
        }
    }

    private func comparisonRow(_ label: String, _ before: Double, _ after: Double, _ unit: String) -> some View {
        let tone = statuses.first(where: { $0.nutrient == label })?.tone ?? .caution
        return ComparisonRow(
            title: label,
            current: numberString(before) + unit,
            projected: numberString(after) + unit,
            projectedTone: tone
        )
    }

    private var ingredientsCard: some View {
        SectionCard(title: "원료 조정", subtitle: "슬라이더로 조정하고, 자물쇠로 엔진 조정을 막을 수 있습니다") {
            VStack(spacing: 14) {
                ForEach(working.items.indices, id: \.self) { index in
                    ingredientRow(index: index)
                    if index < working.items.count - 1 {
                        Divider()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func ingredientRow(index: Int) -> some View {
        let item = working.items[index]
        let originalKg = asFedKg(for: baseFormula.items.first(where: { $0.id == item.id }) ?? item)
        let definitionID = item.definitionID
        let isLocked = definitionID.map { lockedIDs.contains($0) } ?? false
        let hasNutrition = definitionID.flatMap { store.ingredientDefinition(id: $0) } != nil

        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.name)
                    .font(.subheadline.weight(.semibold))
                if !hasNutrition {
                    Text("성분 미등록")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color(.systemGray5)))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(numberString(originalKg)) → \(numberString(item.amount))kg")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(abs(item.amount - originalKg) > 0.05 ? AppPalette.primary : .secondary)
                if let definitionID, hasNutrition {
                    Button {
                        if lockedIDs.contains(definitionID) {
                            lockedIDs.remove(definitionID)
                        } else {
                            lockedIDs.insert(definitionID)
                        }
                    } label: {
                        Image(systemName: isLocked ? "lock.fill" : "lock.open")
                            .foregroundStyle(isLocked ? AppPalette.warning : .secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isLocked ? "\(item.name) 잠금 해제" : "\(item.name) 잠금")
                }
            }

            Slider(
                value: Binding(
                    get: { working.items[index].amount },
                    set: { working.items[index].amount = (max(0, $0) * 10).rounded() / 10 }
                ),
                in: 0...max(originalKg * 3, originalKg + 20, 10)
            )
            .disabled(isLocked)

            if !hasNutrition {
                Text("총량과 수분에만 반영됩니다. 엔진 최적화는 이 원료를 조정하지 않습니다.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var optimizeCard: some View {
        SectionCard(title: "엔진 최적화", subtitle: "잠근 원료를 제외하고, 현재 조정 상태에서 기준에 가장 가까운 조합을 찾습니다") {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    runOptimization()
                } label: {
                    HStack {
                        if isOptimizing {
                            ProgressView()
                                .padding(.trailing, 4)
                        }
                        Text(isOptimizing ? "시뮬레이션 계산 중…" : "최적 조합 찾기")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isOptimizing)

                if let optimizeSummary {
                    NoticeBanner(kind: .info, message: optimizeSummary)
                }
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button("실제 배합에 반영") { showApplyConfirm = true }
                .buttonStyle(PrimaryButtonStyle())
            Button("처음 상태로 초기화") { showResetConfirm = true }
                .buttonStyle(SecondaryButtonStyle())
        }
    }

    // MARK: 동작

    private func reset() {
        var kgFormula = baseFormula
        for index in kgFormula.items.indices {
            kgFormula.items[index].amount = asFedKg(for: kgFormula.items[index])
            kgFormula.items[index].unit = .kg
        }
        working = kgFormula
        optimizeSummary = nil
    }

    private func runOptimization() {
        isOptimizing = true
        optimizeSummary = nil
        // 다음 런루프에서 실행해 버튼 상태가 먼저 그려지게 한다. 엔진은 결정론적 동기 계산이다.
        Task { @MainActor in
            defer { isOptimizing = false }
            let currentMetrics = store.calculateMetrics(for: working).metrics
            let constraints = SimulationConstraints(lockedIngredientIDs: lockedIDs)
            let recommendations = store.buildRecommendations(
                formula: working,
                stage: working.stage,
                metrics: currentMetrics,
                constraints: constraints
            )
            guard let plan = recommendations.first(where: { !$0.correctionActions.isEmpty })
                ?? recommendations.first else {
                optimizeSummary = "추천을 생성하지 못했습니다."
                return
            }

            if plan.correctionActions.isEmpty {
                optimizeSummary = plan.reason
                return
            }
            guard let applied = store.simulateApplying(actions: plan.correctionActions, to: working) else {
                optimizeSummary = "조합 적용에 실패했습니다."
                return
            }
            working = applied.formula
            let stateText = plan.isFullyResolved
                ? "모든 항목이 적정 범위에 들어오는 조합을 적용했습니다."
                : "완전 적정 조합은 없어 가장 가까운 참고 조합을 적용했습니다. \(plan.reason)"
            optimizeSummary = stateText + " 총량은 \(numberString(applied.metrics.totalAsFedKg))kg으로 유지됩니다."
        }
    }
}
