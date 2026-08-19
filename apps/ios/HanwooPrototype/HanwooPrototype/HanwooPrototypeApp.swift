import SwiftUI

@main
struct HanwooPrototypeApp: App {
    @StateObject private var store = PrototypeStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var store: PrototypeStore

    /// 임시: 디자인 작업 중에는 로그인 게이트를 건너뛴다.
    /// 출시 전에 false로 되돌리거나 이 플래그 자체를 제거할 것.
    private let skipsAuthGateForDesignWork = true

    var body: some View {
        Group {
            if !store.isAuthenticated {
                AuthGatewayView()
            } else if !store.hasCompletedOnboarding {
                StageOnboardingView()
            } else {
                MainTabView()
            }
        }
        .background(AppPalette.canvas)
        .onAppear {
            guard skipsAuthGateForDesignWork, !store.isAuthenticated else { return }
            _ = store.login(loginID: "qwer123", password: "asdf123")
            if store.selectedStage == nil {
                store.selectedStage = .fatteningEarly
            }
        }
    }
}


struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack { HomeView() }
                .tabItem {
                    Label("홈", systemImage: "house.fill")
                }

            NavigationStack { BlendView() }
                .tabItem {
                    Label("배합", systemImage: "carrot.fill")
                }

            NavigationStack { HistoryView() }
                .tabItem {
                    Label("최근 분석", systemImage: "clock.fill")
                }

            NavigationStack { CommunityView() }
                .tabItem {
                    Label("커뮤니티", systemImage: "bubble.left.and.bubble.right.fill")
                }

            NavigationStack { FarmView() }
                .tabItem {
                    Label("내 농장", systemImage: "person.crop.circle.fill")
                }
        }
        .tint(AppPalette.primary)
    }
}









