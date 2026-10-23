import Foundation
import Testing
@testable import HealthyEating

struct UsualMealsWordingTests {
    private let meal = Meal(
        id: UUID(), eatenAt: .now, dishName: "Oatmeal with berries", caloriesKcal: 380, proteinG: 14, fatG: 9,
        carbohydratesG: 58, portionGrams: nil, estimatedFields: [], confidence: nil, assistant: "ChatGPT", sourceNote: nil)
    private let locale = Locale(identifier: "en_US")

    @Test func showsEnergyAndMacros() {
        #expect(UsualMealsView.valuesLine(meal, energyUnit: .kcal, calm: false, locale: locale) == "380 kcal · P 14 g · F 9 g · C 58 g")
    }

    @Test func calmModeLeavesEnergyOut() {
        #expect(UsualMealsView.valuesLine(meal, energyUnit: .kcal, calm: true, locale: locale) == "P 14 g · F 9 g · C 58 g")
    }

    @Test func saysHowOften() {
        #expect(UsualMealsView.timesLine(3) == "3 times in the last 90 days")
    }
}

extension NetworkTests {
    struct UsualMealsAPITests {
        private let mealJSON = """
        {"id":"0b6f3c2e-1111-4000-8000-000000000001","dish_name":"Oatmeal","description":null,
         "eaten_at":"2026-10-22T08:10:00+02:00","local_date":"2026-10-22","portion_grams":null,
         "calories_kcal":380.0,"protein_g":14.0,"fat_g":9.0,"carbohydrates_g":58.0,
         "fiber_g":null,"sugar_g":null,"sodium_mg":null,
         "source":"from_conversation","source_note":null,"estimated_fields":["fat_g"],
         "confidence":"high","client_name":"ChatGPT",
         "created_at":"2026-10-22T06:10:01Z","updated_at":"2026-10-22T06:10:01Z"}
        """

        private func api(_ handler: @escaping @Sendable (URLRequest) -> (Int, Data)) throws -> APIClient {
            let server = try ServerAddress.parse("https://food.example.com")
            let session = StubProtocol.session(handler)
            let store = CredentialStore(store: MemoryStore())
            store.save(Credentials(clientID: "c1", accessToken: "a", refreshToken: "r", expiresAt: nil), for: server)
            return APIClient(server: server, auth: AuthSession(server: server, store: store, session: session), session: session)
        }

        @Test func mapsUsualMeals() async throws {
            let meal = mealJSON
            let api = try api { _ in (200, Data(#"{"meals":[{"meal":\#(meal),"times":3}]}"#.utf8)) }
            let usual = try await api.usualMeals()
            #expect(StubProtocol.requests.last?.url?.path() == "/api/v1/usual-meals")
            #expect(usual.map(\.times) == [3])
            #expect(usual.first?.meal.dishName == "Oatmeal")
            #expect(usual.first?.meal.estimatedFields == [.fat])
        }

        @Test func relogSendsTheNewIDAndTime() async throws {
            let meal = mealJSON
            let api = try api { _ in (201, Data(meal.utf8)) }
            let original = try #require(UUID(uuidString: "0B6F3C2E-1111-4000-8000-000000000001"))
            let newID = try #require(UUID(uuidString: "0B6F3C2E-2222-4000-8000-000000000002"))

            _ = try await api.relog(original, as: newID, at: Date(timeIntervalSince1970: 1_792_700_000))

            let request = try #require(StubProtocol.requests.last)
            #expect(request.httpMethod == "POST")
            #expect(request.url?.path() == "/api/v1/meals/0b6f3c2e-1111-4000-8000-000000000001/relog")
            let body = try #require(JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: Any])
            #expect(body["id"] as? String == "0b6f3c2e-2222-4000-8000-000000000002")
            #expect(body["eaten_at"] is String)
        }
    }
}
