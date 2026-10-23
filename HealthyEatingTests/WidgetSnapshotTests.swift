import Foundation
import Testing
@testable import HealthyEating

struct WidgetSnapshotTests {
    private let locale = Locale(identifier: "en_US")

    private func snapshot(calm: Bool = false, unit: EnergyUnit = .kcal, day: Date = Calendar.current.startOfDay(for: .now)) -> TodaySnapshot {
        TodaySnapshot(
            day: day, savedAt: .now, caloriesKcal: 1200, proteinG: 77, fatG: 32, carbohydratesG: 144,
            calories: .init(min: 1900, max: 2200), protein: .init(min: 110, max: 140), fat: nil,
            carbohydrates: .init(min: 200, max: nil), energyUnit: unit, calmMode: calm, mealCount: 3,
            lastMealSavedAt: .now, lastAssistant: "Claude")
    }

    @Test func showsTheF1Numbers() {
        let today = snapshot()
        #expect(today.energy(locale: locale) == "1,200")
        #expect(today.energyCaption(locale: locale) == "kcal · 1,900–2,200")
        #expect(today.lockScreenHeadline(locale: locale) == "1,200 kcal · P 77 g")
        #expect(today.lockScreenDetail(locale: locale) == "F 32 g · C 144 g")
    }

    @Test func kilojoulesAreADisplayConversion() {
        let today = snapshot(unit: .kj)
        #expect(today.energy(locale: locale) == "5,021")
        #expect(today.energyCaption(locale: locale) == "kJ · 7,950–9,205")
    }

    @Test func calmModeLeavesCaloriesOut() {
        let calm = snapshot(calm: true)
        #expect(calm.lockScreenHeadline(locale: locale) == "P 77 g · F 32 g")
        #expect(calm.lockScreenDetail(locale: locale) == "C 144 g")
        #expect(!calm.lockScreenHeadline(locale: locale).contains("kcal"))
    }

    @Test func rangesMayBeOpen() {
        #expect(TodaySnapshot.range(.init(min: 200, max: nil), locale: locale) == "from 200")
        #expect(TodaySnapshot.range(.init(min: nil, max: 80), locale: locale) == "up to 80")
        #expect(TodaySnapshot.range(.init(min: nil, max: nil), locale: locale) == nil)
    }

    @Test func overAndUnderUseTheSameScale() {
        let range = TodaySnapshot.Range(min: 110, max: 140)
        #expect(TodaySnapshot.scale(77, range) == 182)
        #expect(TodaySnapshot.scale(200, range) == 200, "a value past the track just fills it")
        #expect(TodaySnapshot.scale(50, nil) == 65)
    }

    @Test func yesterdaysSnapshotIsNotCurrent() throws {
        let yesterday = try #require(Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: .now)))
        #expect(snapshot().isCurrent())
        #expect(!snapshot(day: yesterday).isCurrent())
    }

    @Test func publishingKeepsItForTheWidgetsAndSignOutRemovesIt() throws {
        let storage = MemorySnapshotStorage()
        WidgetUpdates.publish(snapshot(), storage: storage)
        #expect(TodaySnapshot.load(from: storage)?.proteinG == 77)
        WidgetUpdates.setCalmMode(true, storage: storage)
        #expect(TodaySnapshot.load(from: storage)?.calmMode == true)
        WidgetUpdates.clear(storage: storage)
        #expect(TodaySnapshot.load(from: storage) == nil)
    }

    @Test func snapshotsComeFromTheDayAndSettings() {
        let settings = UserSettings(
            timeZone: nil, energyUnit: .kcal, calmMode: false,
            targets: [.calories: TargetRange(min: 1900, max: 2200), .protein: TargetRange(min: 110, max: nil)])
        let integration = IntegrationState(lastMealSavedAt: nil, lastAssistant: nil, mealsToday: 0)
        let empty = WidgetUpdates.snapshot(day: nil, settings: settings, integration: integration)
        #expect(empty.caloriesKcal == 0)
        #expect(empty.mealCount == 0)
        #expect(empty.calories == .init(min: 1900, max: 2200))
        #expect(empty.protein == .init(min: 110, max: nil))
        #expect(empty.fat == nil)
    }
}
