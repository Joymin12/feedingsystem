import SwiftUI

// MARK: - 홈 대시보드 화면

struct HomeView: View {
    @EnvironmentObject private var store: PrototypeStore

    private var productionFormulaCount: Int {
        store.userFacingFormulas.filter { !$0.isTestFormula }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("현장 운영 대시보드")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppPalette.primary)
                    Text(store.farmName)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                    Text(store.selectedStage?.title ?? "단계 미선택")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("배합 입력부터 분석, 교정안 확인, 일지 기록까지 한 흐름으로 빠르게 점검합니다.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        MetricTile(
                            title: "실제 배합",
                            value: "\(productionFormulaCount)개",
                            accent: AppPalette.primary
                        )
                        MetricTile(
                            title: "최근 분석",
                            value: "\(store.userFacingAnalyses.count)건",
                            accent: AppPalette.ink
                        )
                        MetricTile(
                            title: "사육일지",
                            value: "\(store.diaryEntries.count)건",
                            accent: AppPalette.warning
                        )
                    }
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(AppPalette.heroGradient)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )

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
