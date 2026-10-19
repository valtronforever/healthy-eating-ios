import Foundation
import Testing
@testable import HealthyEating

private let server = try! ServerAddress.parse("https://food.example.com")

private let metadataJSON = Data("""
{"issuer":"https://food.example.com/","authorization_endpoint":"https://food.example.com/authorize",
 "token_endpoint":"https://food.example.com/token","registration_endpoint":"https://food.example.com/register",
 "revocation_endpoint":"https://food.example.com/revoke"}
""".utf8)

private let mealJSON = """
{"id":"0b6f3c2e-1111-4000-8000-000000000001","dish_name":"Borscht","description":null,
 "eaten_at":"2026-10-18T13:00:00+02:00","local_date":"2026-10-18","portion_grams":null,
 "calories_kcal":412.0,"protein_g":14.0,"fat_g":24.0,"carbohydrates_g":36.0,
 "source":"from_conversation","source_note":"Google Sheets log","estimated_fields":["protein_g","fat_g"],
 "confidence":"medium","client_name":null,
 "created_at":"2026-10-18T11:00:01.123456+00:00","updated_at":"2026-10-18T11:00:01.123456+00:00"}
"""

private func client(_ handler: @escaping @Sendable (URLRequest) -> (Int, Data), accessToken: String = "access-1") -> (APIClient, CredentialStore) {
    let session = StubProtocol.session(handler)
    let store = CredentialStore(store: MemoryStore())
    store.save(Credentials(clientID: "c1", accessToken: accessToken, refreshToken: "refresh-1", expiresAt: nil), for: server)
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
    return (APIClient(server: server, auth: AuthSession(server: server, store: store, session: session), session: session, calendar: calendar), store)
}

private func json(_ text: String) -> Data { Data(text.utf8) }

struct APIDateTests {
    @Test func parsesPythonTimestamps() throws {
        let micro = try #require(APIDate.parse("2026-10-18T11:00:01.123456+00:00"))
        #expect(abs(micro.timeIntervalSince1970 - 1_792_321_201.123) < 0.001)
        #expect(APIDate.parse("2026-10-18T13:00:00+02:00") == APIDate.parse("2026-10-18T11:00:00Z"))
        #expect(APIDate.parse("2026-10-18T11:00:00.5Z") != nil)
        #expect(APIDate.parse("yesterday") == nil)
    }

    @Test func localDaysRoundTrip() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        let day = try #require(APIDate.day("2026-10-18", calendar: calendar))
        #expect(APIDate.dayString(day, calendar: calendar) == "2026-10-18")
        #expect(APIDate.day("18.10.2026", calendar: calendar) == nil)
    }
}

extension NetworkTests {
struct APIClientTests {
    @Test func mapsMealsWithPerFieldProvenance() async throws {
        let (api, _) = client { request in
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer access-1")
            return (200, json(#"{"meals":[\#(mealJSON)],"next_cursor":"abc"}"#))
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Berlin"))
        let day = try #require(APIDate.day("2026-10-18", calendar: calendar))

        let page = try await api.meals(from: day, to: day)

        let meal = try #require(page.meals.first)
        #expect(page.nextCursor == "abc")
        #expect(meal.dishName == "Borscht")
        #expect(meal.estimatedFields == [.protein, .fat])
        #expect(meal.provenance == .estimated)
        #expect(meal.confidence == .medium)
        #expect(meal.assistant == "your AI assistant")
        #expect(meal.eatenAt == APIDate.parse("2026-10-18T11:00:00Z"))
        let query = try #require(StubProtocol.requests.last?.url?.query())
        #expect(query.contains("from=2026-10-18") && query.contains("to=2026-10-18"))
    }

    @Test func refreshesOnceAfterA401AndRetries() async throws {
        let (api, store) = client { request in
            switch request.url?.path() {
            case "/.well-known/oauth-authorization-server": return (200, metadataJSON)
            case "/token": return (200, json(#"{"access_token":"access-2","refresh_token":"refresh-2","expires_in":3600}"#))
            default:
                let token = request.value(forHTTPHeaderField: "Authorization")
                return token == "Bearer access-2"
                    ? (200, json(#"{"last_meal_saved_at":null,"last_client_name":null,"meals_today":2}"#))
                    : (401, json(#"{"code":"unauthorized","message":"Invalid or expired access token","details":[]}"#))
            }
        }
        let status = try await api.integrationStatus()
        #expect(status.mealsToday == 2)
        #expect(StubProtocol.requests.filter { $0.url?.path() == "/token" }.count == 1)
        #expect(store.credentials(for: server)?.accessToken == "access-2")
    }

    @Test func aSecond401EndsTheSession() async {
        let (api, _) = client { request in
            switch request.url?.path() {
            case "/.well-known/oauth-authorization-server": (200, metadataJSON)
            case "/token": (200, json(#"{"access_token":"access-2","expires_in":3600}"#))
            default: (401, json(#"{"code":"unauthorized","message":"no","details":[]}"#))
            }
        }
        await #expect(throws: APIError.sessionExpired) { try await api.integrationStatus() }
    }

    @Test func mapsErrorResponses() async {
        let (notFound, _) = client { _ in (404, json(#"{"code":"not_found","message":"Meal not found","details":[]}"#)) }
        await #expect(throws: APIError.notFound) { try await notFound.meal(UUID()) }

        let (invalid, _) = client { _ in
            (422, json(#"{"code":"invalid_request","message":"The request is not valid","details":[{"field":"protein_g","message":"Input should be greater than or equal to 0"}]}"#))
        }
        await #expect(throws: APIError.invalid(message: "The request is not valid", fields: ["protein_g": "Input should be greater than or equal to 0"])) {
            try await invalid.update(UUID(), with: .init(proteinG: -1))
        }

        let (broken, _) = client { _ in (500, Data("Internal Server Error".utf8)) }
        do {
            _ = try await broken.integrationStatus()
            Issue.record("expected an error")
        } catch {
            #expect(error == .server(code: "500", message: HTTPURLResponse.localizedString(forStatusCode: 500)))
        }
    }

    @Test func mealEditsSendOnlyChangedFieldsAndCanRemoveThePortion() async throws {
        let (api, _) = client { _ in (200, json(#"{"meal":\#(mealJSON),"warnings":["Calories do not match"]}"#)) }
        let result = try await api.update(UUID(), with: .init(dishName: "Soup", portionGrams: .some(nil), caloriesKcal: 400))
        #expect(result.warnings == ["Calories do not match"])
        let request = try #require(StubProtocol.requests.last)
        #expect(request.httpMethod == "PATCH")
        let body = try #require(JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: Any])
        #expect(Set(body.keys) == ["dish_name", "portion_grams", "calories_kcal"])
        #expect(body["portion_grams"] is NSNull)
    }

    @Test func settingsChangesCanClearTheTimeZoneAndATarget() async throws {
        let (api, _) = client { _ in
            (200, json(#"{"timezone":null,"energy_unit":"kj","calm_mode":false,"targets":{"calories_kcal":{"min":1800,"max":2200},"protein_g":null,"fat_g":null,"carbohydrates_g":null}}"#))
        }
        let settings = try await api.updateSettings(.init(timeZone: .some(nil), energyUnit: .kj, targets: [.protein: nil]))
        #expect(settings.energyUnit == .kj)
        #expect(settings.targets == [.calories: TargetRange(min: 1800, max: 2200)])
        let body = try #require(JSONSerialization.jsonObject(with: StubProtocol.requests.last?.httpBody ?? Data()) as? [String: Any])
        #expect(body["timezone"] is NSNull)
        #expect(body["energy_unit"] as? String == "kj")
        #expect((body["targets"] as? [String: Any])?["protein_g"] is NSNull)
    }

    @Test func mapsDaysToTheDeviceCalendar() async throws {
        let (api, _) = client { _ in
            (200, json("""
            {"days":[
              {"date":"2026-10-17","meal_count":0,"calories_kcal":0,"protein_g":0,"fat_g":0,"carbohydrates_g":0,
               "estimated_calories_share":null,"status":null,"status_set_by":null,"counted":false},
              {"date":"2026-10-18","meal_count":3,"calories_kcal":1950.5,"protein_g":110,"fat_g":70,"carbohydrates_g":220,
               "estimated_calories_share":0.6,"status":"complete","status_set_by":"assistant","counted":true}],
             "counting_rule":"complete_days"}
            """))
        }
        let range = try await api.days(from: .now, to: .now)
        #expect(range.countingRule == .completeDays)
        #expect(range.days.map(\.state) == [.none, .complete])
        #expect(range.days[1].markedBy == .assistant)
        #expect(range.days[1].estimatedCaloriesShare == 0.6)
    }

    @Test func unreachableServer() async {
        let (api, _) = client { _ in (0, Data()) }
        StubProtocol.handler = nil
        let session = URLSession(configuration: .ephemeral)
        let store = CredentialStore(store: MemoryStore())
        let offline = try! ServerAddress.parse("https://127.0.0.1:9")
        store.save(Credentials(clientID: "c", accessToken: "a", refreshToken: nil, expiresAt: nil), for: offline)
        let unreachable = APIClient(server: offline, auth: AuthSession(server: offline, store: store, session: session), session: session)
        _ = api
        do {
            _ = try await unreachable.integrationStatus()
            Issue.record("expected an error")
        } catch {
            if case .unreachable = error {} else { Issue.record("got \(error)") }
        }
    }
}

}

/// The DTOs must match the backend's contract (a copy of its openapi.json in Fixtures/).
/// After the backend changes /api/v1, copy its openapi.json here and adjust the DTOs.
struct APIContractTests {
    private static func schemas() throws -> [String: [String: Any]] {
        let url = try #require(Bundle(for: BundleToken.self).url(forResource: "openapi", withExtension: "json"))
        let spec = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let components = try #require(spec["components"] as? [String: Any])
        return try #require(components["schemas"] as? [String: [String: Any]])
    }

    static let contract: [(schema: String, keys: [String])] = [
        ("MealResponse", MealDTO.CodingKeys.allCases.map(\.stringValue)),
        ("MealListResponse", MealListDTO.CodingKeys.allCases.map(\.stringValue)),
        ("MealUpdateResponse", MealUpdateResponseDTO.CodingKeys.allCases.map(\.stringValue)),
        ("DaySummaryResponse", DaySummaryDTO.CodingKeys.allCases.map(\.stringValue)),
        ("DaysResponse", DaysDTO.CodingKeys.allCases.map(\.stringValue)),
        ("DayStatusResponse", DayStatusDTO.CodingKeys.allCases.map(\.stringValue)),
        ("Nutrients", NutrientsDTO.CodingKeys.allCases.map(\.stringValue)),
        ("PeriodResponse", PeriodDTO.CodingKeys.allCases.map(\.stringValue)),
        ("TrendsResponse", TrendsDTO.CodingKeys.allCases.map(\.stringValue)),
        ("TargetRangeModel", TargetRangeDTO.CodingKeys.allCases.map(\.stringValue)),
        ("Targets", TargetsDTO.CodingKeys.allCases.map(\.stringValue)),
        ("SettingsResponse", SettingsDTO.CodingKeys.allCases.map(\.stringValue)),
        ("IntegrationStatusResponse", IntegrationStatusDTO.CodingKeys.allCases.map(\.stringValue)),
        ("GrantResponse", GrantDTO.CodingKeys.allCases.map(\.stringValue)),
        ("ConnectionResponse", ConnectionDTO.CodingKeys.allCases.map(\.stringValue)),
        ("ConnectionsResponse", ConnectionsDTO.CodingKeys.allCases.map(\.stringValue)),
        ("RevokeResponse", RevokeDTO.CodingKeys.allCases.map(\.stringValue)),
        ("MealUpdate", RequestFields.mealUpdate),
        ("SettingsUpdate", RequestFields.settingsUpdate),
        ("DayStatusUpdate", RequestFields.dayStatusUpdate),
        ("DeleteAccountRequest", RequestFields.deleteAccount),
        ]

    @Test(arguments: contract)
    func dtoMatchesTheContract(_ entry: (schema: String, keys: [String])) throws {
        let (name, keys) = entry
        let schema = try #require(try Self.schemas()[name], "\(name) is not in openapi.json")
        let properties = Set((schema["properties"] as? [String: Any] ?? [:]).keys)
        let required = Set(schema["required"] as? [String] ?? [])
        #expect(Set(keys) == properties, "\(name): the DTO and the contract list different fields")
        #expect(required.isSubset(of: Set(keys)))
    }
}

private final class BundleToken {}
