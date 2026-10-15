import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            if model.state.profile.hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .paperBackground()
        .task {
            await model.restoreRemindersIfNeeded()
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                HomeView()
            }
            .tabItem { Label("Home", systemImage: "house.fill") }

            NavigationStack {
                CircleView()
            }
            .tabItem { Label("Circle", systemImage: "person.3.fill") }

            NavigationStack {
                HistoryView()
            }
            .tabItem { Label("History", systemImage: "chart.xyaxis.line") }

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}

#Preview("Home") {
    RootView()
        .environment(AppModel.preview())
}
