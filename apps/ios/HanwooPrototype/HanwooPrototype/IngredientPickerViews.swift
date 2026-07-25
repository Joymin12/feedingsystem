import SwiftUI

// MARK: - 원료 선택 / 직접 입력 화면
// 배합에 원료를 추가하는 흐름: 분류 선택 → 카테고리 목록 → 추가,
// 또는 사용자 원료(USER_...) 직접 입력.

struct IngredientPickerSheet: View {
    @EnvironmentObject private var store: PrototypeStore
    @Environment(\.dismiss) private var dismiss

    let formulaID: UUID

    var body: some View {
        NavigationStack {
            List {
                ForEach(IngredientCategory.allCases) { category in
                    let defs = store.availableDefinitions(for: category)
                    NavigationLink {
                        IngredientCategoryListView(
                            category: category,
                            formulaID: formulaID,
                            onAdded: { dismiss() }
                        )
                        .environmentObject(store)
                    } label: {
                        HStack {
                            Image(systemName: category.icon)
                                .foregroundStyle(Color.green)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(category.rawValue)
                                    .font(.headline)
                                Text("\(defs.count)종")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("기타") {
                    NavigationLink {
                        CustomIngredientInputView(formulaID: formulaID, onAdded: { dismiss() })
                            .environmentObject(store)
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle")
                                .foregroundStyle(.secondary)
                                .frame(width: 28)
                            Text("내 원료 직접 추가")
                                .font(.headline)
                        }
                    }
                }
            }
            .navigationTitle("원료 분류")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }

}

struct IngredientCategoryListView: View {
    @EnvironmentObject private var store: PrototypeStore
    let category: IngredientCategory
    let formulaID: UUID
    let onAdded: () -> Void

    var body: some View {
        List(store.availableDefinitions(for: category)) { definition in
            Button {
                store.addIngredient(to: formulaID, definition: definition)
                onAdded()
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(definition.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("\(definition.defaultPriceKrwPerKg)원/kg")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 8) {
                        NutrientBadge(label: "수분", value: "\(numberString(definition.nutrition.moisturePct))%")
                        NutrientBadge(label: "CP", value: "\(numberString(definition.nutrition.cpPctDm))%")
                        NutrientBadge(label: "TDN", value: "\(numberString(definition.nutrition.tdnPctDm))%")
                        NutrientBadge(label: "NDF", value: "\(numberString(definition.nutrition.ndfPctDm))%")
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle(category.rawValue)
    }
}

struct CustomIngredientInputView: View {
    @EnvironmentObject private var store: PrototypeStore
    @Environment(\.dismiss) private var dismiss
    let formulaID: UUID
    let onAdded: () -> Void
    @State private var customName = ""
    @State private var category: IngredientCategory = .agriByproduct
    @State private var amountKg = "10"
    @State private var priceKrwPerKg = "0"
    @State private var moisturePct = "12"
    @State private var cpPctDm = ""
    @State private var tdnPctDm = ""
    @State private var eePctDm = ""
    @State private var ndfPctDm = ""
    @State private var adfPctDm = ""
    @State private var nfcPctDm = ""
    @State private var ashPctDm = ""
    @State private var caPctDm = ""
    @State private var pPctDm = ""

    private var trimmedName: String {
        customName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var dmPct: Double {
        max(0, 100 - decimalValue(moisturePct))
    }

    private var canSave: Bool {
        !trimmedName.isEmpty &&
            decimalValue(amountKg) > 0 &&
            decimalValue(moisturePct) >= 0 &&
            decimalValue(moisturePct) < 100
    }

    var body: some View {
        List {
            Section("기본 정보") {
                TextField("예: 청보리 사일리지", text: $customName)
                    .textInputAutocapitalization(.never)
                Picker("카테고리", selection: $category) {
                    ForEach(IngredientCategory.allCases) { category in
                        Text(category.rawValue).tag(category)
                    }
                }
                TextField("투입량 kg", text: decimalText($amountKg))
                    .keyboardType(.decimalPad)
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
            } footer: {
                Text("축협·농협·분석기관에서 받은 수분값을 입력하면 건물률은 자동 계산됩니다.")
            }

            Section {
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
            } header: {
                Text("영양성분 (%DM 기준)")
            } footer: {
                Text("빈 값은 0으로 저장됩니다. 앱 계산과 추천 시뮬레이션은 이 입력값을 원료 DB보다 우선 사용합니다.")
            }

            Section {
                Button("원료 저장 후 배합에 추가") {
                    guard canSave else { return }
                    store.addUserIngredient(
                        to: formulaID,
                        name: trimmedName,
                        category: category,
                        amount: decimalValue(amountKg),
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
                        )
                    )
                    onAdded()
                }
                .disabled(!canSave)
            }
        }
        .navigationTitle("내 원료 추가")
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
