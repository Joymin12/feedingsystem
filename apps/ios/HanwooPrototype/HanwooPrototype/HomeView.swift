import SwiftUI

// MARK: - 홈 대시보드 화면

struct HomeView: View {
    @EnvironmentObject private var store: PrototypeStore

    private var productionFormulaCount: Int {
        store.userFacingFormulas.filter { !$0.isTestFormula }.count
    }

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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
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

                    Text("배합 입력부터 판정, 증감 시뮬레이션, 교정안까지 한 흐름으로 점검합니다.")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.85))

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

                SectionCard(title: "오늘의 기준", subtitle: store.selectedStage?.summary ?? "대표 단계 기준을 아직 고르지 않았습니다") {
                    Text(store.selectedStage?.criteria.feedingNote ?? "온보딩에서 대표 단계를 선택하면 기준과 설명이 함께 표시됩니다.")
                        .foregroundStyle(.secondary)
                }

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
}
