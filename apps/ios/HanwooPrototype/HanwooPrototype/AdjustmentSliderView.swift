import SwiftUI

// MARK: - 직접 증감해보기
//
// 엔진이 찾아주는 교정안과는 별개로, 농가가 직접 원료를 밀고 당기면서
// 영양소가 어떻게 변하는지 그 자리에서 보는 화면이다.
//
// 목적이 다르다. 교정안은 "이렇게 하세요"이고, 이 화면은 "이렇게 하면 어떻게 되나요"다.
// 그래서 여기서는 정답을 제시하지 않고 결과만 보여준다.
//
// 계산은 화면이 하지 않는다. 슬라이더 값으로 배합을 만들어 계산 엔진에 넘기고,
// 판정도 분석 화면과 같은 함수를 쓴다. 그래야 이 화면 숫자와 분석 화면 숫자가 어긋나지 않는다.

struct AdjustmentSliderView: View {
    @EnvironmentObject private var store: PrototypeStore
    let formulaID: UUID

    /// 원료 라인별 조정된 투입량(kg). 키는 items 인덱스.
    @State private var amounts: [Int: Double] = [:]
    @State private var didInitialize = false
    @State private var didSave = false


    var body: some View {
        ScrollView {
            if let formula = store.formula(for: formulaID) {
                let working = workingFormula(from: formula)
                let calculation = store.calculateMetrics(for: working)
                let statuses = store.buildStatuses(
                    stage: formula.stage,
                    criteria: formula.stage.criteria,
                    metrics: calculation.metrics
                )
                let baseMetrics = store.calculateMetrics(for: normalized(formula)).metrics

                VStack(alignment: .leading, spacing: 16) {
                    header(formula: formula, working: working)
                    slidersCard(formula: formula)
                    changesCard(before: baseMetrics, after: calculation.metrics, statuses: statuses)
                    saveButton(formula: formula)
                    resetButton(formula: formula)
                }
                .padding(20)
                .onAppear {
                    guard !didInitialize else { return }
                    amounts = initialAmounts(from: formula)
                    didInitialize = true
                }
            }
        }
        // 슬라이더를 미는 동안에도 값이 보여야 한다.
        // 원료가 화면 아래에 있으면 결과를 보려고 매번 위로 스크롤해야 하므로
        // 요약 줄을 화면 위쪽에 고정해 둔다.
        .safeAreaInset(edge: .top) {
            if let formula = store.formula(for: formulaID) {
                let metrics = store.calculateMetrics(for: workingFormula(from: formula)).metrics
                let statuses = store.buildStatuses(
                    stage: formula.stage,
                    criteria: formula.stage.criteria,
                    metrics: metrics
                )
                stickyNutrientBar(statuses: statuses, metrics: metrics)
            }
        }
        .background(AppScreenBackground())
        .navigationTitle("직접 증감해보기")
    }

    // MARK: 상단 고정 요약

    private func stickyNutrientBar(statuses: [NutrientStatus], metrics: AnalysisSummaryMetrics) -> some View {
        let items: [(String, Double, String)] = [
            ("CP", metrics.cpPctDm, "%"),
            ("TDN", metrics.tdnPctDm, "%"),
            ("EE", metrics.eePctDm, "%"),
            ("NDF", metrics.ndfPctDm, "%"),
            ("ADF", metrics.adfPctDm, "%"),
            ("Ca", metrics.caPctDm, "%"),
            ("P", metrics.pPctDm, "%"),
            ("Ca:P", metrics.caPRatio, ""),
            ("수분", metrics.moisturePct, "%"),
        ]

        func tone(_ nutrient: String) -> StatusTone {
            statuses.first(where: { $0.nutrient == nutrient })?.tone ?? .caution
        }

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items, id: \.0) { name, value, unit in
                    let t = tone(name)
                    VStack(spacing: 2) {
                        Text(name)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(numberString(value))\(unit)")
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .foregroundStyle(t.color)
                    }
                    .frame(minWidth: 54)
                    .padding(.vertical, 7)
                    .padding(.horizontal, 8)
                    .background(t.color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
        .background(.regularMaterial)
    }

    // MARK: 헤더

    private func header(formula: FeedFormula, working: FeedFormula) -> some View {
        let totalKg = working.items.reduce(0.0) { $0 + asFedKg(for: $1) }
        let originalKg = formula.items.reduce(0.0) { $0 + asFedKg(for: $1) }
        let deltaKg = totalKg - originalKg

        return HStack(alignment: .firstTextBaseline) {
            DisplayStat(
                value: numberString(totalKg),
                suffix: "kg",
                caption: "총 원물량"
            )
            Spacer()
            if abs(deltaKg) >= 0.05 {
                Text("\(deltaKg > 0 ? "+" : "−")\(numberString(abs(deltaKg)))kg")
                    .font(.system(size: 17, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(deltaKg > 0 ? AppPalette.primary : AppPalette.alert)
            }
        }
    }

    // MARK: 조정 전 → 후

    private func changesCard(
        before: AnalysisSummaryMetrics,
        after: AnalysisSummaryMetrics,
        statuses: [NutrientStatus]
    ) -> some View {
        func tone(_ nutrient: String) -> StatusTone {
            statuses.first(where: { $0.nutrient == nutrient })?.tone ?? .caution
        }

        func row(_ label: String, _ beforeValue: Double, _ afterValue: Double, unit: String = "%") -> some View {
            let changed = abs(afterValue - beforeValue) >= 0.05
            return HStack(spacing: 8) {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 52, alignment: .leading)

                Spacer()

                Text("\(numberString(beforeValue))\(unit)")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.tertiary)

                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Text("\(numberString(afterValue))\(unit)")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(changed ? AppPalette.ink : Color.secondary)
                    .frame(width: 62, alignment: .trailing)

                StatusPill(title: tone(label).title, tone: tone(label))
                    .frame(width: 74, alignment: .trailing)
            }
            .padding(.vertical, 1)
        }

        return SectionCard(title: "영양소 변화", subtitle: "") {
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

    // MARK: 슬라이더

    private func slidersCard(formula: FeedFormula) -> some View {
        SectionCard(title: "원료별 투입량", subtitle: "") {
            VStack(spacing: 18) {
                ForEach(adjustableIndices(of: formula), id: \.self) { index in
                    sliderRow(formula: formula, index: index)
                }
            }
        }
    }

    private func sliderRow(formula: FeedFormula, index: Int) -> some View {
        let item = formula.items[index]
        let original = asFedKg(for: item)
        let current = amounts[index] ?? original
        let upper = sliderUpperBound(formula: formula, index: index, original: original)
        let delta = current - original
        let limitKg = usageLimitKg(formula: formula, index: index)
        let exceeds = limitKg.map { current > $0 + 0.05 } ?? false

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppPalette.ink)
                Spacer()
                Text("\(numberString(current))kg")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(AppPalette.ink)
                if abs(delta) >= 0.05 {
                    Text("\(delta > 0 ? "+" : "−")\(numberString(abs(delta)))kg")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(delta > 0 ? AppPalette.primary : AppPalette.warning)
                }
            }

            Slider(
                value: Binding(
                    get: { amounts[index] ?? original },
                    set: {
                        amounts[index] = (($0 * 10).rounded()) / 10
                        didSave = false
                    }
                ),
                in: 0...max(upper, 0.1)
            )
            .tint(exceeds ? AppPalette.warning : AppPalette.primary)

            HStack {
                Text("기존 \(numberString(original))kg")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                if let limitKg {
                    Text(exceeds
                         ? "사용수준 상한 \(numberString(limitKg))kg 초과"
                         : "사용수준 상한 \(numberString(limitKg))kg")
                        .font(.caption2)
                        .foregroundStyle(exceeds ? AnyShapeStyle(AppPalette.warning) : AnyShapeStyle(.tertiary))
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.name) \(numberString(current))킬로그램")
    }

    /// 조정한 값을 실제 배합에 반영한다.
    /// 실험만 하고 끝나는 경우가 많아 기본은 저장하지 않지만,
    /// 마음에 드는 조합을 찾았을 때 다시 입력하게 만들 이유는 없다.
    private func saveButton(formula: FeedFormula) -> some View {
        Button {
            var updated = normalized(formula)
            for (index, value) in amounts where updated.items.indices.contains(index) {
                updated.items[index].amount = value
            }
            store.updateFormula(updated)
            didSave = true
        } label: {
            Text(didSave ? "저장됨" : "이 값으로 배합 저장")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(didSave)
    }

    private func resetButton(formula: FeedFormula) -> some View {
        Button {
            amounts = initialAmounts(from: formula)
        } label: {
            Text("되돌리기")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(AppPalette.primary)
    }

    // MARK: 계산 보조

    /// 성분표가 있는 원료만 조정 대상. 물처럼 성분이 없는 라인은 슬라이더를 만들지 않는다.
    private func adjustableIndices(of formula: FeedFormula) -> [Int] {
        formula.items.indices.filter { index in
            guard let defID = formula.items[index].definitionID else { return false }
            return store.ingredientDefinition(id: defID) != nil
        }
    }

    private func initialAmounts(from formula: FeedFormula) -> [Int: Double] {
        Dictionary(uniqueKeysWithValues: formula.items.indices.map { ($0, asFedKg(for: formula.items[$0])) })
    }

    /// 모든 라인을 kg 단위로 통일한 배합. 슬라이더 값과 단위를 맞추기 위한 기준.
    private func normalized(_ formula: FeedFormula) -> FeedFormula {
        var copy = formula
        for index in copy.items.indices {
            copy.items[index].amount = asFedKg(for: copy.items[index])
            copy.items[index].unit = .kg
        }
        return copy
    }

    /// 슬라이더 값이 반영된 배합. 이걸 계산 엔진에 넘긴다.
    private func workingFormula(from formula: FeedFormula) -> FeedFormula {
        var copy = normalized(formula)
        for (index, value) in amounts where copy.items.indices.contains(index) {
            copy.items[index].amount = value
        }
        return copy
    }

    /// 슬라이더 최대값. 기존량의 2배와 사용수준 상한 중 큰 쪽을 쓰되 최소 폭은 확보한다.
    private func sliderUpperBound(formula: FeedFormula, index: Int, original: Double) -> Double {
        let byOriginal = max(original * 2, original + 5)
        guard let limit = usageLimitKg(formula: formula, index: index) else { return byOriginal }
        return max(byOriginal, limit * 1.2)
    }

    /// 이 원료의 사용수준 상한을 kg으로 환산. 총량 기준이라 현재 총량으로 계산한다.
    private func usageLimitKg(formula: FeedFormula, index: Int) -> Double? {
        guard let defID = formula.items[index].definitionID else { return nil }
        let working = workingFormula(from: formula)
        let totalKg = working.items.reduce(0.0) { $0 + asFedKg(for: $1) }
        let concentrateKg = working.items.reduce(0.0) { partial, item in
            guard let id = item.definitionID,
                  let definition = store.ingredientDefinition(id: id),
                  definition.category == .concentrate || definition.category == .agriByproduct
            else { return partial }
            return partial + asFedKg(for: item)
        }
        return IngredientUsageLimits.maxKg(
            for: defID,
            stage: formula.stage,
            totalAsFedKg: totalKg,
            concentrateAsFedKg: concentrateKg
        )
    }
}
