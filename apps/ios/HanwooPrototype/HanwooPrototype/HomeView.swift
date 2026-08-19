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
            VStack(alignment: .leading, spacing: 16) {
                heroCard

                if let formula = currentFormula {
                    formulaStatusCard(formula)
                }

                ledgerCard

                NavigationLink {
                    BlendView()
                } label: {
                    QuickActionCard(title: "배합하기", subtitle: "원료와 배합 이름을 입력하고 분석합니다", icon: "carrot.fill")
                }
                .buttonStyle(.plain)

                NavigationLink {
                    HistoryView()
                } label: {
                    QuickActionCard(title: "최근 분석", subtitle: "저장된 배합의 분석 결과를 다시 봅니다", icon: "clock.fill")
                }
                .buttonStyle(.plain)

                NavigationLink {
                    DiaryListView()
                } label: {
                    QuickActionCard(title: "사육일지", subtitle: "경과 기록을 추가하고 수정합니다", icon: "book.pages.fill")
                }
                .buttonStyle(.plain)
            }
            .padding(20)
        }
        .background(AppScreenBackground())
        .navigationTitle("홈")
    }

    // MARK: 히어로

    private func heroStat(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.75))
            Text(value)
                .font(.headline.bold())
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.14))
        )
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.farmName)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Text(store.selectedStage?.title ?? "단계 미선택")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                }
                Spacer()
                Image(systemName: "leaf.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(.white.opacity(0.35))
            }

            HStack(spacing: 10) {
                heroStat(title: "실제 배합", value: "\(productionFormulaCount)개")
                heroStat(title: "저장 분석", value: "\(store.savedAnalyses.count)건")
                heroStat(title: "사육일지", value: "\(store.diaryEntries.count)건")
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppPalette.heroGradient)
        )
        .shadow(color: AppPalette.primaryDeep.opacity(0.25), radius: 12, x: 0, y: 6)
    }

    // MARK: 현재 배합 상태

    private func formulaStatusCard(_ formula: FeedFormula) -> some View {
        // 홈에서는 판정만 필요하다. 교정안은 분석 화면에서 만든다.
        // 여기서 analysis(for:)를 부르면 홈을 그릴 때마다 교정 엔진이 돌아 화면이 버벅인다.
        let statuses = store.statusesOnly(for: formula).statuses
        let adequate = statuses.filter { $0.tone == .adequate }.count
        let caution = statuses.filter { $0.tone == .caution }.count
        let attention = statuses.filter { $0.tone == .deficient || $0.tone == .excess }
        let allClear = attention.isEmpty && caution == 0

        return NavigationLink {
            AnalysisDetailView(formulaID: formula.id)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("현재 배합")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(formula.name)
                            .font(.headline)
                            .foregroundStyle(AppPalette.ink)
                    }
                    Spacer()
                    StatusPill(
                        title: allClear ? "모두 적정" : "\(attention.count + caution)개 확인 필요",
                        tone: allClear ? .adequate : (attention.isEmpty ? .caution : .deficient)
                    )
                }

                HStack(spacing: 14) {
                    statusDot(count: adequate, label: "적정", tone: .adequate)
                    statusDot(count: caution, label: "주의", tone: .caution)
                    statusDot(count: attention.count, label: "부족·과잉", tone: .deficient)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }

                if !attention.isEmpty {
                    Text(attention.map(\.nutrient).joined(separator: ", ") + " 항목을 확인해보세요")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .cardSurface()
        }
        .buttonStyle(.plain)
    }

    private func statusDot(count: Int, label: String, tone: StatusTone) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(count > 0 ? tone.color : Color.secondary.opacity(0.25))
                .frame(width: 8, height: 8)
            Text("\(label) \(count)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(count > 0 ? AppPalette.ink : Color.secondary)
        }
    }

    // MARK: 가계부 요약

    private var ledgerCard: some View {
        let calendar = Calendar.current
        let now = Date()
        let monthCost = store.purchases
            .filter { calendar.isDate($0.purchasedAt, equalTo: now, toGranularity: .month) }
            .reduce(0) { $0 + $1.totalCostKrw }
        let stockValue = store.purchases.reduce(0) { $0 + $1.remainingValueKrw }

        return NavigationLink {
            LedgerView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "wonsign.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppPalette.primary)
                    .frame(width: 42, height: 42)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(AppPalette.accentSoft)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text("원료 가계부")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppPalette.ink)
                    Text(store.purchases.isEmpty
                         ? "구매 기록을 남기면 사료비가 집계됩니다"
                         : "이번 달 \(krwString(monthCost)) · 남은 원료 \(krwString(stockValue))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .cardSurface()
        }
        .buttonStyle(.plain)
    }
}
