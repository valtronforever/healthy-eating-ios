import Foundation
import Testing
@testable import HealthyEating

/// Calm mode hides calories everywhere and follows the server's setting.
@MainActor
struct CalmModeTests {
    private func settings(calm: Bool, targets: [NutrientField: TargetRange]) -> UserSettings {
        UserSettings(timeZone: "Europe/Berlin", energyUnit: .kcal, calmMode: calm, targets: targets)
    }

    @Test func consistencyIsAPlainCount() {
        #expect(TodayView.consistencyLine(6) == "Logged 6 of the last 7 days.")
        #expect(TodayView.consistencyLine(0) == "Logged 0 of the last 7 days.")
    }

    @Test func targetSummaryShowsNoCaloriesInCalmMode() {
        let targets: [NutrientField: TargetRange] = [.calories: TargetRange(min: 1900, max: 2200), .protein: TargetRange(min: 110, max: 140)]
        #expect(SettingsView.targetSummary(settings(calm: false, targets: targets), calm: false).hasSuffix("kcal"))
        let calm = SettingsView.targetSummary(settings(calm: true, targets: targets), calm: true)
        #expect(calm.hasSuffix(" g"))
        #expect(!calm.contains("kcal"))
        // Only a calorie range set: Calm mode does not hint at it.
        let onlyCalories = settings(calm: true, targets: [.calories: TargetRange(min: 1900, max: 2200)])
        #expect(SettingsView.targetSummary(onlyCalories, calm: true) == "Not set")
    }

    @Test func adoptsTheServersSettingWithoutSendingItBack() async throws {
        let defaults = try #require(UserDefaults(suiteName: "CalmModeTests.\(UUID())"))
        let app = AppModel(defaults: defaults, arguments: [AppModel.LaunchArgument.skipOnboarding])
        #expect(!app.calmMode)

        app.adopt(settings(calm: true, targets: [:]))

        #expect(app.calmMode)
        #expect(defaults.bool(forKey: "calmMode"))
        // The sample server still has it off: adopting never writes back.
        let data = try #require(app.data)
        #expect(try await data.settings().calmMode == false)
    }
}
