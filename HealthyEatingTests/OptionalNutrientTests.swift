import Foundation
import Testing
@testable import HealthyEating

/// Fiber, sugar and sodium: shown only when present, and a partial value says what it covers.
struct OptionalNutrientTests {
    private let english = Locale(identifier: "en_US")

    @Test func dayLineNamesWhatEachValueCovers() {
        let totals: [OptionalNutrient: OptionalTotal] = [
            .fiber: .init(amount: 14, mealCount: 3), .sugar: .init(amount: 26, mealCount: 2),
            .sodium: .init(amount: 1820, mealCount: 1),
        ]
        #expect(OptionalNutrientsLine.text(totals, mealCount: 3, locale: english)
            == "Fiber 14 g · Sugar 26 g (2 of 3 meals) · Sodium 1,820 mg (1 of 3 meals)")
        #expect(OptionalNutrientsLine.text([:], mealCount: 3, locale: english) == nil)
    }

    @Test func trendsSayHowManyDaysHaveAValue() {
        #expect(OptionalAveragesCard.daysLine(.init(average: 21, days: 18), countedDays: 18) == "average of 18 days")
        #expect(OptionalAveragesCard.daysLine(.init(average: 9, days: 1), countedDays: 1) == "average of 1 day")
        #expect(OptionalAveragesCard.daysLine(.init(average: 2100, days: 9), countedDays: 18) == "on 9 of 18 counted days")
    }

    @Test func anEstimatedOptionalValueMakesTheMealEstimated() {
        var meal = SampleData.meals[0]
        #expect(meal.provenance == .user)
        meal.estimatedOptional = [.fiber]
        #expect(meal.provenance == .estimated)
    }

    @Test func sodiumIsInMilligrams() {
        #expect(OptionalNutrient.sodium.unit == .milligrams)
        #expect(NutritionFormat.value(820, .milligrams, locale: english) == "820 mg")
    }
}
