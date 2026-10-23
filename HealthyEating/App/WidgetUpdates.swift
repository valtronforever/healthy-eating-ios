import Foundation
import WidgetKit

/// Keeps the widgets' `TodaySnapshot` current (ios#35): written after Today loads, in background
/// refresh and when Calm mode changes; removed on sign-out. Only a changed snapshot reloads the
/// widgets, to stay within WidgetKit's refresh budget.
nonisolated enum WidgetUpdates {
    static func snapshot(
        day: DayTotals?, settings: UserSettings, integration: IntegrationState, now: Date = .now, calendar: Calendar = .current
    ) -> TodaySnapshot {
        let range = { (field: NutrientField) in settings.targets[field].map { TodaySnapshot.Range(min: $0.min, max: $0.max) } }
        return TodaySnapshot(
            day: calendar.startOfDay(for: now), savedAt: now,
            caloriesKcal: day?.caloriesKcal ?? 0, proteinG: day?.proteinG ?? 0, fatG: day?.fatG ?? 0,
            carbohydratesG: day?.carbohydratesG ?? 0,
            calories: range(.calories), protein: range(.protein), fat: range(.fat), carbohydrates: range(.carbohydrates),
            energyUnit: settings.energyUnit, calmMode: settings.calmMode, mealCount: day?.mealCount ?? 0,
            lastMealSavedAt: integration.lastMealSavedAt, lastAssistant: integration.lastAssistant)
    }

    /// Saves it and reloads the widgets when something they show changed.
    static func publish(_ snapshot: TodaySnapshot, storage: any SnapshotStorage = KeychainSnapshotStorage()) {
        var previous = TodaySnapshot.load(from: storage)
        previous?.savedAt = snapshot.savedAt
        snapshot.save(to: storage)
        if previous != snapshot { WidgetCenter.shared.reloadTimelines(ofKind: TodaySnapshot.widgetKind) }
    }

    /// Calm mode changed in Settings: the widgets follow at once.
    static func setCalmMode(_ calm: Bool, storage: any SnapshotStorage = KeychainSnapshotStorage()) {
        guard var snapshot = TodaySnapshot.load(from: storage), snapshot.calmMode != calm else { return }
        snapshot.calmMode = calm
        publish(snapshot, storage: storage)
    }

    /// Signing out: the widgets lose the totals and their token.
    static func clear(
        storage: any SnapshotStorage = KeychainSnapshotStorage(),
        access: any SnapshotStorage = KeychainSnapshotStorage(account: "access")
    ) {
        TodaySnapshot.remove(from: storage)
        WidgetAccess.remove(from: access)
        WidgetCenter.shared.reloadTimelines(ofKind: TodaySnapshot.widgetKind)
    }
}
