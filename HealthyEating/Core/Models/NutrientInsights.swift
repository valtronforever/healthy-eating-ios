import Foundation

/// One vitamin or mineral over a period and the period of the same length before it
/// (`GET /api/v1/micronutrients/insights`, backend #36). The server computes every number; a
/// period without any value for the nutrient has no average, weeks or sources.
nonisolated struct NutrientInsights: Sendable, Equatable {
    var nutrient: Micronutrient
    /// The range that applies now: the person's goal, else their life stage's reference.
    var range: MicronutrientRange?
    var current: Period
    var previous: Period

    struct Period: Sendable, Equatable {
        var firstDay: Date
        var lastDay: Date
        var countedDays: Int
        var mealCount: Int
        /// Meals with vitamin and mineral values (meals with food items).
        var mealsWithValues: Int
        /// Over the counted days on which every meal has a value.
        var average: OptionalAverage?
        /// On the days the average uses; nil without a range.
        var rangeDays: RangeDays?
        /// Monday to Sunday, cut to the period; empty without values.
        var weeks: [Week]
        var foodSources: [Source]
        /// Items with label values: supplements and packaged foods.
        var labelSources: [Source]

        var hasValues: Bool { average != nil || !foodSources.isEmpty || !labelSources.isEmpty }
    }

    struct Week: Sendable, Equatable, Identifiable {
        var firstDay: Date
        var lastDay: Date
        var average: Double?
        /// The days the average uses.
        var days: Int

        var id: Date { firstDay }
    }

    struct RangeDays: Sendable, Equatable {
        var below: Int
        var within: Int
        var above: Int

        var total: Int { below + within + above }
    }

    struct Source: Sendable, Equatable, Identifiable {
        var name: String
        var amount: Double
        /// Of all items' amounts of the nutrient in the period (0 to 1).
        var share: Double
        var meals: Int

        var id: String { name }
    }
}

/// The insights screen's periods, each ending today and starting on a Monday.
nonisolated enum InsightsPeriod: String, CaseIterable, Identifiable, Sendable {
    case fourWeeks, twelveWeeks, year

    var id: Self { self }

    var weeks: Int {
        switch self {
        case .fourWeeks: 4
        case .twelveWeeks: 12
        case .year: 52
        }
    }

    var name: String {
        switch self {
        case .fourWeeks: String(localized: "4 weeks")
        case .twelveWeeks: String(localized: "12 weeks")
        case .year: String(localized: "Year")
        }
    }

    /// The Monday `weeks - 1` weeks before this week's Monday, and today.
    func days(today: Date, calendar: Calendar = .current) -> (first: Date, last: Date) {
        let last = calendar.startOfDay(for: today)
        let sinceMonday = (calendar.component(.weekday, from: last) + 5) % 7
        let monday = calendar.date(byAdding: .day, value: -sinceMonday, to: last) ?? last
        let first = calendar.date(byAdding: .day, value: -7 * (weeks - 1), to: monday) ?? monday
        return (first, last)
    }
}
