import SwiftUI

// MARK: - 배합 편집 화면

struct BlendView: View {
    @EnvironmentObject private var store: PrototypeStore
    @State private var isShowingIngredientSheet = false

    private func binding(for id: UUID) -> Binding<FeedFormula>? {
        guard let index = store.formulas.firstIndex(where: { $0.id == id }) else { return nil }
        return $store.formulas[index]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("배합 입력")
                    .font(.system(size: 30, weight: .bold, design: .rounded))

                let currentID = store.preferredSelectedFormulaID()
                if let formula = binding(for: currentID) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("현재 작업 배합")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppPalette.primary)
                        HStack(spacing: 12) {
                            MetricTile(title: "단계", value: formula.wrappedValue.stage.title, accent: AppPalette.primary)
                            MetricTile(title: "원료 수", value: "\(formula.wrappedValue.items.count)종", accent: AppPalette.ink)
                            MetricTile(title: "유형", value: formula.wrappedValue.isTestFormula ? "테스트" : "실제", accent: AppPalette.warning)
                        }
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(AppPalette.surfaceStrong)
                    )

                    SectionCard(title: "배합 이름", subtitle: "이 배합을 구분할 이름을 적습니다") {
                        VStack(alignment: .leading, spacing: 12) {
                            if formula.wrappedValue.isTestFormula {
                                StatusPill(title: "테스트 배합", tone: .caution)
                            }
                            LabeledTextField(
                                title: "배합 이름",
                                text: formula.name,
                                placeholder: "예: 육성기 오전 배합"
                            )
                        }
                    }

                    SectionCard(title: "성장 단계 선택", subtitle: "이 배합을 어떤 기준으로 판정할지 정합니다") {
                        VStack(alignment: .leading, spacing: 12) {
                            Picker("성장 단계", selection: formula.stage) {
                                ForEach(FarmStage.allCases) { stage in
                                    Text(stage.title).tag(stage)
                                }
                            }
                            .pickerStyle(.segmented)

                            Text(formula.wrappedValue.stage.summary)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack {
                        Text("원료 구성")
                            .font(.title3.bold())
                        Spacer()
                        Button("원료 추가") {
                            isShowingIngredientSheet = true
                        }
                        .font(.subheadline.weight(.semibold))
                    }

                    SectionCard(title: "원료 구성", subtitle: "배합에 들어가는 원료와 중량을 정리합니다") {
                        VStack(spacing: 14) {
                            ForEach(formula.items) { item in
                                IngredientAmountEditor(
                                    item: item,
                                    onRemove: {
                                        store.removeIngredient(from: currentID, ingredientID: item.wrappedValue.id)
                                    },
                                    defaultPricePerKg: item.wrappedValue.definitionID.flatMap {
                                        store.ingredientDefinition(id: $0)?.defaultPriceKrwPerKg
                                    }
                                )
                            }
                        }
                    }

                    // 실시간 합계·검증: 총 원물량과 원료비를 입력 즉시 반영한다.
                    let liveTotalKg = formula.wrappedValue.items.reduce(0.0) { $0 + asFedKg(for: $1) }
                    VStack(spacing: 10) {
                        HStack {
                            Text("총 원물량")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(numberString(liveTotalKg))kg")
                                .font(.title3.bold())
                        }
                        if let totalCost = store.totalCostKrw(for: formula.wrappedValue) {
                            HStack {
                                Text("총 원료비 (원물 기준)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(krwString(totalCost))
                                    .font(.title3.bold())
                                    .foregroundStyle(Color.green)
                            }
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(AppPalette.surface)).overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppPalette.hairline, lineWidth: 1))

                    if liveTotalKg <= 0 {
                        NoticeBanner(kind: .warning, message: "투입량이 0입니다. 원료별 투입량을 입력해야 분석할 수 있습니다.")
                    }

                    NavigationLink {
                        AnalysisDetailView(formulaID: formula.wrappedValue.id)
                    } label: {
                        Text("분석 결과 보기")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }
            .padding(20)
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

struct IngredientAmountEditor: View {
    @Binding var item: IngredientLine
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

    private var priceText: Binding<String> {
        Binding(
            get: {
                let price = item.priceOverrideKrwPerKg ?? defaultPricePerKg
                return price.map { String($0) } ?? ""
            },
            set: { newValue in
                let filtered = newValue.filter { $0.isNumber }
                item.priceOverrideKrwPerKg = Int(filtered)
            }
        )
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
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))
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
                    .font(.subheadline)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(.secondarySystemBackground)))

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
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(.secondarySystemBackground)))
    }
}
