import Foundation
import Testing
@testable import HealthyEating

struct WidgetSnapshotTests {
    private let locale = Locale(identifier: "en_US")

    private func snapshot(calm: Bool = false, unit: EnergyUnit = .kcal, day: Date = Calendar.current.startOfDay(for: .now)) -> TodaySnapshot {
        TodaySnapshot(
            day: day, savedAt: .now, caloriesKcal: 1200, proteinG: 77, fatG: 32, carbohydratesG: 144,
            calories: .init(min: 1900, max: 2200), protein: .init(min: 110, max: 140), fat: nil,
            carbohydrates: .init(min: 200, max: nil), energyUnit: unit, calmMode: calm, mealCount: 3,
            lastMealSavedAt: .now, lastAssistant: "Claude")
    }

    @Test func showsTheF1Numbers() {
        let today = snapshot()
        #expect(today.energy(locale: locale) == "1,200")
        #expect(today.energyCaption(locale: locale) == "kcal · 1,900–2,200")
        #expect(today.lockScreenHeadline(locale: locale) == "1,200 kcal · P 77 g")
        #expect(today.lockScreenDetail(locale: locale) == "F 32 g · C 144 g")
    }

    @Test func kilojoulesAreADisplayConversion() {
        let today = snapshot(unit: .kj)
        #expect(today.energy(locale: locale) == "5,021")
        #expect(today.energyCaption(locale: locale) == "kJ · 7,950–9,205")
    }

    @Test func calmModeLeavesCaloriesOut() {
        let calm = snapshot(calm: true)
        #expect(calm.lockScreenHeadline(locale: locale) == "P 77 g · F 32 g")
        #expect(calm.lockScreenDetail(locale: locale) == "C 144 g")
        #expect(!calm.lockScreenHeadline(locale: locale).contains("kcal"))
    }

    @Test func rangesMayBeOpen() {
        #expect(TodaySnapshot.range(.init(min: 200, max: nil), locale: locale) == "from 200")
        #expect(TodaySnapshot.range(.init(min: nil, max: 80), locale: locale) == "up to 80")
        #expect(TodaySnapshot.range(.init(min: nil, max: nil), locale: locale) == nil)
    }

    @Test func overAndUnderUseTheSameScale() {
        let range = TodaySnapshot.Range(min: 110, max: 140)
        #expect(TodaySnapshot.scale(77, range) == 182)
        #expect(TodaySnapshot.scale(200, range) == 200, "a value past the track just fills it")
        #expect(TodaySnapshot.scale(50, nil) == 65)
    }

    @Test func yesterdaysSnapshotIsNotCurrent() throws {
        let yesterday = try #require(Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: .now)))
        #expect(snapshot().isCurrent())
        #expect(!snapshot(day: yesterday).isCurrent())
    }

    @Test func publishingKeepsItForTheWidgetsAndSignOutRemovesIt() throws {
        let storage = MemorySnapshotStorage()
        WidgetUpdates.publish(snapshot(), storage: storage)
        #expect(TodaySnapshot.load(from: storage)?.proteinG == 77)
        WidgetUpdates.setCalmMode(true, storage: storage)
        #expect(TodaySnapshot.load(from: storage)?.calmMode == true)
        WidgetUpdates.clear(storage: storage, access: MemorySnapshotStorage())
        #expect(TodaySnapshot.load(from: storage) == nil)
    }

    @Test func snapshotsComeFromTheDayAndSettings() {
        let settings = UserSettings(
            timeZone: nil, energyUnit: .kcal, calmMode: false,
            targets: [.calories: TargetRange(min: 1900, max: 2200), .protein: TargetRange(min: 110, max: nil)])
        let integration = IntegrationState(lastMealSavedAt: nil, lastAssistant: nil, mealsToday: 0)
        let empty = WidgetUpdates.snapshot(day: nil, settings: settings, integration: integration)
        #expect(empty.caloriesKcal == 0)
        #expect(empty.mealCount == 0)
        #expect(empty.calories == .init(min: 1900, max: 2200))
        #expect(empty.protein == .init(min: 110, max: nil))
        #expect(empty.fat == nil)
    }
}

extension NetworkTests {
    struct WidgetAccessTests {
        private let server = URL(string: "https://food.example.com")!

        private let today = Data(#"""
        {"local_date":"2026-10-23","meal_count":2,"calories_kcal":1200.0,"protein_g":77.0,"fat_g":32.0,
         "carbohydrates_g":144.0,"targets":{"calories_kcal":{"min":1900.0,"max":2200.0},"protein_g":null,
         "fat_g":null,"carbohydrates_g":{"min":200.0,"max":null}},"energy_unit":"kj","calm_mode":true,
         "last_meal_saved_at":"2026-10-23T08:44:52.441424+00:00","last_client_name":"ChatGPT"}
        """#.utf8)

        private var calendar: Calendar {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "Europe/Berlin") ?? .current
            return calendar
        }

        @Test func readsTodayWithItsOwnToken() async throws {
            let body = today
            let session = StubProtocol.session { _ in (200, body) }
            let snapshot = try await WidgetAccess(server: server, token: "w1").today(session: session, calendar: calendar)

            let request = try #require(StubProtocol.requests.last)
            #expect(request.url?.absoluteString == "https://food.example.com/api/v1/widget/today")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer w1")
            #expect(APIDate.dayString(snapshot.day, calendar: calendar) == "2026-10-23")
            #expect(snapshot.caloriesKcal == 1200)
            #expect(snapshot.calories == .init(min: 1900, max: 2200))
            #expect(snapshot.protein == nil)
            #expect(snapshot.carbohydrates == .init(min: 200, max: nil))
            #expect(snapshot.energyUnit == .kj)
            #expect(snapshot.calmMode)
            #expect(snapshot.mealCount == 2)
            #expect(snapshot.lastAssistant == "ChatGPT")
            #expect(snapshot.lastMealSavedAt != nil)
        }

        @Test func aRefusedTokenIsRevoked() async {
            let session = StubProtocol.session { _ in (401, Data(#"{"code":"unauthorized","message":"Invalid widget token","details":[]}"#.utf8)) }
            await #expect(throws: WidgetAccess.FetchError.revoked) {
                _ = try await WidgetAccess(server: server, token: "old").today(session: session)
            }
        }

        @Test func noConnectionFailsQuietly() async {
            let session = StubProtocol.session { _ in (-1, Data()) }
            await #expect(throws: WidgetAccess.FetchError.failed) {
                _ = try await WidgetAccess(server: server, token: "w1").today(session: session)
            }
        }

        @Test func theAppAsksForAWidgetToken() async throws {
            let address = try ServerAddress.parse("https://food.example.com")
            let session = StubProtocol.session { _ in (200, Data(#"{"token":"widget-1"}"#.utf8)) }
            let store = CredentialStore(store: MemoryStore())
            store.save(Credentials(clientID: "c1", accessToken: "a", refreshToken: "r", expiresAt: nil), for: address)
            let api = APIClient(server: address, auth: AuthSession(server: address, store: store, session: session), session: session)

            #expect(try await api.createWidgetToken() == "widget-1")
            #expect(StubProtocol.requests.last?.httpMethod == "POST")
            #expect(StubProtocol.requests.last?.url?.path() == "/api/v1/widget-token")
        }

        @Test func accessIsKeptAndRemoved() {
            let storage = MemorySnapshotStorage()
            WidgetAccess(server: server, token: "w1").save(to: storage)
            #expect(WidgetAccess.load(from: storage)?.token == "w1")
            WidgetAccess.remove(from: storage)
            #expect(WidgetAccess.load(from: storage) == nil)
        }
    }
}

struct WidgetSavedLineTests {
    private func snapshot(saved: Date?, assistant: String? = "Claude", meals: Int = 2) -> TodaySnapshot {
        TodaySnapshot(
            day: Calendar.current.startOfDay(for: .now), savedAt: .now, caloriesKcal: 0, proteinG: 0, fatG: 0,
            carbohydratesG: 0, calories: nil, protein: nil, fat: nil, carbohydrates: nil, energyUnit: .kcal,
            calmMode: false, mealCount: meals, lastMealSavedAt: saved, lastAssistant: assistant)
    }

    @Test func showsMinutesNeverSeconds() {
        let now = Date(timeIntervalSince1970: 1_792_700_000)
        #expect(snapshot(saved: now.addingTimeInterval(-20 * 60 - 42)).savedLine(now: now) == "Saved 20 min ago via Claude")
        #expect(snapshot(saved: now.addingTimeInterval(-42)).savedLine(now: now) == "Saved just now via Claude")
        #expect(snapshot(saved: now.addingTimeInterval(-2 * 3600 - 300)).savedLine(now: now) == "Saved 2 h ago via Claude")
        #expect(snapshot(saved: now.addingTimeInterval(-5 * 60), assistant: nil).savedLine(now: now) == "Saved 5 min ago")
    }

    @Test func beforeTheFirstMealItSaysSo() {
        #expect(snapshot(saved: nil, meals: 0).savedLine() == "No meals yet today")
        #expect(snapshot(saved: nil).savedLine() == nil)
    }
}
