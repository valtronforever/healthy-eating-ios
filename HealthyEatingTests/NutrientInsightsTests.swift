import Foundation
import Testing
@testable import HealthyEating

struct NutrientInsightsWordingTests {
    private let locale = Locale(identifier: "en_US")
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin") ?? .gmt
        return calendar
    }

    private func day(_ text: String) throws -> Date {
        try #require(APIDate.day(text, calendar: calendar))
    }

    private func period(average: OptionalAverage? = nil, meals: Int = 0, withValues: Int = 0) throws -> NutrientInsights.Period {
        NutrientInsights.Period(
            firstDay: try day("2026-10-05"), lastDay: try day("2026-10-29"), countedDays: 20, mealCount: meals,
            mealsWithValues: withValues, average: average, rangeDays: nil, weeks: [], foodSources: [], labelSources: [])
    }

    @Test func periodsStartOnAMondayAndEndToday() throws {
        // Thursday 2026-10-29: this week's Monday is Oct 26.
        let today = try day("2026-10-29")
        #expect(InsightsPeriod.fourWeeks.days(today: today, calendar: calendar) == (try day("2026-10-05"), today))
        #expect(InsightsPeriod.twelveWeeks.days(today: today, calendar: calendar).first == (try day("2026-08-10")))
        let year = InsightsPeriod.year.days(today: today, calendar: calendar)
        #expect(year.first == (try day("2025-11-03")))
        // The server takes at most 366 days.
        #expect((calendar.dateComponents([.day], from: year.first, to: year.last).day ?? 0) + 1 <= 366)
    }

    @Test func averageAndThePeriodBeforeArePlainFacts() throws {
        #expect(NutrientInsightsView.perDay(11.64, .milligrams, locale: locale) == "12 mg a day")
        #expect(NutrientInsightsView.perDay(2.44, .micrograms, locale: locale) == "2.4 µg a day")
        let before = try period(average: OptionalAverage(average: 9.8, days: 6))
        #expect(NutrientInsightsView.previousLine(before, period: .fourWeeks, .milligrams, locale: locale) == "Previous 4 weeks: 9.8 mg a day")
        #expect(NutrientInsightsView.previousLine(try period(), period: .year, .milligrams, locale: locale) == "Previous year: no values")
    }

    @Test func belowWithinAndAboveAreWordedAlike() {
        let days = NutrientInsights.RangeDays(below: 8, within: 9, above: 4)
        let both = NutrientInsightsView.rangeRows(days, MicronutrientRange(min: 18, max: 45, source: .reference))
        #expect(both == [
            .init(label: "Below the range", value: "8 of 21 days"),
            .init(label: "Within the range", value: "9 of 21 days"),
            .init(label: "Above the range", value: "4 of 21 days"),
        ])
        // An open bound has no row: nothing can be above a range without an upper bound.
        let atLeast = NutrientInsightsView.rangeRows(.init(below: 2, within: 3, above: 0), MicronutrientRange(min: 50, max: nil, source: .personal))
        #expect(atLeast.map(\.label) == ["Below the range", "Within the range"])
        let upTo = NutrientInsightsView.rangeRows(.init(below: 0, within: 3, above: 1), MicronutrientRange(min: nil, max: 30, source: .personal))
        #expect(upTo.map(\.label) == ["Within the range", "Above the range"])
    }

    @Test func sourcesShowTheirShareAndMeals() {
        #expect(NutrientInsightsView.share(0.3449, locale: locale) == "34%")
        let lentils = NutrientInsights.Source(name: "Lentil soup", amount: 4.44, share: 0.34, meals: 5)
        #expect(NutrientInsightsView.sourceLine(lentils, .milligrams, locale: locale) == "4.4 mg in 5 meals")
        let capsule = NutrientInsights.Source(name: "Vitamin D3", amount: 50, share: 0.8, meals: 1)
        #expect(NutrientInsightsView.sourceLine(capsule, .micrograms, locale: locale) == "50 µg in 1 meal")
    }

    @Test func aWeekWithFewDaysIsLighterAndSaysSo() throws {
        let today = try day("2026-10-29")
        let past = NutrientInsights.Week(firstDay: try day("2026-10-19"), lastDay: try day("2026-10-25"), average: 12, days: 3)
        #expect(NutrientInsightsView.weekDaysLine(past, today: today, calendar: calendar) == "3 of 7 days")
        #expect(NutrientInsightsView.isSparse(past, today: today, calendar: calendar))
        // This week counts only up to today: 2 of 4 days is half, not fewer.
        let current = NutrientInsights.Week(firstDay: try day("2026-10-26"), lastDay: try day("2026-11-01"), average: 10, days: 2)
        #expect(NutrientInsightsView.weekDaysLine(current, today: today, calendar: calendar) == "2 of 4 days")
        #expect(!NutrientInsightsView.isSparse(current, today: today, calendar: calendar))
    }

    @Test func coverageSaysHowManyMealsHaveValues() throws {
        #expect(NutrientInsightsView.coverageLine(try period(meals: 52, withValues: 34))
            == "Values for 34 of 52 meals. Meals without food items have no vitamin or mineral values.")
        #expect(NutrientInsightsView.coverageLine(try period()) == "No meals in these weeks.")
    }

    @Test func aHighUpperBoundDoesNotFlattenTheBars() throws {
        let weeks = [NutrientInsights.Week(firstDay: try day("2026-10-19"), lastDay: try day("2026-10-25"), average: 60, days: 5)]
        #expect(WeeklyNutrientChart.scaleMax(weeks, range: MicronutrientRange(min: 75, max: 2000, source: .reference)) == 93.75)
        #expect(WeeklyNutrientChart.scaleMax(weeks, range: nil) == 75)
        #expect(WeeklyNutrientChart.scaleMax([], range: nil) == 1)
    }
}

extension NetworkTests {
    struct NutrientInsightsAPITests {
        private func api(_ handler: @escaping @Sendable (URLRequest) -> (Int, Data)) throws -> APIClient {
            let server = try ServerAddress.parse("https://food.example.com")
            let session = StubProtocol.session(handler)
            let store = CredentialStore(store: MemoryStore())
            store.save(Credentials(clientID: "c1", accessToken: "a", refreshToken: "r", expiresAt: nil), for: server)
            return APIClient(server: server, auth: AuthSession(server: server, store: store, session: session), session: session)
        }

        @Test func asksForOneNutrientAndReadsBothPeriods() async throws {
            let body = """
            {"counting_rule":"logged_days",
             "ranges":{"iron_mg":{"min":18.0,"max":45.0,"source":"reference"}},
             "current":{"first_day":"2026-10-05","last_day":"2026-10-29","counted_days":18,"meal_count":52,
              "meals_with_values":34,"nutrients":{"iron_mg":{"average":{"average":11.6,"days":12},
              "range_days":{"below":9,"within":3,"above":0},
              "weeks":[{"first_day":"2026-10-05","last_day":"2026-10-11","average":10.5,"days":3},
                       {"first_day":"2026-10-12","last_day":"2026-10-18","average":null,"days":0}],
              "food_sources":[{"name":"Lentil soup","amount":40.2,"share":0.34,"meals":5}],
              "label_sources":[{"name":"Iron tablet","amount":28.0,"share":0.24,"meals":2}]}}},
             "previous":{"first_day":"2026-09-10","last_day":"2026-10-04","counted_days":0,"meal_count":0,
              "meals_with_values":0,"nutrients":{}}}
            """
            let api = try api { _ in (200, Data(body.utf8)) }
            let from = try #require(APIDate.day("2026-10-05", calendar: api.calendar))
            let to = try #require(APIDate.day("2026-10-29", calendar: api.calendar))

            let insights = try await api.nutrientInsights(.iron, from: from, to: to)

            let url = try #require(StubProtocol.requests.last?.url)
            #expect(url.path() == "/api/v1/micronutrients/insights")
            let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            #expect(query.contains(URLQueryItem(name: "from", value: "2026-10-05")))
            #expect(query.contains(URLQueryItem(name: "to", value: "2026-10-29")))
            #expect(query.contains(URLQueryItem(name: "nutrient", value: "iron_mg")))
            #expect(insights.range == MicronutrientRange(min: 18, max: 45, source: .reference))
            #expect(insights.current.average == OptionalAverage(average: 11.6, days: 12))
            #expect(insights.current.rangeDays == .init(below: 9, within: 3, above: 0))
            #expect(insights.current.weeks.map(\.average) == [10.5, nil])
            #expect(insights.current.foodSources.map(\.name) == ["Lentil soup"])
            #expect(insights.current.labelSources.first?.meals == 2)
            #expect((insights.current.mealsWithValues, insights.current.mealCount) == (34, 52))
            // The period before has no iron: no average, weeks or sources.
            #expect(!insights.previous.hasValues)
            #expect(insights.previous.weeks.isEmpty)
        }
    }
}
