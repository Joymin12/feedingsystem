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

    /// 디자인 작업 동안 잠시 끄던 로그인 게이트를 되살렸다.
    /// 소셜 로그인 화면이 첫 화면이다.
    private let skipsAuthGateForDesignWork = false

    var body: some View {
        Group {
            if !store.isAuthenticated {
                AuthGatewayView()
            } else if !store.hasCompletedOnboarding {
                OnboardingFlowView()
            } else {
                MainTabView()
            }
        }
        .background(AppPalette.canvas)
        .onAppear {
            guard skipsAuthGateForDesignWork, !store.isAuthenticated else { return }
            _ = store.login(loginID: "qwer123", password: "asdf123")
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









