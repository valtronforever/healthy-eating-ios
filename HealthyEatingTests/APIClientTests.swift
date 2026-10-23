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
        ("WeeklyReviewResponse", WeeklyReviewDTO.CodingKeys.allCases.map(\.stringValue)),
        ("NutrientTotalResponse", NutrientTotalDTO.CodingKeys.allCases.map(\.stringValue)),
        ("OptionalAverageResponse", OptionalAverageDTO.CodingKeys.allCases.map(\.stringValue)),
        ("LeftOutDayResponse", LeftOutDayDTO.CodingKeys.allCases.map(\.stringValue)),
        ("DayGroupResponse", DayGroupDTO.CodingKeys.allCases.map(\.stringValue)),
        ("ProteinBucketResponse", ProteinBucketDTO.CodingKeys.allCases.map(\.stringValue)),
        ("GrantResponse", GrantDTO.CodingKeys.allCases.map(\.stringValue)),
        ("ConnectionResponse", ConnectionDTO.CodingKeys.allCases.map(\.stringValue)),
        ("ConnectionsResponse", ConnectionsDTO.CodingKeys.allCases.map(\.stringValue)),
        ("RevokeResponse", RevokeDTO.CodingKeys.allCases.map(\.stringValue)),
        ("MeResponse", MeDTO.CodingKeys.allCases.map(\.stringValue)),
        ("WeightEntryResponse", WeightEntryDTO.CodingKeys.allCases.map(\.stringValue)),
        ("TrendPointResponse", TrendPointDTO.CodingKeys.allCases.map(\.stringValue)),
        ("WeightsResponse", WeightsDTO.CodingKeys.allCases.map(\.stringValue)),
        ("WeightsCreated", WeightsCreatedDTO.CodingKeys.allCases.map(\.stringValue)),
        ("WeightsDeleted", WeightsDeletedDTO.CodingKeys.allCases.map(\.stringValue)),
        ("ExpenditureResponse", ExpenditureDTO.CodingKeys.allCases.map(\.stringValue)),
        ("WidgetTokenResponse", WidgetTokenDTO.CodingKeys.allCases.map(\.stringValue)),
        ("WidgetTodayResponse", WidgetTodayDTO.CodingKeys.allCases.map(\.stringValue)),
        ("MealUpdate", RequestFields.mealUpdate),
        ("SettingsUpdate", RequestFields.settingsUpdate),
        ("DayStatusUpdate", RequestFields.dayStatusUpdate),
        ("DeleteAccountRequest", RequestFields.deleteAccount),
        ("WeightCreate", RequestFields.weightCreate),
        ("WeightsCreate", RequestFields.weightsCreate),
        ("WeightUpdate", RequestFields.weightUpdate),
        ("DeleteAllWeightsRequest", RequestFields.deleteAllWeights),
        ("AppleHealthDeletions", RequestFields.appleHealthDeletions),
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

extension NetworkTests {
    struct ArrivalStatusAPITests {
        private func status(_ arrival: String?) async throws -> IntegrationState {
            let field = arrival.map { #","arrival_status":"\#($0)""# } ?? ""
            let (api, _) = client { _ in
                (200, json(#"{"last_meal_saved_at":"2026-10-18T11:00:00Z","last_client_name":"Claude","meals_today":0\#(field)}"#))
            }
            return try await api.integrationStatus()
        }

        @Test func mapsTheServersArrivalStatus() async throws {
            #expect(try await status("quiet").arrival == .quiet)
            #expect(try await status("ok").arrival == .ok)
        }

        @Test func olderServersAndNewValuesMeanUnknown() async throws {
            #expect(try await status(nil).arrival == .unknown)
            #expect(try await status("something-new").arrival == .unknown)
        }
    }
}

extension NetworkTests {
    struct WeeklyReviewAPITests {
        @Test func mapsTheWeek() async throws {
            let (api, _) = client { request in
                #expect(request.url?.path() == "/api/v1/weekly-review")
                #expect(request.url?.query() == "week=2026-10-14")
                return (200, json(#"""
                {"first_day":"2026-10-12","last_day":"2026-10-18","counting_rule":"complete_days",
                 "logged_days":6,"complete_days":5,"counted_days":5,
                 "averages":{"calories_kcal":2060.0,"protein_g":121.0,"fat_g":70.0,"carbohydrates_g":231.0},
                 "left_out":[{"local_date":"2026-10-15","reason":"not_logged"},{"local_date":"2026-10-18","reason":"in_progress"},
                             {"local_date":"2026-10-16","reason":"something_new"}],
                 "weekdays":{"counted_days":3,"averages":null},
                 "weekend":{"counted_days":0,"averages":null},
                 "meal_count":17,"protein_per_meal_g":31.0,
                 "protein_buckets":[{"min_g":0,"max_g":10,"meals":1},{"min_g":40,"max_g":null,"meals":4}],
                 "late_meals":2,"estimated_values_share":0.64,"low_confidence_meals":3}
                """#))
            }
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = try #require(TimeZone(identifier: "Europe/Berlin"))
            let wednesday = try #require(APIDate.day("2026-10-14", calendar: calendar))

            let review = try await api.weeklyReview(week: wednesday)

            #expect(APIDate.dayString(review.firstDay, calendar: calendar) == "2026-10-12")
            #expect(review.countingRule == .completeDays)
            #expect(review.averages?.proteinG == 121)
            #expect(review.leftOut.map(\.reason) == [.notLogged, .inProgress, .notLogged])
            #expect(review.weekend.averages == nil)
            #expect(review.proteinBuckets.last == .init(minG: 40, maxG: nil, meals: 4))
            #expect(review.estimatedValuesShare == 0.64)
        }
    }
}

extension NetworkTests {
    struct OptionalNutrientAPITests {
        @Test func mapsMealValuesAndTheirMarks() async throws {
            let meal = mealJSON.replacingOccurrences(
                of: #""carbohydrates_g":36.0,"#,
                with: #""carbohydrates_g":36.0,"fiber_g":7.0,"sugar_g":null,"sodium_mg":640.0,"#)
                .replacingOccurrences(of: #""estimated_fields":["protein_g","fat_g"]"#, with: #""estimated_fields":["protein_g","fiber_g"]"#)
            let (api, _) = client { _ in (200, json(#"{"meals":[\#(meal)],"next_cursor":null}"#)) }

            let page = try await api.meals(from: .now, to: .now)

            let first = try #require(page.meals.first)
            #expect(first.optional == [.fiber: 7, .sodium: 640])
            #expect(first.estimatedOptional == [.fiber])
            #expect(first.estimatedFields == [.protein])
        }

        @Test func editsSetAndClearThem() async throws {
            let (api, _) = client { _ in (200, json(#"{"meal":\#(mealJSON),"warnings":[]}"#)) }
            var edit = APIClient.MealEdit()
            edit.optional = [.fiber: 9, .sugar: Double?.none]

            _ = try await api.update(UUID(), with: edit)

            let body = try #require(JSONSerialization.jsonObject(with: StubProtocol.requests.last?.httpBody ?? Data()) as? [String: Any])
            #expect(body["fiber_g"] as? Double == 9)
            #expect(body["sugar_g"] is NSNull)
            #expect(body["sodium_mg"] == nil)
        }

        @Test func olderServersHaveNone() async throws {
            let (api, _) = client { _ in (200, json(#"{"meals":[\#(mealJSON)],"next_cursor":null}"#)) }
            let first = try #require(try await api.meals(from: .now, to: .now).meals.first)
            #expect(first.optional.isEmpty)
        }

        @Test func mapsDayTotals() async throws {
            let (api, _) = client { _ in
                (200, json(#"""
                {"days":[{"date":"2026-10-18","meal_count":3,"calories_kcal":1200.0,"protein_g":80.0,"fat_g":40.0,
                  "carbohydrates_g":120.0,"fiber_g":{"amount":14.0,"meal_count":2},"sugar_g":null,"sodium_mg":null,
                  "estimated_calories_share":0.5,"status":null,"status_set_by":null,"counted":true}],
                 "counting_rule":"logged_days"}
                """#))
            }
            let day = try #require(try await api.days(from: .now, to: .now).days.first)
            #expect(day.optional == [.fiber: OptionalTotal(amount: 14, mealCount: 2)])
        }
    }
}

extension NetworkTests {
    struct WeightAPITests {
        private let entryJSON = #"""
        {"id":"0b6f3c2e-2222-4000-8000-000000000001","weight_kg":80.4,"measured_at":"2026-10-18T07:10:00+02:00",
         "local_date":"2026-10-18","source":"assistant",
         "created_at":"2026-10-18T05:10:01Z","updated_at":"2026-10-18T05:10:01Z"}
        """#

        @Test func mapsWeighInsAndTheTrendToTheDeviceCalendar() async throws {
            let entry = entryJSON
            let (api, _) = client { request in
                #expect(request.url?.path() == "/api/v1/weights")
                #expect(request.url?.query() == "from=2026-09-25&to=2026-10-22")
                return (200, json(#"""
                {"first_day":"2026-09-25","last_day":"2026-10-22","entries":[\#(entry)],
                 "trend":[{"date":"2026-10-18","weight_kg":80.4,"trend_kg":80.1}],
                 "latest_trend_kg":80.1,"weekly_change_kg":-0.3,"change_days":21}
                """#))
            }
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = try #require(TimeZone(identifier: "Europe/Berlin"))
            let first = try #require(APIDate.day("2026-09-25", calendar: calendar))
            let last = try #require(APIDate.day("2026-10-22", calendar: calendar))

            let history = try await api.weights(from: first, to: last)

            #expect(history.entries.map(\.weightKg) == [80.4])
            #expect(history.entries.first?.source == .assistant)
            #expect(history.trend.map { APIDate.dayString($0.date, calendar: calendar) } == ["2026-10-18"])
            #expect(history.latestTrendKg == 80.1)
            #expect(history.weeklyChangeKg == -0.3)
            #expect(history.changeDays == 21)
        }

        @Test func addsOneWeighInFromTheApp() async throws {
            let entry = entryJSON
            let (api, _) = client { _ in (201, json(#"{"entries":[\#(entry)]}"#)) }
            let saved = try await api.addWeight(kg: 80.4, at: Date(timeIntervalSince1970: 1_792_300_000))
            #expect(saved.weightKg == 80.4)
            let request = try #require(StubProtocol.requests.last)
            #expect(request.httpMethod == "POST")
            let body = try #require(JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: Any])
            let entries = try #require(body["entries"] as? [[String: Any]])
            #expect(entries.count == 1)
            #expect(entries.first?["source"] as? String == "app")
            #expect(entries.first?["weight_kg"] as? Double == 80.4)
        }

        @Test func deletingAllWeightsSendsTheConfirmation() async throws {
            let (api, _) = client { _ in (200, json(#"{"deleted":12}"#)) }
            #expect(try await api.deleteAllWeights() == 12)
            let request = try #require(StubProtocol.requests.last)
            #expect(request.httpMethod == "DELETE")
            let body = try #require(JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: Any])
            #expect(body["confirm"] as? String == "delete-all-weights")
        }

        @Test func mapsTheEnergyEstimateAndWhatIsMissing() async throws {
            let (api, _) = client { request in
                #expect(request.url?.path() == "/api/v1/expenditure")
                return (200, json(#"""
                {"first_day":"2026-09-25","last_day":"2026-10-22","counting_rule":"all_logged_days",
                 "counted_days":9,"weigh_ins":3,"weigh_in_days":3,"average_intake_kcal":2100.0,
                 "trend_change_kg":null,"span_days":null,"maintenance_kcal":null,"confidence":null,
                 "reason":"not_enough_logged_days"}
                """#))
            }
            let estimate = try await api.energyEstimate()
            #expect(estimate.maintenanceKcal == nil)
            #expect(estimate.missing == .loggedDays)
            #expect(estimate.countedDays == 9)
        }

        @Test func olderServersHaveWeightTrackingOff() async throws {
            let (api, _) = client { _ in
                (200, json(#"{"timezone":null,"energy_unit":"kcal","calm_mode":false,"targets":{"calories_kcal":null,"protein_g":null,"fat_g":null,"carbohydrates_g":null}}"#))
            }
            let settings = try await api.settings()
            #expect(settings.weightTracking == false)
            #expect(settings.weightUnit == .kg)
        }

        @Test func settingsChangesTurnWeightTrackingOnInPounds() async throws {
            let (api, _) = client { _ in
                (200, json(#"{"timezone":null,"energy_unit":"kcal","calm_mode":false,"targets":{"calories_kcal":null,"protein_g":null,"fat_g":null,"carbohydrates_g":null},"weight_tracking":true,"weight_unit":"lb"}"#))
            }
            let settings = try await api.updateSettings(.init(weightTracking: true, weightUnit: .lb))
            #expect(settings.weightTracking)
            #expect(settings.weightUnit == .lb)
            let body = try #require(JSONSerialization.jsonObject(with: StubProtocol.requests.last?.httpBody ?? Data()) as? [String: Any])
            #expect(body["weight_tracking"] as? Bool == true)
            #expect(body["weight_unit"] as? String == "lb")
        }
    }
}
