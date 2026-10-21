import Foundation

/// Sample data from the design system boards (design/system). The backend has no meal or
/// statistics REST endpoints yet, so the data screens and previews use these values.
/// Replace with API data once `/api/v1` serves meals and statistics; do not add logic here.
nonisolated enum SampleData {
    static var calendar: Calendar { .current }

    static func today(at hour: Int, _ minute: Int, now: Date = .now) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now) ?? now
    }

    // MARK: Today (B1)

    static let meals: [Meal] = [
        Meal(
            id: UUID(uuidString: "6F1A3C2E-0000-4000-8000-000000000001") ?? UUID(),
            eatenAt: today(at: 8, 10), dishName: "Oatmeal with berries",
            caloriesKcal: 380, proteinG: 14, fatG: 9, carbohydratesG: 58, portionGrams: 320,
            provenance: .user, confidence: nil, assistant: "ChatGPT", sourceNote: nil,
            optional: [.fiber: 8]),
        Meal(
            id: UUID(uuidString: "6F1A3C2E-0000-4000-8000-000000000002") ?? UUID(),
            eatenAt: today(at: 12, 40), dishName: "Chicken with rice and salad",
            caloriesKcal: 610, proteinG: 46, fatG: 18, carbohydratesG: 62, portionGrams: 350,
            provenance: .estimated, confidence: .medium, assistant: "Claude",
            sourceNote: "Claude estimated all values from a photo. Portion size and cooking oil were not stated.",
            optional: [.fiber: 6, .sugar: 4, .sodium: 820]),
        Meal(
            id: UUID(uuidString: "6F1A3C2E-0000-4000-8000-000000000003") ?? UUID(),
            eatenAt: today(at: 16, 5), dishName: "Greek yogurt with honey",
            caloriesKcal: 210, proteinG: 17, fatG: 5, carbohydratesG: 24, portionGrams: 200,
            provenance: .estimated, confidence: .high, assistant: "Claude",
            sourceNote: "Claude estimated the values from the description.",
            optional: [.sugar: 22]),
    ]

    static let kcalSoFar: Double = 1200
    static let kcalTarget = TargetRange(min: 1900, max: 2200)

    static let macros: [MacroProgress] = [
        MacroProgress(macro: .protein, value: 77, min: 110, max: 140),
        MacroProgress(macro: .fat, value: 32, min: 55, max: 80),
        MacroProgress(macro: .carbs, value: 144, min: 200, max: 260),
    ]

    static let lastSavedAt: Date = Date.now.addingTimeInterval(-2 * 3600)
    static let lastSavedVia = "Claude"
    static let exampleServer = "https://food.example.com"

    // MARK: History (C1)

    private static let monthPattern: [DayState] = [
        .complete, .complete, .none, .partial, .complete, .complete, .complete, .partial, .complete,
        .none, .none, .complete, .complete, .partial, .complete, .complete, .complete, .partial,
    ]

    /// The board's state for a past day of any month, by its day number.
    static func pastState(dayOfMonth day: Int) -> DayState {
        monthPattern[(day - 1) % monthPattern.count]
    }

    /// Day states for the month containing `now`: days after today are `future`, today is partial.
    static func monthStates(now: Date = .now) -> [Int: DayState] {
        let todayDay = calendar.component(.day, from: now)
        guard let range = calendar.range(of: .day, in: .month, for: now) else { return [:] }
        var states: [Int: DayState] = [:]
        for day in range {
            if day > todayDay {
                states[day] = .future
            } else if day == todayDay {
                states[day] = .partial
            } else {
                states[day] = monthPattern[(day - 1) % monthPattern.count]
            }
        }
        return states
    }

    /// Summary of one logged day, as the History day card shows it.
    struct DaySummary: Sendable {
        var kcal: Double
        var mealCount: Int
        var estimatedCount: Int
        var proteinG: Double
        var fatG: Double
        var carbohydratesG: Double
    }

    static func daySummary(day: Int) -> DaySummary {
        let offset = Double((day * 37) % 9)
        return DaySummary(
            kcal: 1880 + offset * 40, mealCount: 3 + day % 2, estimatedCount: 2 + day % 2,
            proteinG: 112 + offset * 2, fatG: 64 + offset, carbohydratesG: 214 + offset * 3)
    }

    // MARK: Trends (D1)

    private static let kcal30: [Double] = [
        2120, 1980, 1150, 0, 2240, 1910, 2060, 1320, 2150, 0, 1890, 2010, 980, 2180, 2070,
        0, 1950, 2230, 1410, 2040, 0, 2110, 1220, 1960, 2090, 0, 1080, 2000, 2120, 1200,
    ]
    private static let notLogged: Set<Int> = [3, 9, 15, 20, 25]
    private static let partial: Set<Int> = [2, 7, 12, 18, 22, 26, 29]

    /// The last `count` days ending today, repeating the 30-day board pattern.
    static func kcalDays(count: Int, now: Date = .now) -> [KcalDay] {
        let start = calendar.startOfDay(for: now)
        return (0..<count).map { position in
            let index = (position + 30 * 3 - count) % 30
            let date = calendar.date(byAdding: .day, value: position - count + 1, to: start) ?? start
            let state: DayState = notLogged.contains(index) ? .none : partial.contains(index) ? .partial : .complete
            return KcalDay(date: date, kcal: state == .none ? 0 : kcal30[index], state: state)
        }
    }

    struct TrendSummary: Sendable {
        var days: [KcalDay]
        var averageKcal: Double
        var completeDays: Int
        var macroAverages: [MacroProgress]
        /// Differences to the previous period, already worded by the backend.
        var comparisons: [(label: String, value: String)]
    }

    /// Precomputed trend values. On the real API the backend computes averages; the sample
    /// values for 30 days match the D1 board.
    static func trend(days count: Int, now: Date = .now) -> TrendSummary {
        let days = kcalDays(count: count, now: now)
        let complete = days.filter { $0.state == .complete }
        let average = count == 30 ? 2040 : (complete.map(\.kcal).reduce(0, +) / Double(max(complete.count, 1))).rounded()
        return TrendSummary(
            days: days,
            averageKcal: average,
            completeDays: count == 30 ? 18 : complete.count,
            macroAverages: [
                MacroProgress(macro: .protein, value: 118, min: 110, max: 140),
                MacroProgress(macro: .fat, value: 71, min: 55, max: 80),
                MacroProgress(macro: .carbs, value: 228, min: 200, max: 260),
            ],
            comparisons: [
                (String(localized: "Calories"), String(localized: "70 kcal lower")),
                (Macro.protein.name, String(localized: "6 g higher")),
                (Macro.fat.name, String(localized: "About the same")),
                (Macro.carbs.name, String(localized: "11 g lower")),
            ])
    }

    // MARK: Weight (D3)

    static let weightPoints: [WeightPoint] = {
        let raw: [Double?] = [
            79.6, nil, 79.4, 79.5, nil, 79.1, 79.3, 79.2, nil, 79.0, 79.2, nil, 78.9, 79.0,
            78.8, nil, 78.9, 78.7, nil, 78.8, 78.5, 78.7, nil, 78.6, 78.4, 78.6, nil, 78.4,
        ]
        var trend = 79.45
        return raw.enumerated().map { index, value in
            if let value { trend += (value - trend) * 0.22 }
            trend = Swift.max(78.4, trend - 0.018)
            return WeightPoint(index: index, raw: value, trend: index == raw.count - 1 ? 78.4 : trend)
        }
    }()
}
