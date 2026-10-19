import Foundation
import Testing
@testable import HealthyEating

struct NutritionFormatTests {
    private let us = Locale(identifier: "en_US")

    @Test func formatsValuesWithGroupingAndUnitAfterASpace() {
        #expect(NutritionFormat.value(1200, .kcal, locale: us) == "1,200 kcal")
        #expect(NutritionFormat.value(77, .grams, locale: us) == "77 g")
    }

    @Test func formatsRangesWithAnEnDashAndNoSpaces() {
        #expect(NutritionFormat.range(1900, 2200, .kcal, locale: us) == "1,900–2,200 kcal")
        #expect(NutritionFormat.range(110, 140, locale: us) == "110–140")
    }

    @Test func formatsEnergyInThePersonsUnit() {
        #expect(NutritionFormat.energy(1200, in: .kcal, locale: us) == "1,200 kcal")
        #expect(NutritionFormat.energy(1200, in: .kj, locale: us) == "5,021 kJ")
        #expect(NutritionFormat.energyRange(1900, 2200, in: .kj, locale: us) == "7,950–9,205 kJ")
        #expect(NutrientUnit.kilojoules.spokenValue("5,021") == "5,021 kilojoules")
    }

    @Test func targetsMayHaveOpenBounds() {
        #expect(NutritionFormat.target(min: 110, max: 140, .grams, locale: us) == "Target 110–140 g")
        #expect(NutritionFormat.target(min: 110, max: nil, .grams, locale: us) == "Target at least 110 g")
        #expect(NutritionFormat.target(min: nil, max: 80, .grams, locale: us) == "Target up to 80 g")
        #expect(NutritionFormat.target(min: nil, max: nil, .grams, locale: us) == "No target")
        #expect(NutritionFormat.shortTarget(min: 110, max: 140, locale: us) == "110–140")
        #expect(NutritionFormat.spokenTarget(value: 77, min: 110, max: nil, unit: .grams, locale: us)
            == "77 grams, target at least 110 grams")
    }

    @Test func formatsTheMealMacroLine() {
        #expect(NutritionFormat.macroLine(protein: 46, fat: 18, carbs: 62, locale: us) == "P 46 g · F 18 g · C 62 g")
    }

    @Test func spokenRangeMatchesTheVoiceOverCopy() {
        #expect(NutritionFormat.spokenRange(value: 77, min: 110, max: 140, unit: .grams, locale: us)
            == "77 grams, target 110 to 140 grams")
    }

    @Test func relativeTimes() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Berlin"))
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 18, hour: 14, minute: 40)))
        let format = { (seconds: TimeInterval) in
            RelativeTimeFormat.string(for: now.addingTimeInterval(-seconds), now: now, calendar: calendar, locale: Locale(identifier: "en_GB"))
        }
        #expect(format(20) == "just now")
        #expect(format(20 * 60) == "20 min ago")
        #expect(format(2 * 3600) == "2 h ago")
        let yesterdayEvening = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 17, hour: 20, minute: 15)))
        #expect(RelativeTimeFormat.string(for: yesterdayEvening, now: now, calendar: calendar, locale: Locale(identifier: "en_GB"))
            == "yesterday at 20:15")
    }
}

struct SampleDataTests {
    @Test func everyMealCarriesHonestProvenance() {
        for meal in SampleData.meals {
            switch meal.provenance {
            case .estimated: #expect(meal.confidence != nil, "Estimated meals show a confidence")
            case .user: #expect(meal.confidence == nil, "Your numbers show no confidence")
            }
            #expect(!meal.assistant.isEmpty)
        }
    }

    @Test func trendDaysEndToday() {
        for count in [7, 30, 90] {
            let days = SampleData.kcalDays(count: count)
            #expect(days.count == count)
            #expect(Calendar.current.isDateInToday(days.last?.date ?? .distantPast))
            #expect(days.allSatisfy { $0.state != .none || $0.kcal == 0 })
        }
    }
}

struct TrendWordingTests {
    @Test func changesAreLowerHigherOrAboutTheSame() {
        #expect(TrendsView.energyChange(-70, unit: .kcal).hasSuffix("lower"))
        #expect(TrendsView.energyChange(12, unit: .kcal) == "About the same")
        #expect(TrendsView.gramChange(6).hasSuffix("higher"))
        #expect(TrendsView.gramChange(-1.4) == "About the same")
    }
}
