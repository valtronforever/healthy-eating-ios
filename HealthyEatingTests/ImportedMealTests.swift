import Foundation
import Testing
@testable import HealthyEating

struct ImportedMealTests {
    private func meal(note: String?, importedFrom: String?) -> Meal {
        Meal(
            id: UUID(), eatenAt: .now, dishName: "Day total", caloriesKcal: 2100, proteinG: 110, fatG: 80,
            carbohydratesG: 230, portionGrams: nil, estimatedFields: [], confidence: nil, assistant: "ChatGPT",
            sourceNote: note, importedFrom: importedFrom)
    }

    @Test func namesWhereAnImportedMealCameFrom() {
        #expect(MealDetailView.importedLine(meal(note: nil, importedFrom: "ChatGPT project")) == "Imported from ChatGPT project")
        #expect(MealDetailView.importedLine(meal(note: "Nutrition label", importedFrom: nil)) == nil)
    }

    @Test func doesNotRepeatTheSourceInTheNote() {
        #expect(MealDetailView.shownNote(meal(note: "ChatGPT project", importedFrom: "ChatGPT project")) == nil)
        #expect(MealDetailView.shownNote(meal(note: "Weighed portions", importedFrom: "Google Sheets")) == "Weighed portions")
        #expect(MealDetailView.shownNote(meal(note: "Nutrition label", importedFrom: nil)) == "Nutrition label")
    }
}

extension NetworkTests {
    struct ImportedMealAPITests {
        private func api(_ handler: @escaping @Sendable (URLRequest) -> (Int, Data)) throws -> APIClient {
            let server = try ServerAddress.parse("https://food.example.com")
            let session = StubProtocol.session(handler)
            let store = CredentialStore(store: MemoryStore())
            store.save(Credentials(clientID: "c1", accessToken: "a", refreshToken: "r", expiresAt: nil), for: server)
            return APIClient(server: server, auth: AuthSession(server: server, store: store, session: session), session: session)
        }

        private func mealJSON(_ importedFrom: String) -> String {
            """
            {"id":"0b6f3c2e-1111-4000-8000-000000000001","dish_name":"Day total","description":null,
             "eaten_at":"2026-09-02T12:00:00+02:00","local_date":"2026-09-02","portion_grams":null,
             "calories_kcal":2100.0,"protein_g":110.0,"fat_g":80.0,"carbohydrates_g":230.0,
             "fiber_g":null,"sugar_g":null,"sodium_mg":null,
             "source":"from_conversation","source_note":"ChatGPT project",\(importedFrom)
             "estimated_fields":["protein_g"],"confidence":"low","client_name":"ChatGPT",
             "created_at":"2026-10-26T06:10:01Z","updated_at":"2026-10-26T06:10:01Z"}
            """
        }

        @Test func readsWhereAMealWasImportedFrom() async throws {
            let body = mealJSON(#""imported_from":"ChatGPT project","#)
            let api = try api { _ in (200, Data(#"{"meals":[\#(body)],"next_cursor":null}"#.utf8)) }
            let meals = try await api.meals(from: nil, to: nil).meals
            #expect(meals.first?.importedFrom == "ChatGPT project")
        }

        @Test func serversWithoutTheFieldMeanNotImported() async throws {
            let body = mealJSON("")
            let api = try api { _ in (200, Data(#"{"meals":[\#(body)],"next_cursor":null}"#.utf8)) }
            let meals = try await api.meals(from: nil, to: nil).meals
            #expect(meals.first?.importedFrom == nil)
        }
    }
}
