import Foundation
import Testing
@testable import HealthyEating

/// Apple Health in memory: hands out queued changes once, records what the app writes.
@MainActor
private final class FakeHealth: AppleHealthStore {
    var isAvailable = true
    var canWrite = true
    /// Off unless a test is about meals, so weight tests count only weight changes.
    var writableNutrients: Set<HealthNutrient> = []
    /// Apple Health returns nothing while read access is off.
    var readable = true
    var pending = AppleHealthChanges()
    private(set) var saved: [HealthWrite] = []
    private(set) var deleted: [UUID] = []
    private(set) var savedMeals: [HealthMeal] = []
    private(set) var deletedMeals: [UUID] = []
    private(set) var accessRequests = 0

    init(added: [HealthWeight] = []) {
        pending.added = added
    }

    func requestAccess() async throws {}
    func requestAccessIfNeeded() async { accessRequests += 1 }

    func changes(after anchor: Data?) async throws -> AppleHealthChanges {
        guard readable else { return AppleHealthChanges(anchor: Data("anchor".utf8)) }
        var changes = pending
        changes.anchor = Data("anchor".utf8)
        pending = AppleHealthChanges()
        return changes
    }

    func save(_ writes: [HealthWrite]) async throws { saved += writes }
    func delete(serverIDs: [UUID]) async throws { deleted += serverIDs }
    func saveMeals(_ meals: [HealthMeal]) async throws { savedMeals += meals }
    func deleteMeals(serverIDs: [UUID]) async throws { deletedMeals += serverIDs }
}

@MainActor
struct AppleHealthSyncTests {
    private let scaleSample = HealthWeight(id: UUID(), kg: 85, measuredAt: .now.addingTimeInterval(-3 * 365 * 86_400))

    private func model(_ health: FakeHealth) -> AppModel {
        let defaults = UserDefaults(suiteName: "AppleHealthSyncTests.\(UUID())")!
        return AppModel(defaults: defaults, arguments: [AppModel.LaunchArgument.skipOnboarding], appleHealth: health)
    }

    private func weighIns(_ model: AppModel) async throws -> [WeighIn] {
        let data = try #require(model.data)
        let today = Calendar.current.startOfDay(for: .now)
        // Sample data has no range limit; the old scale sample is three years back.
        let first = Calendar.current.date(byAdding: .day, value: -4 * 365, to: today) ?? today
        return try await data.weights(from: first, to: today).entries
    }

    @Test func offByDefaultAndSyncsNothing() async {
        let model = model(FakeHealth())
        #expect(!model.appleHealthSyncEnabled)
        #expect(await model.syncAppleHealth() == nil)
    }

    @Test func turningOnImportsTheWholeHistoryAndWritesChatAndAppWeighIns() async throws {
        let health = FakeHealth(added: [scaleSample])
        let model = model(health)
        let data = try #require(model.data)
        let typed = try await data.addWeight(kg: 84.5, at: .now.addingTimeInterval(-3600))

        await model.setAppleHealthSync(true)

        #expect(model.appleHealthSyncEnabled)
        #expect(health.saved.map(\.serverID) == [typed.id], "only weigh-ins from the chat or the app")
        #expect(health.saved.first?.kg == 84.5)
        #expect(model.appleHealthLastSyncCount == 2)
        // Opening the app again changes nothing.
        #expect(await model.syncAppleHealth() == 0)
        #expect(health.saved.count == 1)
    }

    @Test func aCorrectionReplacesTheSampleAndADeletionRemovesIt() async throws {
        let health = FakeHealth()
        let model = model(health)
        let data = try #require(model.data)
        let typed = try await data.addWeight(kg: 84.5, at: .now.addingTimeInterval(-3600))
        await model.setAppleHealthSync(true)

        try await Task.sleep(for: .milliseconds(5))
        _ = try await data.updateWeight(typed.id, kg: 84.0, at: nil)
        #expect(await model.syncAppleHealth() == 1)
        #expect(health.saved.map(\.kg) == [84.5, 84.0])
        #expect(health.saved[1].version > health.saved[0].version)

        try await data.deleteWeight(typed.id)
        #expect(await model.syncAppleHealth() == 1)
        #expect(health.deleted == [typed.id])
    }

    @Test func deletionsInAppleHealthReachTheServer() async throws {
        let health = FakeHealth(added: [scaleSample])
        let model = model(health)
        let data = try #require(model.data)
        let typed = try await data.addWeight(kg: 84.5, at: .now.addingTimeInterval(-3600))
        await model.setAppleHealthSync(true)
        let version = try #require(health.saved.first?.version)

        // The scale sample and the app's own sample are deleted in Apple Health; a replaced
        // older version of the typed weigh-in is reported too and must not delete it.
        health.pending.deleted = [scaleSample.id]
        health.pending.deletedWrites = [DeletedHealthWrite(serverID: typed.id, version: version - 1)]
        _ = await model.syncAppleHealth()
        var ids = Set(try await weighIns(model).map(\.id))
        #expect(!ids.contains(scaleSample.id))
        #expect(ids.contains(typed.id))

        health.pending.deletedWrites = [DeletedHealthWrite(serverID: typed.id, version: version)]
        _ = await model.syncAppleHealth()
        ids = Set(try await weighIns(model).map(\.id))
        #expect(!ids.contains(typed.id))
        #expect(health.deleted.isEmpty, "already gone from Apple Health")
    }

    @Test func whileWeightTrackingIsOffNothingSyncs() async throws {
        let health = FakeHealth(added: [scaleSample])
        let model = model(health)
        let data = try #require(model.data)
        _ = try await data.updateSettings(.init(weightTracking: false))

        await model.setAppleHealthSync(true)
        #expect(model.appleHealthLastSyncCount == 0)

        _ = try await data.updateSettings(.init(weightTracking: true))
        #expect(await model.syncAppleHealth() == 1)
    }

    @Test func anEmptyFirstReadIsReadAgainLater() async throws {
        let health = FakeHealth(added: [scaleSample])
        health.readable = false
        let model = model(health)
        await model.setAppleHealthSync(true)
        #expect(!(try await weighIns(model).contains { $0.id == scaleSample.id }))

        health.readable = true
        _ = await model.syncAppleHealth()
        #expect(try await weighIns(model).contains { $0.id == scaleSample.id })
    }

    @Test func largeHistoriesGoInBatches() async throws {
        let samples = (0..<2_500).map { index in
            HealthWeight(id: UUID(), kg: 80, measuredAt: .now.addingTimeInterval(-Double(index) * 600))
        }
        let model = model(FakeHealth(added: samples))
        await model.setAppleHealthSync(true)
        #expect(model.appleHealthLastSyncCount == 2_500)
    }

    @Test func withoutWritePermissionItOnlyImports() async throws {
        let health = FakeHealth(added: [scaleSample])
        health.canWrite = false
        let model = model(health)
        _ = try await #require(model.data).addWeight(kg: 84.5, at: .now)
        await model.setAppleHealthSync(true)
        #expect(health.saved.isEmpty)
        #expect(try await weighIns(model).contains { $0.id == scaleSample.id })
    }

    @Test func unavailableHealthDataLeavesItOff() async {
        let health = FakeHealth()
        health.isAvailable = false
        let model = model(health)
        await model.setAppleHealthSync(true)
        #expect(!model.appleHealthSyncEnabled)
    }

    @Test func turningOffOrSigningOutForgetsTheSync() async {
        let model = model(FakeHealth(added: [scaleSample]))
        await model.setAppleHealthSync(true)
        await model.setAppleHealthSync(false)
        #expect(!model.appleHealthSyncEnabled)
        #expect(model.appleHealthLastSync == nil)

        await model.setAppleHealthSync(true)
        await model.signOut()
        #expect(!model.appleHealthSyncEnabled)
        #expect(model.appleHealthLastSyncCount == 0)
    }

    // MARK: Meals (ios#31)

    @Test func writesMealsOnceThenOnlyWhatChanged() async throws {
        let health = FakeHealth()
        health.writableNutrients = Set(HealthNutrient.allCases)
        let model = model(health)
        let data = try #require(model.data)
        let meals = try await data.allMeals(from: .now, to: .now)
        try #require(meals.count >= 2)

        await model.setAppleHealthSync(true)
        #expect(Set(health.savedMeals.map(\.serverID)) == Set(meals.map(\.id)))
        #expect(await model.syncAppleHealth() == 0)

        try await Task.sleep(for: .milliseconds(5))
        _ = try await data.update(meals[0].id, with: .init(caloriesKcal: meals[0].caloriesKcal + 50))
        #expect(await model.syncAppleHealth() == 1)
        let corrected = try #require(health.savedMeals.last)
        #expect(corrected.serverID == meals[0].id)
        #expect(corrected.values[.energy] == meals[0].caloriesKcal + 50)
        #expect(corrected.version > (health.savedMeals.first { $0.serverID == meals[0].id }?.version ?? .max))

        try await data.deleteMeal(meals[1].id)
        #expect(await model.syncAppleHealth() == 1)
        #expect(health.deletedMeals == [meals[1].id])
    }

    @Test func mealsSyncWhileWeightTrackingIsOff() async throws {
        let health = FakeHealth(added: [scaleSample])
        health.writableNutrients = Set(HealthNutrient.allCases)
        let model = model(health)
        _ = try await #require(model.data).updateSettings(.init(weightTracking: false))
        await model.setAppleHealthSync(true)
        #expect(!health.savedMeals.isEmpty)
        #expect(!(try await weighIns(model).contains { $0.id == scaleSample.id }), "weight stays off")
    }

    @Test func withoutCaloriesPermissionNoMealIsWritten() async throws {
        let health = FakeHealth()
        health.writableNutrients = [.protein, .fat]
        await model(health).setAppleHealthSync(true)
        #expect(health.savedMeals.isEmpty)
    }

    @Test func aMealCarriesOnlyTheValuesItHas() {
        let meal = Meal(id: UUID(), eatenAt: .now, dishName: "Borscht", caloriesKcal: 412, proteinG: 14, fatG: 24,
                        carbohydratesG: 36, portionGrams: nil, estimatedFields: [], confidence: nil, assistant: "Claude",
                        sourceNote: nil, optional: [.fiber: 6, .sodium: 820])
        let written = HealthMeal(meal, version: 1)
        #expect(written.values == [.energy: 412, .protein: 14, .fat: 24, .carbohydrates: 36, .fiber: 6, .sodium: 820])
        #expect(written.dishName == "Borscht")
        #expect(AppleHealthSyncID.meal(meal.id, .energy) == AppleHealthSyncID.meal(meal.id) + ":energy")
    }

    @Test func theForegroundAsksForNewlyAddedTypes() async {
        let health = FakeHealth()
        let model = model(health)
        await model.setAppleHealthSync(true)
        _ = await model.syncAppleHealth(foreground: true)
        _ = await model.syncAppleHealth()
        #expect(health.accessRequests == 1, "only in the foreground")
    }

    @Test func describesTheLastSync() {
        let locale = Locale(identifier: "en_US")
        #expect(AppleHealthSyncToggle.detail(enabled: false, last: .now, count: 3, locale: locale)
            == "Meals and body weight, when the app opens")
        #expect(AppleHealthSyncToggle.detail(enabled: true, last: nil, count: 0, locale: locale)
            == "Meals and body weight, when the app opens")
        #expect(AppleHealthSyncToggle.detail(enabled: true, last: .now.addingTimeInterval(-7200), count: 3, locale: locale)
            .hasPrefix("3 changes synced "))
        #expect(AppleHealthSyncToggle.detail(enabled: true, last: .now, count: 1, locale: locale).hasPrefix("1 change synced "))
    }

    @Test func syncIDsNameTheServerWeighIn() throws {
        let id = try #require(UUID(uuidString: "0B6F3C2E-3333-4000-8000-000000000001"))
        #expect(AppleHealthSyncID.make(id) == "healthy-eating:0b6f3c2e-3333-4000-8000-000000000001")
        #expect(AppleHealthSyncID.serverID(AppleHealthSyncID.make(id)) == id)
        #expect(AppleHealthSyncID.serverID("com.withings:123") == nil)
        #expect(AppleHealthSyncID.serverID(nil) == nil)
    }
}

extension NetworkTests {
    struct AppleHealthAPITests {
        private func api(_ handler: @escaping @Sendable (URLRequest) -> (Int, Data)) throws -> APIClient {
            let server = try ServerAddress.parse("https://food.example.com")
            let session = StubProtocol.session(handler)
            let store = CredentialStore(store: MemoryStore())
            store.save(Credentials(clientID: "c1", accessToken: "a", refreshToken: "r", expiresAt: nil), for: server)
            return APIClient(server: server, auth: AuthSession(server: server, store: store, session: session), session: session)
        }

        private func body() throws -> [String: Any] {
            let request = try #require(StubProtocol.requests.last)
            #expect(request.httpMethod == "POST")
            return try #require(JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: Any])
        }

        private let sampleID = UUID(uuidString: "0B6F3C2E-3333-4000-8000-000000000001") ?? UUID()

        @Test func sendsSamplesAsAppleHealthWithTheirIDs() async throws {
            let api = try api { _ in (201, Data(#"{"entries":[]}"#.utf8)) }
            _ = try await api.importWeights([HealthWeight(id: sampleID, kg: 78.4567, measuredAt: .now)])
            #expect(StubProtocol.requests.last?.url?.path() == "/api/v1/weights")
            let entry = try #require((try body()["entries"] as? [[String: Any]])?.first)
            #expect(entry["source"] as? String == "apple_health")
            #expect(entry["external_id"] as? String == "0b6f3c2e-3333-4000-8000-000000000001")
            #expect(entry["weight_kg"] as? Double == 78.46)
        }

        @Test func sendsDeletedSamplesByTheirIDs() async throws {
            let api = try api { _ in (200, Data(#"{"deleted":1}"#.utf8)) }
            #expect(try await api.deleteAppleHealthWeights([sampleID]) == 1)
            #expect(StubProtocol.requests.last?.url?.path() == "/api/v1/weights/apple-health-deletions")
            #expect(try body()["external_ids"] as? [String] == ["0b6f3c2e-3333-4000-8000-000000000001"])
        }

        @Test func weighInsCarryTheirServerChangeTime() async throws {
            let api = try api { _ in
                (200, Data(#"""
                {"first_day":"2026-10-22","last_day":"2026-10-22","entries":[{"id":"0b6f3c2e-2222-4000-8000-000000000001",
                 "weight_kg":55.5,"measured_at":"2026-10-22T14:56:57+03:00","local_date":"2026-10-22","source":"assistant",
                 "created_at":"2026-10-22T11:56:57Z","updated_at":"2026-10-22T12:00:00Z"}],
                 "trend":[],"latest_trend_kg":null,"weekly_change_kg":null,"change_days":null}
                """#.utf8))
            }
            let entry = try #require(try await api.weights(from: .now, to: .now).entries.first)
            #expect(entry.updatedAt == ISO8601DateFormatter().date(from: "2026-10-22T12:00:00Z"))
            #expect(AppleHealthSync.version(entry) == 1_792_670_400_000)
        }
    }
}
