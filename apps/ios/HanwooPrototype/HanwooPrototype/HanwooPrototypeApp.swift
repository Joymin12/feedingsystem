import SwiftUI

@main
struct HanwooPrototypeApp: App {
    @StateObject private var store = PrototypeStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .task {
                    #if DEBUG
                    print("=== REGRESSION START ===")
                    for formula in store.formulas.filter(\.isTestFormula) {
                        let run = store.analysis(for: formula)
                        print(">>> [\(formula.name)]")
                        for rec in run.recommendations {
                            let acts = rec.correctionActions.map { "\($0.type)==\($0.ingredientName) \(String(format:"%.1f",$0.amountKg))kg" }.joined(separator: " / ")
                            print("    strategy=\(rec.strategy) full=\(rec.isFullyResolved) actions=[\(acts)]")
                        }
                        if run.recommendations.first?.strategy == .noSolution { print("    noSolution") }
                    }
                    print("=== REGRESSION END ===")
                    #endif
                }
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var store: PrototypeStore

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
        .background(Color(.systemGroupedBackground))
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









