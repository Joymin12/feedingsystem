import SwiftUI

// MARK: - 내 농장 화면

struct FarmView: View {
    @EnvironmentObject private var store: PrototypeStore
    @State private var isLoggingOut = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(store.currentUser.map { "\($0.loginID)\($0.isAdmin ? " · 관리자" : "")" } ?? "")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppPalette.subtle)

                Text(store.farmName)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(AppPalette.ink)
                    .padding(.top, 6)

                Text(store.selectedStage?.title ?? "단계 미선택")
                    .font(.footnote)
                    .foregroundStyle(AppPalette.subtle)
                    .padding(.top, 6)

                Color.clear.frame(height: 26)

                HairlineDivider()
                row("사육일지") { DiaryListView() }
                HairlineDivider()
                row("최근 분석") { HistoryView() }
                HairlineDivider()
                row("원료 가계부") { LedgerView() }
                HairlineDivider()
                row("내 원료 관리") { UserIngredientManagementView() }
                HairlineDivider()
                row("설정·도움말") { SettingsHelpView() }
                HairlineDivider()

                if store.currentUser?.isAdmin == true {
                    row("엔진 검증") { RegressionSuiteView() }
                    HairlineDivider()
                }

                Button {
                    isLoggingOut = true
                } label: {
                    Text("로그아웃")
                        .font(.system(size: 15))
                        .foregroundStyle(AppPalette.alert)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 16)
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .background(AppScreenBackground())
        .navigationTitle("내 농장")
        .alert("로그아웃할까요?", isPresented: $isLoggingOut) {
            Button("취소", role: .cancel) {}
            Button("로그아웃", role: .destructive) {
                Task { await store.performLogout() }
            }
        }
    }

    private func row<Destination: View>(
        _ title: String,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink(destination: destination()) {
            HStack {
                Text(title)
                    .font(.system(size: 15))
                    .foregroundStyle(AppPalette.ink)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppPalette.subtle)
            }
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

}




