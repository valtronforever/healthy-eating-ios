import Foundation
import Testing
@testable import HealthyEating

/// The weekly review's copy: facts with their days, in the design's formats, never judging.
struct WeeklyReviewWordingTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }()
    private let english = Locale(identifier: "en_US")

    private func day(_ text: String) -> Date { APIDate.day(text, calendar: calendar)! }

    private func review(
        rule: CountingRule = .completeDays,
        counted: Int = 5,
        leftOut: [(String, WeeklyReview.LeftOutReason)] = [("2026-10-15", .notLogged), ("2026-10-18", .inProgress)],
        weekend: NutrientValues? = NutrientValues(caloriesKcal: 2190, proteinG: 128, fatG: 75, carbohydratesG: 244)
    ) -> WeeklyReview {
        WeeklyReview(
            firstDay: day("2026-10-12"), lastDay: day("2026-10-18"), countingRule: rule,
            loggedDays: 6, completeDays: 5, countedDays: counted,
            averages: NutrientValues(caloriesKcal: 2060, proteinG: 121, fatG: 70, carbohydratesG: 231),
            leftOut: leftOut.map { .init(date: day($0.0), reason: $0.1) },
            weekdays: .init(countedDays: 3, averages: NutrientValues(caloriesKcal: 2010, proteinG: 118, fatG: 68, carbohydratesG: 226)),
            weekend: .init(countedDays: weekend == nil ? 0 : 2, averages: weekend),
            mealCount: 17, proteinPerMealG: 31, proteinBuckets: [], lateMeals: 2,
            estimatedValuesShare: 0.64, lowConfidenceMeals: 3)
    }

    @Test func weekTitlesUseAnEnDashWithoutSpaces() {
        #expect(WeeklyReviewView.weekTitle(first: day("2026-10-12"), last: day("2026-10-18"), calendar: calendar, locale: english) == "Oct 12–18")
        #expect(WeeklyReviewView.weekTitle(first: day("2026-09-28"), last: day("2026-10-04"), calendar: calendar, locale: english) == "Sep 28–Oct 4")
        // Day-first locales keep their order.
        let british = Locale(identifier: "en_GB")
        #expect(WeeklyReviewView.weekTitle(first: day("2026-10-19"), last: day("2026-10-25"), calendar: calendar, locale: british) == "19–25 Oct")
    }

    @Test func daysLineFollowsTheCountingRule() {
        #expect(WeeklyReviewView.daysLine(review()) == "6 of 7 · 5 complete")
        #expect(WeeklyReviewView.daysLine(review(rule: .loggedDays)) == "6 of 7")
    }

    @Test func footnoteNamesTheDaysLeftOut() {
        let text = WeeklyReviewView.averagesFootnote(review(), calendar: calendar, locale: english)
        #expect(text == "Averages use the 5 complete days. Today is still in progress. Thursday was not logged.")

        let several = review(rule: .loggedDays, counted: 3, leftOut: [
            ("2026-10-14", .notLogged), ("2026-10-15", .notLogged), ("2026-10-16", .partial), ("2026-10-18", .future),
        ])
        let text2 = WeeklyReviewView.averagesFootnote(several, calendar: calendar, locale: english)
        #expect(text2.hasPrefix("Averages use 3 of 7 days."))
        #expect(text2.contains("were not logged."))
        #expect(text2.contains("Friday was marked partial."))
        #expect(text2.hasSuffix("The rest of the week is still ahead."))

        let one = review(counted: 1, leftOut: [])
        #expect(WeeklyReviewView.averagesFootnote(one, calendar: calendar, locale: english) == "Averages use the 1 complete day.")

        let none = review(counted: 0, leftOut: [])
        #expect(WeeklyReviewView.averagesFootnote(none, calendar: calendar, locale: english) == "No day counts for the averages yet.")
    }

    @Test func patternsAreFacts() {
        #expect(WeeklyReviewView.proteinLine(review(), locale: english) == "31 g on average across 17 meals")
        #expect(WeeklyReviewView.weekdaysLine(review(), unit: .kcal, calm: false, locale: english) == "2,010 kcal on weekdays, 2,190 on the weekend")
        #expect(WeeklyReviewView.weekdaysLine(review(), unit: .kcal, calm: true, locale: english) == "118 g protein on weekdays, 128 g on the weekend")
        #expect(WeeklyReviewView.weekdaysLine(review(weekend: nil), unit: .kcal, calm: false, locale: english)
            == "Shown once both weekdays and the weekend have counted days")
        #expect(WeeklyReviewView.lateLine(review(), calendar: calendar).hasPrefix("2 of 17 meals after "))
        #expect(WeeklyReviewView.mealsCount(1) == "1 meal")
        #expect(WeeklyReviewView.mealsCount(3) == "3 meals")
    }

    @Test func noJudgment() {
        let all = [
            WeeklyReviewView.averagesFootnote(review(), calendar: calendar, locale: english),
            WeeklyReviewView.proteinLine(review(), locale: english),
            WeeklyReviewView.weekdaysLine(review(), unit: .kcal, calm: false, locale: english),
            WeeklyReviewView.lateLine(review(), calendar: calendar),
        ].joined(separator: " ").lowercased()
        for word in ["good", "bad", "too ", "over", "under", "should", "missed", "forgot"] {
            #expect(!all.contains(word), "\(word)")
        }
    }
}
