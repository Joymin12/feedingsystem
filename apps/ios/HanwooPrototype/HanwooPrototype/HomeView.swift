import SwiftUI

// MARK: - 홈 대시보드
//
// 홈만 봐도 농장 상태가 읽히도록 상태 카드를 허브처럼 배치한다.
//   1) 히어로: 농장 이름과 단계, 기록 규모
//   2) 현재 배합 카드: 판정 요약(적정 몇, 손볼 것 몇)과 문제 항목 이름
//   3) 가계부 카드: 이번 달 지출과 창고에 남은 원료 금액
// 각 카드는 해당 화면으로 바로 들어가는 입구를 겸한다.

struct HomeView: View {
    @EnvironmentObject private var store: PrototypeStore

    private var productionFormulaCount: Int {
        store.userFacingFormulas.filter { !$0.isTestFormula }.count
    }

    private var currentFormula: FeedFormula? {
        store.formula(for: store.selectedFormulaID)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(store.farmName)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppPalette.subtle)

                Text(store.selectedStage?.title ?? "단계 미선택")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(AppPalette.ink)
                    .padding(.top, 6)

                if let formula = currentFormula {
                    formulaSummary(formula)
                }

                Text("")
                    .padding(.top, 26)

                HairlineDivider()
                navRow(title: "원료 가계부", detail: ledgerDetail) { LedgerView() }
                HairlineDivider()
                navRow(title: "사육일지", detail: diaryDetail) { DiaryListView() }
                HairlineDivider()
                navRow(title: "최근 분석", detail: "저장 \(store.savedAnalyses.count)건") { HistoryView() }
                HairlineDivider()

                NavigationLink {
                    BlendView()
                } label: {
                    Text("배합 분석하기")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 32)
            }
            .padding(.horizontal, 22)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .background(AppScreenBackground())
        .navigationTitle("홈")
    }

    // MARK: 현재 배합 요약

    private var ledgerDetail: String {
        guard !store.purchases.isEmpty else { return "구매 기록 없음" }
        let calendar = Calendar.current
        let month = store.purchases
            .filter { calendar.isDate($0.purchasedAt, equalTo: Date(), toGranularity: .month) }
            .reduce(0) { $0 + $1.totalCostKrw }
        let stock = store.purchases.reduce(0) { $0 + $1.remainingValueKrw }
        return "이번 달 \(krwString(month)) · 재고 \(krwString(stock))"
    }

    private var diaryDetail: String {
        guard let latest = store.diaryEntries.first else { return "기록 없음" }
        return "최근 기록 \(dateString(latest.date))"
    }

    private func navRow<Destination: View>(
        title: String,
        detail: String,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink(destination: destination()) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15))
                        .foregroundStyle(AppPalette.ink)
                    Text(detail)
                        .font(.system(size: 12))
                        .foregroundStyle(AppPalette.subtle)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppPalette.subtle)
            }
            .padding(.vertical, 15)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // 홈에서는 판정만 필요하다. 교정 엔진을 부르면 홈을 그릴 때마다 탐색이 돌아 버벅인다.
    private func formulaSummary(_ formula: FeedFormula) -> some View {
        let statuses = store.statusesOnly(for: formula).statuses
        let attention = statuses.filter { $0.tone != .adequate }
        let metrics = store.statusesOnly(for: formula).metrics

        return NavigationLink {
            AnalysisDetailView(formulaID: formula.id)
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                Text("현재 배합")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppPalette.subtle)
                    .padding(.top, 30)

                HStack(alignment: .firstTextBaseline) {
                    DisplayStat(
                        value: "\(attention.count)",
                        suffix: "/\(statuses.count)",
                        caption: attention.isEmpty ? "모든 항목이 기준을 만족" : "항목이 기준을 벗어남"
                    )
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(formula.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppPalette.ink)
                            .lineLimit(1)
                        Text("\(numberString(metrics.totalAsFedKg))kg · \(formula.items.count)종")
                            .font(.system(size: 12))
                            .foregroundStyle(AppPalette.subtle)
                    }
                }
                .padding(.top, 10)

                if !attention.isEmpty {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 96), spacing: 7)],
                        alignment: .leading,
                        spacing: 7
                    ) {
                        ForEach(attention.prefix(3)) { status in
                            ValueChip(name: status.nutrient, value: status.currentValue)
                        }
                    }
                    .padding(.top, 14)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
