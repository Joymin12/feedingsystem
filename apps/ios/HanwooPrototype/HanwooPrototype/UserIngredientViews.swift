import SwiftUI

// MARK: - 내 원료 관리 화면
// 사용자가 직접 입력한 원료(USER_...)의 목록/삭제/편집.

struct UserIngredientManagementView: View {
    @EnvironmentObject private var store: PrototypeStore
    @State private var pendingDeletion: UserIngredientDefinition?

    var body: some View {
        let ingredients = store.myUserIngredientDefinitions()

        List {
            if ingredients.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("직접 입력한 원료가 없습니다.")
                            .font(.headline)
                        Text("배합 화면의 원료 추가에서 분석기관 성분표를 입력하면 이곳에서 다시 수정할 수 있습니다.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }
            } else {
                ForEach(IngredientCategory.allCases) { category in
                    let categoryIngredients = ingredients.filter { $0.category == category }
                    if !categoryIngredients.isEmpty {
                        Section(category.rawValue) {
                            ForEach(categoryIngredients) { ingredient in
                                NavigationLink {
                                    UserIngredientEditView(ingredient: ingredient)
                                        .environmentObject(store)
                                } label: {
                                    UserIngredientSummaryRow(
                                        ingredient: ingredient,
                                        usageCount: store.formulaUsageCount(forUserIngredientID: ingredient.id)
                                    )
                                }
                                .swipeActions {
                                    Button(role: .destructive) {
                                        pendingDeletion = ingredient
                                    } label: {
                                        Label("삭제", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("내 원료 관리")
        .alert("원료를 삭제할까요?", isPresented: deletionAlertBinding) {
            Button("취소", role: .cancel) {
                pendingDeletion = nil
            }
            Button("삭제", role: .destructive) {
                if let pendingDeletion {
                    store.deleteUserIngredient(id: pendingDeletion.id)
                }
                pendingDeletion = nil
            }
        } message: {
            if let pendingDeletion {
                let usageCount = store.formulaUsageCount(forUserIngredientID: pendingDeletion.id)
                Text("'\(pendingDeletion.name)' 원료가 삭제됩니다. 이 원료를 쓰던 배합 라인 \(usageCount)개도 함께 제거됩니다.")
            }
        }
    }

    private var deletionAlertBinding: Binding<Bool> {
        Binding(
            get: { pendingDeletion != nil },
            set: { if !$0 { pendingDeletion = nil } }
        )
    }
}

struct UserIngredientSummaryRow: View {
    let ingredient: UserIngredientDefinition
    let usageCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(ingredient.name)
                    .font(.headline)
                Spacer()
                Text("\(ingredient.defaultPriceKrwPerKg)원/kg")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                NutrientBadge(label: "수분", value: "\(numberString(ingredient.nutrition.moisturePct))%")
                NutrientBadge(label: "CP", value: "\(numberString(ingredient.nutrition.cpPctDm))%")
                NutrientBadge(label: "TDN", value: "\(numberString(ingredient.nutrition.tdnPctDm))%")
                NutrientBadge(label: "EE", value: "\(numberString(ingredient.nutrition.eePctDm))%")
            }

            Text("사용 중인 배합 라인 \(usageCount)개")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct UserIngredientEditView: View {
    @EnvironmentObject private var store: PrototypeStore
    @Environment(\.dismiss) private var dismiss

    let ingredient: UserIngredientDefinition
    @State private var customName: String
    @State private var category: IngredientCategory
    @State private var priceKrwPerKg: String
    @State private var moisturePct: String
    @State private var cpPctDm: String
    @State private var tdnPctDm: String
    @State private var eePctDm: String
    @State private var ndfPctDm: String
    @State private var adfPctDm: String
    @State private var nfcPctDm: String
    @State private var ashPctDm: String
    @State private var caPctDm: String
    @State private var pPctDm: String

    init(ingredient: UserIngredientDefinition) {
        self.ingredient = ingredient
        _customName = State(initialValue: ingredient.name)
        _category = State(initialValue: ingredient.category)
        _priceKrwPerKg = State(initialValue: String(ingredient.defaultPriceKrwPerKg))
        _moisturePct = State(initialValue: numberString(ingredient.nutrition.moisturePct))
        _cpPctDm = State(initialValue: numberString(ingredient.nutrition.cpPctDm))
        _tdnPctDm = State(initialValue: numberString(ingredient.nutrition.tdnPctDm))
        _eePctDm = State(initialValue: numberString(ingredient.nutrition.eePctDm))
        _ndfPctDm = State(initialValue: numberString(ingredient.nutrition.ndfPctDm))
        _adfPctDm = State(initialValue: numberString(ingredient.nutrition.adfPctDm))
        _nfcPctDm = State(initialValue: numberString(ingredient.nutrition.nfcPctDm))
        _ashPctDm = State(initialValue: numberString(ingredient.nutrition.ashPctDm))
        _caPctDm = State(initialValue: numberString(ingredient.nutrition.caPctDm))
        _pPctDm = State(initialValue: numberString(ingredient.nutrition.pPctDm))
    }

    private var trimmedName: String {
        customName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var dmPct: Double {
        max(0, 100 - decimalValue(moisturePct))
    }

    private var canSave: Bool {
        !trimmedName.isEmpty &&
            decimalValue(moisturePct) >= 0 &&
            decimalValue(moisturePct) < 100
    }

    var body: some View {
        List {
            Section("기본 정보") {
                TextField("원료명", text: $customName)
                    .textInputAutocapitalization(.never)
                Picker("카테고리", selection: $category) {
                    ForEach(IngredientCategory.allCases) { category in
                        Text(category.rawValue).tag(category)
                    }
                }
                TextField("단가 원/kg", text: integerText($priceKrwPerKg))
                    .keyboardType(.numberPad)
            }

            Section {
                TextField("수분 %", text: decimalText($moisturePct))
                    .keyboardType(.decimalPad)
                HStack {
                    Text("건물 DM")
                    Spacer()
                    Text("\(numberString(dmPct))%")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("건물/수분")
            }

            Section("영양성분 (%DM 기준)") {
                TextField("CP 조단백", text: decimalText($cpPctDm))
                    .keyboardType(.decimalPad)
                TextField("TDN 가소화영양소총량", text: decimalText($tdnPctDm))
                    .keyboardType(.decimalPad)
                TextField("EE 조지방", text: decimalText($eePctDm))
                    .keyboardType(.decimalPad)
                TextField("NDF 중성세제불용섬유", text: decimalText($ndfPctDm))
                    .keyboardType(.decimalPad)
                TextField("ADF 산성세제불용섬유", text: decimalText($adfPctDm))
                    .keyboardType(.decimalPad)
                TextField("NFC 비섬유성탄수화물", text: decimalText($nfcPctDm))
                    .keyboardType(.decimalPad)
                TextField("회분 Ash", text: decimalText($ashPctDm))
                    .keyboardType(.decimalPad)
                TextField("Ca 칼슘", text: decimalText($caPctDm))
                    .keyboardType(.decimalPad)
                TextField("P 인", text: decimalText($pPctDm))
                    .keyboardType(.decimalPad)
            }

            Section {
                Button("저장") {
                    guard canSave else { return }
                    let updated = UserIngredientDefinition(
                        id: ingredient.id,
                        ownerLoginID: ingredient.ownerLoginID,
                        name: trimmedName,
                        category: category,
                        defaultPriceKrwPerKg: Int(priceKrwPerKg) ?? 0,
                        nutrition: IngredientNutritionProfile(
                            moisturePct: decimalValue(moisturePct),
                            dmPct: dmPct,
                            cpPctDm: decimalValue(cpPctDm),
                            tdnPctDm: decimalValue(tdnPctDm),
                            ndfPctDm: decimalValue(ndfPctDm),
                            adfPctDm: decimalValue(adfPctDm),
                            nfcPctDm: decimalValue(nfcPctDm),
                            eePctDm: decimalValue(eePctDm),
                            ashPctDm: decimalValue(ashPctDm),
                            caPctDm: decimalValue(caPctDm),
                            pPctDm: decimalValue(pPctDm)
                        ),
                        createdAt: ingredient.createdAt
                    )
                    store.updateUserIngredient(updated)
                    dismiss()
                }
                .disabled(!canSave)
            }
        }
        .navigationTitle("원료 수정")
    }

    private func decimalText(_ value: Binding<String>) -> Binding<String> {
        Binding(
            get: { value.wrappedValue },
            set: { value.wrappedValue = filteredDecimal($0) }
        )
    }

    private func integerText(_ value: Binding<String>) -> Binding<String> {
        Binding(
            get: { value.wrappedValue },
            set: { value.wrappedValue = $0.filter(\.isNumber) }
        )
    }

    private func decimalValue(_ value: String) -> Double {
        Double(value) ?? 0
    }
}
