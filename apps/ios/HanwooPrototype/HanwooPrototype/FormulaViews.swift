import SwiftUI

// MARK: - 배합 편집 화면

struct BlendView: View {
    @EnvironmentObject private var store: PrototypeStore
    @State private var isShowingIngredientSheet = false

    private func binding(for id: UUID) -> Binding<FeedFormula>? {
        guard let index = store.formulas.firstIndex(where: { $0.id == id }) else { return nil }
        return $store.formulas[index]
    }

    /// 편집 중인 원료. 줄을 탭하면 펼쳐진다.
    @State private var expandedItemID: UUID?

    var body: some View {
        ScrollView {
            let currentID = store.preferredSelectedFormulaID()
            if let formula = binding(for: currentID) {
                let liveTotalKg = formula.wrappedValue.items.reduce(0.0) { $0 + asFedKg(for: $1) }

                VStack(alignment: .leading, spacing: 0) {
                    // 제목 — 배합 이름을 그대로 큰 글자로 쓴다.
                    TextField("배합 이름", text: formula.name)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(AppPalette.ink)

                    Text(formula.wrappedValue.stage.title + " 기준")
                        .font(.footnote)
                        .foregroundStyle(AppPalette.subtle)
                        .padding(.top, 6)

                    // 단계 선택
                    Picker("성장 단계", selection: formula.stage) {
                        ForEach(FarmStage.allCases) { stage in
                            Text(stage.title).tag(stage)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.top, 18)

                    // 핵심 수치 두 개 — 화면에서 가장 큰 글자
                    HStack(alignment: .firstTextBaseline) {
                        DisplayStat(
                            value: numberString(liveTotalKg),
                            suffix: "kg",
                            caption: "총 원물량"
                        )
                        Spacer()
                        if let totalCost = store.totalCostKrw(for: formula.wrappedValue) {
                            VStack(alignment: .trailing, spacing: 6) {
                                Text(krwString(totalCost))
                                    .font(.system(size: 22, weight: .semibold))
                                    .monospacedDigit()
                                    .foregroundStyle(AppPalette.ink)
                                Text("총 원료비")
                                    .font(.footnote)
                                    .foregroundStyle(AppPalette.subtle)
                            }
                        }
                    }
                    .padding(.top, 26)

                    if liveTotalKg <= 0 {
                        Text("투입량이 0입니다. 원료별 투입량을 입력해야 분석할 수 있습니다.")
                            .font(.footnote)
                            .foregroundStyle(AppPalette.alert)
                            .padding(.top, 10)
                    }

                    // 원료 목록 — 한 줄에 하나. 탭하면 펼쳐서 편집한다.
                    Text("원료 \(formula.wrappedValue.items.count)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppPalette.subtle)
                        .padding(.top, 30)
                        .padding(.bottom, 12)

                    HairlineDivider()

                    ForEach(formula.items) { item in
                        FormulaIngredientRow(
                            item: item,
                            isExpanded: expandedItemID == item.wrappedValue.id,
                            defaultPricePerKg: item.wrappedValue.definitionID.flatMap {
                                store.ingredientDefinition(id: $0)?.defaultPriceKrwPerKg
                            },
                            onToggle: {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    expandedItemID = expandedItemID == item.wrappedValue.id ? nil : item.wrappedValue.id
                                }
                            },
                            onRemove: {
                                store.removeIngredient(from: currentID, ingredientID: item.wrappedValue.id)
                            }
                        )
                        HairlineDivider()
                    }

                    Button {
                        isShowingIngredientSheet = true
                    } label: {
                        Text("+ 원료 추가")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppPalette.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 16)
                    }

                    NavigationLink {
                        AnalysisDetailView(formulaID: formula.wrappedValue.id)
                    } label: {
                        Text("분석 결과 보기")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, 20)
                }
                .padding(.horizontal, 22)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
        }
        .background(AppScreenBackground())
        .navigationTitle("배합")
        .sheet(isPresented: $isShowingIngredientSheet) {
            let formulaID = store.preferredSelectedFormulaID()
            IngredientPickerSheet(formulaID: formulaID)
                .environmentObject(store)
        }
    }
}

// MARK: - 원료 한 줄
//
// 접혀 있을 때는 이름, 투입량, 금액만 보여준다. 원료 하나가 화면 3분의 1을 차지하면
// 배합 전체를 한눈에 볼 수 없기 때문이다.
// 탭하면 그 줄만 펼쳐져 단위, 단가, 삭제가 나온다.

struct FormulaIngredientRow: View {
    @Binding var item: IngredientLine
    let isExpanded: Bool
    let defaultPricePerKg: Int?
    let onToggle: () -> Void
    let onRemove: () -> Void

    @State private var priceDraft: String = ""

    private var effectivePricePerKg: Int? {
        item.priceOverrideKrwPerKg ?? defaultPricePerKg
    }

    private var subtotalKrw: Int? {
        guard let price = effectivePricePerKg else { return nil }
        return Int((asFedKg(for: item) * Double(price)).rounded())
    }

    private var amountText: Binding<String> {
        Binding(
            get: { numberString(item.amount) },
            set: { newValue in
                let filtered = filteredDecimal(newValue)
                if filtered.isEmpty { item.amount = 0 }
                else if let value = Double(filtered) { item.amount = value }
            }
        )
    }

    // 입력 중인 글자는 화면이 들고 있는다. 저장값에서 매번 다시 만들면
    // 다 지우는 순간 기본단가가 되살아나 새 단가를 넣을 수 없다.
    private var priceText: Binding<String> {
        Binding(
            get: { priceDraft },
            set: { newValue in
                let filtered = newValue.filter { $0.isNumber }
                priceDraft = filtered
                item.priceOverrideKrwPerKg = filtered.isEmpty ? nil : Int(filtered)
            }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggle) {
                HStack(spacing: 10) {
                    Text(item.name)
                        .font(.system(size: 15))
                        .foregroundStyle(AppPalette.ink)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    TextField("0", text: amountText)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 19, weight: .semibold))
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(AppPalette.ink)
                        .frame(width: 58)

                    Text(item.unit.rawValue)
                        .font(.system(size: 13))
                        .foregroundStyle(AppPalette.subtle)
                        .frame(width: 20, alignment: .leading)

                    Text(subtotalKrw.map { krwString($0) } ?? "—")
                        .font(.system(size: 13))
                        .monospacedDigit()
                        .foregroundStyle(AppPalette.subtle)
                        .frame(width: 72, alignment: .trailing)
                }
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                HStack(spacing: 14) {
                    Picker("단위", selection: $item.unit) {
                        ForEach(WeightUnit.allCases) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 96)

                    HStack(spacing: 4) {
                        Text("kg당")
                            .font(.system(size: 13))
                            .foregroundStyle(AppPalette.subtle)
                        TextField("0", text: priceText)
                            .keyboardType(.numberPad)
                            .font(.system(size: 15))
                            .monospacedDigit()
                            .frame(width: 62)
                        Text("원")
                            .font(.system(size: 13))
                            .foregroundStyle(AppPalette.subtle)
                    }

                    Spacer()

                    Button(action: onRemove) {
                        Image(systemName: "trash")
                            .font(.system(size: 15))
                            .foregroundStyle(AppPalette.subtle)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 16)
            }
        }
        .onAppear { syncPriceDraft() }
        .onChange(of: item.definitionID) { _, _ in syncPriceDraft() }
    }

    private func syncPriceDraft() {
        let saved = item.priceOverrideKrwPerKg ?? defaultPricePerKg
        priceDraft = saved.map { String($0) } ?? ""
    }
}

struct IngredientAmountEditor: View {
    @Binding var item: IngredientLine
    /// 단가 입력칸의 현재 글자. 저장값과 분리해 둬야 다 지운 상태를 유지할 수 있다.
    @State private var priceDraft: String = ""
    let onRemove: () -> Void
    let defaultPricePerKg: Int?

    private var amountText: Binding<String> {
        Binding(
            get: {
                if item.amount == 0 { return "" }
                if item.amount.rounded() == item.amount { return String(Int(item.amount)) }
                return String(item.amount)
            },
            set: { newValue in
                let filtered = filteredDecimal(newValue)
                if filtered.isEmpty { item.amount = 0 }
                else if let value = Double(filtered) { item.amount = value }
            }
        )
    }

    // 입력 중인 글자는 화면이 직접 들고 있는다.
    // 저장된 값에서 매번 다시 만들면, 다 지우는 순간 기본단가가 되살아나
    // 새 단가를 입력할 수 없다.
    private var priceText: Binding<String> {
        Binding(
            get: { priceDraft },
            set: { newValue in
                let filtered = newValue.filter { $0.isNumber }
                priceDraft = filtered
                // 비우면 기본단가로 되돌린다는 뜻으로 본다.
                item.priceOverrideKrwPerKg = filtered.isEmpty ? nil : Int(filtered)
            }
        )
    }

    /// 저장된 값이 바뀌었을 때(다른 배합을 열었을 때 등) 입력칸을 맞춘다.
    private func syncPriceDraft() {
        let saved = item.priceOverrideKrwPerKg ?? defaultPricePerKg
        priceDraft = saved.map { String($0) } ?? ""
    }

    private var effectivePricePerKg: Int? {
        item.priceOverrideKrwPerKg ?? defaultPricePerKg
    }

    private var subtotalKrw: Int? {
        guard let price = effectivePricePerKg else { return nil }
        return Int(asFedKg(for: item) * Double(price))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(item.name)
                    .font(.headline)
                Spacer()
                Button(role: .destructive, action: onRemove) {
                    Image(systemName: "trash")
                }
            }

            HStack(spacing: 10) {
                TextField("0", text: amountText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 8)
                    .background(RoundedRectangle(cornerRadius: 14).fill(AppPalette.surfaceMuted))
                    .frame(maxWidth: .infinity)

                Picker("단위", selection: $item.unit) {
                    ForEach(WeightUnit.allCases) { unit in
                        Text(unit.rawValue).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 100)
            }

            HStack(spacing: 8) {
                Image(systemName: "wonsign")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("단가 (원/kg)", text: priceText)
                    .keyboardType(.numberPad)
                    .onAppear { syncPriceDraft() }
                    .onChange(of: item.definitionID) { _, _ in syncPriceDraft() }
                    .font(.subheadline)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(AppPalette.surfaceMuted))

                if let subtotal = subtotalKrw {
                    Text("= \(krwString(subtotal))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.green)
                }
            }

            if item.priceOverrideKrwPerKg == nil, defaultPricePerKg != nil {
                Text("기본단가 \(krwString(defaultPricePerKg!)) 적용 중")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 18).fill(AppPalette.surfaceMuted))
    }
}
