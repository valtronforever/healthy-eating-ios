import SwiftUI

@main
struct HealthyEatingApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .tint(.accent)
        }
        // The notice when meals stop arriving and the Apple Health sync (both opt-in).
        .backgroundTask(.appRefresh(ArrivalNotice.taskIdentifier)) { [model] in
            await model.backgroundRefresh()
        }
    }
}

/// Shows onboarding until a server is set up, then the four tabs.
struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        if model.hasCompletedOnboarding {
            MainTabView()
                .task {
                    model.scheduleBackgroundRefresh()
                    await model.syncTimeZoneIfNeeded()
                    await model.syncAppleHealth(foreground: true)
                }
                // Meals and weigh-ins sync with Apple Health whenever the app opens.
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { Task { await model.syncAppleHealth(foreground: true) } }
                }
        } else {
            OnboardingFlow()
        }
    }
}

enum AppTab: String, CaseIterable {
    case today, history, trends, settings
}

/// The system tab bar with the four tabs from the design system.
struct MainTabView: View {
    @State private var selection: AppTab

    init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        _selection = State(initialValue: AppModel.LaunchArgument.initialTab(in: arguments) ?? .today)
    }

    var body: some View {
        TabView(selection: $selection) {
            Tab("Today", systemImage: "fork.knife", value: AppTab.today) {
                TodayView()
            }
            Tab("History", systemImage: "calendar", value: AppTab.history) {
                HistoryView()
            }
            Tab("Trends", systemImage: "chart.bar", value: AppTab.trends) {
                TrendsView()
            }
            Tab("Settings", systemImage: "gearshape", value: AppTab.settings) {
                SettingsView()
            }
        }
    }
}

#Preview("Light") {
    MainTabView().environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.skipOnboarding]))
}

#Preview("Dark") {
    MainTabView().environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.skipOnboarding]))
        .preferredColorScheme(.dark)
}

#Preview("AX5") {
    MainTabView().environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.skipOnboarding]))
        .environment(\.dynamicTypeSize, .accessibility5)
}

extension UserDefaults {
    /// A throwaway store so previews never touch the app's real settings.
    static var preview: UserDefaults {
        UserDefaults(suiteName: "preview") ?? .standard
    }
}
