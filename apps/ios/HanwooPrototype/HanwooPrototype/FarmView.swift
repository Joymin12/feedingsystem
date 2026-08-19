import SwiftUI

// MARK: - 내 농장 화면

struct FarmView: View {
    @EnvironmentObject private var store: PrototypeStore
    @State private var isLoggingOut = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SectionCard(title: store.farmName, subtitle: store.selectedStage?.title ?? "단계 미선택") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("최근 분석과 사육일지를 이곳에서 다시 확인합니다.")
                        if let currentUser = store.currentUser {
                            Text("로그인 계정: \(currentUser.loginID)\(currentUser.isAdmin ? " · 관리자" : "")")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                        .foregroundStyle(.secondary)
                }

                NavigationLink {
                    DiaryListView()
                } label: {
                    QuickActionCard(title: "사육일지", subtitle: "기록 추가와 수정", icon: "book.closed.fill")
                }
                .buttonStyle(.plain)

                NavigationLink {
                    HistoryView()
                } label: {
                    QuickActionCard(title: "최근 분석", subtitle: "배합 기준 다시 보기", icon: "chart.bar.doc.horizontal.fill")
                }
                .buttonStyle(.plain)

                NavigationLink {
                    LedgerView()
                } label: {
                    QuickActionCard(title: "원료 가계부", subtitle: "구매 기록과 남은 원료", icon: "wonsign.circle.fill")
                }
                .buttonStyle(.plain)

                NavigationLink {
                    UserIngredientManagementView()
                } label: {
                    QuickActionCard(title: "내 원료 관리", subtitle: "직접 입력한 원료 성분 수정", icon: "tray.full.fill")
                }
                .buttonStyle(.plain)

                NavigationLink {
                    SettingsHelpView()
                } label: {
                    QuickActionCard(title: "설정·도움말", subtitle: "성장단계 변경, 용어 안내, 데이터 관리", icon: "gearshape.fill")
                }
                .buttonStyle(.plain)

                if store.currentUser?.isAdmin == true {
                    NavigationLink {
                        RegressionSuiteView()
                    } label: {
                        QuickActionCard(title: "엔진 검증", subtitle: "테스트 배합 7종의 추천안 방향 확인", icon: "checklist.checked")
                    }
                    .buttonStyle(.plain)
                }

                Button("로그아웃") {
                    isLoggingOut = true
                    Task {
                        await store.performLogout()
                        await MainActor.run {
                            isLoggingOut = false
                        }
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isLoggingOut)
            }
            .padding(20)
        }
        .background(AppScreenBackground())
        .navigationTitle("내 농장")
    }
}




