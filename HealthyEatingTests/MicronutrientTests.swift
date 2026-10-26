import Foundation
import Testing
@testable import HealthyEating

struct MicronutrientFormatTests {
    private let locale = Locale(identifier: "en_US")

    @Test func showsSmallAmountsWithDecimals() {
        #expect(NutritionFormat.micronutrient(0.254, .milligrams, locale: locale) == "0.25 mg")
        #expect(NutritionFormat.micronutrient(2.44, .micrograms, locale: locale) == "2.4 µg")
        #expect(NutritionFormat.micronutrient(18.4, .milligrams, locale: locale) == "18 mg")
        #expect(NutritionFormat.micronutrient(1240, .milligrams, locale: locale) == "1,240 mg")
        #expect(NutritionFormat.micronutrient(3, .milligrams, locale: locale) == "3 mg")
    }

    @Test func unitsAndGroupsFollowTheCodes() {
        #expect(Micronutrient.vitaminB12.unit == .micrograms)
        #expect(Micronutrient.iron.unit == .milligrams)
        #expect(Micronutrient.vitamins.count == 11)
        #expect(Micronutrient.minerals == [.calcium, .iron, .magnesium, .phosphorus, .potassium, .zinc, .selenium])
    }

    @Test func dayValuesSayHowManyMealsTheyCover() {
        let day = DayTotals(
            date: .now, mealCount: 3, caloriesKcal: 1200, proteinG: 77, fatG: 32, carbohydratesG: 144,
            estimatedCaloriesShare: nil, status: nil, markedBy: nil, counted: true,
            micronutrients: [.iron: OptionalTotal(amount: 5.3, mealCount: 2), .zinc: OptionalTotal(amount: 4, mealCount: 3)])
        let values = MicronutrientsView.dayValues(day)
        #expect(values[.iron] == MicronutrientValue(amount: 5.3, note: "2 of 3 meals"))
        #expect(values[.zinc] == MicronutrientValue(amount: 4, note: nil))
    }

    @Test func itemSourcesAreNamed() {
        let matched = MealItem(name: "boiled rice", grams: 150, status: .matched, foodDescription: "Rice, cooked, NFS")
        let weak = MealItem(name: "house salad", grams: 50, status: .weak, foodDescription: nil)
        #expect(MealDetailView.itemSource(matched) == "USDA: Rice, cooked, NFS")
        #expect(MealDetailView.itemSource(weak) == "Not found in USDA data, no values")
        #expect(MicronutrientsLink.countLine(1) == "1 value")
    }
}

extension NetworkTests {
    struct MicronutrientAPITests {
        private func api(_ handler: @escaping @Sendable (URLRequest) -> (Int, Data)) throws -> APIClient {
            let server = try ServerAddress.parse("https://food.example.com")
            let session = StubProtocol.session(handler)
            let store = CredentialStore(store: MemoryStore())
            store.save(Credentials(clientID: "c1", accessToken: "a", refreshToken: "r", expiresAt: nil), for: server)
            return APIClient(server: server, auth: AuthSession(server: server, store: store, session: session), session: session)
        }

        @Test func readsMealItemsAndValuesAndSkipsUnknownCodes() async throws {
            let body = """
            {"meals":[{"id":"0b6f3c2e-1111-4000-8000-000000000001","dish_name":"Rice","description":null,
             "eaten_at":"2026-10-26T12:00:00+01:00","local_date":"2026-10-26","portion_grams":null,
             "calories_kcal":200.0,"protein_g":4.0,"fat_g":1.0,"carbohydrates_g":44.0,
             "fiber_g":null,"sugar_g":null,"sodium_mg":null,"source":"estimated_by_assistant","source_note":null,
             "imported_from":null,"micronutrients":{"iron_mg":1.79,"iodine_ug":12.0},
             "items":[{"name":"boiled rice","grams":150.0,"status":"matched","food_description":"Rice, cooked, NFS"}],
             "estimated_fields":[],"confidence":"medium","client_name":"Claude",
             "created_at":"2026-10-26T11:00:00Z","updated_at":"2026-10-26T11:00:00Z"}],"next_cursor":null}
            """
            let api = try api { _ in (200, Data(body.utf8)) }
            let meal = try #require(try await api.meals(from: nil, to: nil).meals.first)
            #expect(meal.micronutrients == [.iron: 1.79])
            #expect(meal.items == [MealItem(name: "boiled rice", grams: 150, status: .matched, foodDescription: "Rice, cooked, NFS")])
        }

        @Test func readsDayTotals() async throws {
            let body = """
            {"days":[{"date":"2026-10-25","meal_count":3,"calories_kcal":1200.0,"protein_g":77.0,"fat_g":32.0,
             "carbohydrates_g":144.0,"fiber_g":null,"sugar_g":null,"sodium_mg":null,
             "micronutrients":{"iron_mg":{"amount":5.3,"meal_count":2}},
             "estimated_calories_share":null,"status":null,"status_set_by":null,"counted":true}],
             "counting_rule":"logged_days"}
            """
            let api = try api { _ in (200, Data(body.utf8)) }
            let day = try #require(try await api.days(from: .now, to: .now).days.first)
            #expect(day.micronutrients == [.iron: OptionalTotal(amount: 5.3, mealCount: 2)])
        }
    }
}
