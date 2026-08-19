import SwiftUI

// MARK: - 원료 가계부
//
// 농가는 원료를 살 때마다 단가가 다르다. 언제 얼마에 몇 kg을 샀는지 남겨두면
// 실제 사료비를 알 수 있고, 남은 양을 보면 다음 구매 시점을 가늠할 수 있다.
//
// 재고를 자동으로 깎지 않는다. 배합표는 설계이고 실제 급여량은 날마다 다르기 때문에,
// 앱이 임의로 빼면 창고 실물과 어긋난다. 남은 양은 농가가 직접 조정한다.

struct LedgerView: View {
    @EnvironmentObject private var store: PrototypeStore
    @State private var isAdding = false
    @State private var pendingDeletion: FeedPurchase?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                summaryCard
                stockCard
                purchaseListCard
            }
            .padding(20)
        }
        .background(AppScreenBackground())
        .navigationTitle("원료 가계부")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isAdding = true
                } label: {
                    Label("구매 기록", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isAdding) {
            PurchaseEditorView()
                .environmentObject(store)
        }
        .alert("이 구매 기록을 지울까요?", isPresented: Binding(
            get: { pendingDeletion != nil },
            set: { if !$0 { pendingDeletion = nil } }
        )) {
            Button("삭제", role: .destructive) {
                if let target = pendingDeletion {
                    store.purchases.removeAll { $0.id == target.id }
                }
                pendingDeletion = nil
            }
            Button("취소", role: .cancel) { pendingDeletion = nil }
        } message: {
            if let target = pendingDeletion {
                Text("\(target.ingredientName) · \(dateString(target.purchasedAt))")
            }
        }
    }

    // MARK: 이번 달 요약

    private var summaryCard: some View {
        let calendar = Calendar.current
        let now = Date()
        let thisMonth = store.purchases.filter {
            calendar.isDate($0.purchasedAt, equalTo: now, toGranularity: .month)
        }
        let monthCost = thisMonth.reduce(0) { $0 + $1.totalCostKrw }
        let totalCost = store.purchases.reduce(0) { $0 + $1.totalCostKrw }
        let stockValue = store.purchases.reduce(0) { $0 + $1.remainingValueKrw }

        return SectionCard(title: "지출 요약", subtitle: monthLabel(now)) {
            VStack(spacing: 12) {
                amountRow("이번 달 구매액", monthCost, accent: AppPalette.ink, emphasized: true)
                Divider()
                amountRow("전체 누적 구매액", totalCost, accent: .secondary)
                amountRow("남은 원료 금액", stockValue, accent: AppPalette.primary)
            }
        }
    }

    private func amountRow(_ title: String, _ amount: Int, accent: Color, emphasized: Bool = false) -> some View {
        HStack {
            Text(title)
                .font(emphasized ? .subheadline.weight(.semibold) : .subheadline)
                .foregroundStyle(emphasized ? AppPalette.ink : .secondary)
            Spacer()
            Text(krwString(amount))
                .font(emphasized ? .title3.weight(.bold).monospacedDigit() : .subheadline.monospacedDigit())
                .foregroundStyle(accent)
        }
    }

    // MARK: 남은 원료

    private var stockCard: some View {
        // 같은 원료를 여러 번 샀을 수 있으므로 이름으로 합산한다.
        let grouped = Dictionary(grouping: store.purchases.filter { !$0.isDepleted }) { $0.ingredientName }
        let rows = grouped
            .map { (name: $0.key, kg: $0.value.reduce(0.0) { $0 + $1.remainingKg }) }
            .sorted { $0.kg > $1.kg }

        return SectionCard(title: "남은 원료", subtitle: "") {
            if rows.isEmpty {
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.name) { index, row in
                        if index > 0 { Divider() }
                        HStack {
                            Text(row.name)
                                .font(.subheadline)
                                .foregroundStyle(AppPalette.ink)
                            Spacer()
                            Text("\(numberString(row.kg))kg")
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                                .foregroundStyle(AppPalette.ink)
                        }
                        .padding(.vertical, 10)
                    }
                }
            }
        }
    }

    // MARK: 구매 내역

    private var purchaseListCard: some View {
        let sorted = store.purchases.sorted { $0.purchasedAt > $1.purchasedAt }

        return SectionCard(title: "구매 내역", subtitle: "") {
            if sorted.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("아직 기록이 없습니다.")
                        .font(.subheadline)
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(sorted.enumerated()), id: \.element.id) { index, purchase in
                        if index > 0 { Divider() }
                        purchaseRow(purchase)
                    }
                }
            }
        }
    }

    private func purchaseRow(_ purchase: FeedPurchase) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(purchase.ingredientName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppPalette.ink)
                if purchase.isDepleted {
                    StatusPill(title: "소진", tone: .caution)
                }
                Spacer()
                Text(krwString(purchase.totalCostKrw))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(AppPalette.ink)
            }

            Text("\(dateString(purchase.purchasedAt)) · \(numberString(purchase.quantityKg))kg · kg당 \(krwString(purchase.unitPriceKrwPerKg))")
                .font(.caption)
                .foregroundStyle(.secondary)

            if !purchase.vendor.isEmpty || !purchase.memo.isEmpty {
                Text([purchase.vendor, purchase.memo].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            // 남은 양은 여기서 바로 조정한다. 창고를 보고 고치는 값이라 입력이 쉬워야 한다.
            HStack(spacing: 10) {
                Text("남은 양")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    adjustRemaining(purchase, by: -1)
                } label: {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppPalette.warning)

                Text("\(numberString(purchase.remainingKg))kg")
                    .font(.subheadline.monospacedDigit())
                    .frame(minWidth: 62)

                Button {
                    adjustRemaining(purchase, by: 1)
                } label: {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppPalette.primary)

                Spacer()

                Button(role: .destructive) {
                    pendingDeletion = purchase
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppPalette.warning)
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 11)
    }

    private func adjustRemaining(_ purchase: FeedPurchase, by deltaKg: Double) {
        guard let index = store.purchases.firstIndex(where: { $0.id == purchase.id }) else { return }
        let next = store.purchases[index].remainingKg + deltaKg
        // 구매량보다 많이 남을 수는 없고, 음수도 될 수 없다.
        store.purchases[index].remainingKg = min(max(0, next), store.purchases[index].quantityKg)
    }

    private func monthLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월"
        return formatter.string(from: date)
    }
}

// MARK: - 구매 기록 입력

struct PurchaseEditorView: View {
    @EnvironmentObject private var store: PrototypeStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var ingredientID: String?
    @State private var purchasedAt = Date()
    @State private var quantityText = ""
    @State private var unitPriceText = ""
    @State private var vendor = ""
    @State private var memo = ""
    @State private var isPickingIngredient = false

    private var quantityKg: Double { Double(quantityText) ?? 0 }
    private var unitPrice: Int { Int(unitPriceText) ?? 0 }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && quantityKg > 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section("원료") {
                    // 카탈로그에서 고르면 이름과 기본 단가가 함께 채워진다.
                    Button {
                        isPickingIngredient = true
                    } label: {
                        HStack {
                            Text(name.isEmpty ? "원료 선택" : name)
                                .foregroundStyle(name.isEmpty ? Color.secondary : AppPalette.ink)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    TextField("직접 입력", text: $name)
                        .onChange(of: name) { _, _ in ingredientID = nil }
                }

                Section("구매 정보") {
                    DatePicker("구매일", selection: $purchasedAt, displayedComponents: .date)
                    HStack {
                        Text("수량")
                        Spacer()
                        TextField("0", text: $quantityText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                        Text("kg")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("kg당 단가")
                        Spacer()
                        TextField("0", text: $unitPriceText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                        Text("원")
                            .foregroundStyle(.secondary)
                    }
                    if quantityKg > 0 && unitPrice > 0 {
                        HStack {
                            Text("총액")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(krwString(Int((quantityKg * Double(unitPrice)).rounded())))
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                                .foregroundStyle(AppPalette.primary)
                        }
                    }
                }

                Section("메모 (선택)") {
                    TextField("구입처", text: $vendor)
                    TextField("메모", text: $memo)
                }
            }
            .navigationTitle("구매 기록")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { save() }
                        .disabled(!canSave)
                }
            }
            .sheet(isPresented: $isPickingIngredient) {
                LedgerIngredientPicker { definition in
                    name = definition.name
                    ingredientID = definition.id
                    if unitPriceText.isEmpty {
                        unitPriceText = String(definition.defaultPriceKrwPerKg)
                    }
                    isPickingIngredient = false
                }
                .environmentObject(store)
            }
        }
    }

    private func save() {
        let purchase = FeedPurchase(
            ingredientID: ingredientID,
            ingredientName: name.trimmingCharacters(in: .whitespaces),
            purchasedAt: purchasedAt,
            quantityKg: quantityKg,
            unitPriceKrwPerKg: unitPrice,
            remainingKg: quantityKg,
            vendor: vendor.trimmingCharacters(in: .whitespaces),
            memo: memo.trimmingCharacters(in: .whitespaces)
        )
        store.purchases.append(purchase)
        dismiss()
    }
}

// MARK: - 가계부 전용 원료 선택
//
// 기존 원료 피커는 특정 배합에 원료를 추가하는 용도라 여기서 쓸 수 없다.
// 여기서는 이름과 기본 단가만 가져오면 되므로 단순한 검색 목록으로 둔다.

struct LedgerIngredientPicker: View {
    @EnvironmentObject private var store: PrototypeStore
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    let onSelect: (IngredientDefinition) -> Void

    private var results: [IngredientDefinition] {
        let all = IngredientCategory.allCases.flatMap { store.availableDefinitions(for: $0) }
        let keyword = query.trimmingCharacters(in: .whitespaces)
        guard !keyword.isEmpty else { return all }
        return all.filter { $0.name.localizedCaseInsensitiveContains(keyword) }
    }

    var body: some View {
        NavigationStack {
            List(results) { definition in
                Button {
                    onSelect(definition)
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(definition.name)
                                .foregroundStyle(AppPalette.ink)
                            Text(definition.category.rawValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("kg당 \(krwString(definition.defaultPriceKrwPerKg))")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .searchable(text: $query, prompt: "원료 이름 검색")
            .navigationTitle("원료 선택")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
            }
        }
    }
}
