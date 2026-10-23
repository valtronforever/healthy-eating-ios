import Foundation

/// How the widgets read today's totals by themselves (ios#35): a read-only widget token from the
/// server (`POST /api/v1/widget-token`, requested by the app) and `GET /api/v1/widget/today`.
/// The widget never sees the app's tokens; this one reads only that endpoint and ends with the
/// app's sign-in. Stored in the shared Keychain group next to the snapshot.
nonisolated struct WidgetAccess: Codable, Equatable, Sendable {
    /// The server's base URL, as the app signed in to it.
    var server: URL
    var token: String

    static func load(from storage: any SnapshotStorage = KeychainSnapshotStorage(account: "access")) -> WidgetAccess? {
        storage.read().flatMap { try? JSONDecoder().decode(WidgetAccess.self, from: $0) }
    }

    func save(to storage: any SnapshotStorage = KeychainSnapshotStorage(account: "access")) {
        storage.write(try? JSONEncoder().encode(self))
    }

    static func remove(from storage: any SnapshotStorage = KeychainSnapshotStorage(account: "access")) {
        storage.write(nil)
    }

    enum FetchError: Error, Equatable {
        /// The token no longer works (the app signed out or the sign-in was revoked).
        case revoked
        case failed
    }

    /// Today's totals from the server, as the snapshot the widgets show.
    func today(session: URLSession = .shared, now: Date = .now, calendar: Calendar = .current) async throws(FetchError) -> TodaySnapshot {
        var request = URLRequest(url: server.appending(path: "api/v1/widget/today"))
        request.timeoutInterval = 15
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw .failed
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401 { throw .revoked }
        guard status == 200, let dto = try? JSONDecoder().decode(WidgetTodayDTO.self, from: data),
              let snapshot = dto.snapshot(now: now, calendar: calendar) else { throw .failed }
        return snapshot
    }
}

/// `WidgetTodayResponse` in the backend's contract.
nonisolated struct WidgetTodayDTO: Decodable, Sendable {
    struct RangeDTO: Decodable, Sendable {
        let min: Double?
        let max: Double?

        enum CodingKeys: String, CodingKey, CaseIterable {
            case min, max
        }
    }

    struct TargetsDTO: Decodable, Sendable {
        let caloriesKcal: RangeDTO?
        let proteinG: RangeDTO?
        let fatG: RangeDTO?
        let carbohydratesG: RangeDTO?

        enum CodingKeys: String, CodingKey, CaseIterable {
            case caloriesKcal = "calories_kcal"
            case proteinG = "protein_g"
            case fatG = "fat_g"
            case carbohydratesG = "carbohydrates_g"
        }
    }

    let localDate: String
    let mealCount: Int
    let caloriesKcal: Double
    let proteinG: Double
    let fatG: Double
    let carbohydratesG: Double
    let targets: TargetsDTO
    let energyUnit: String
    let calmMode: Bool
    let lastMealSavedAt: String?
    let lastClientName: String?

    enum CodingKeys: String, CodingKey, CaseIterable {
        case localDate = "local_date"
        case mealCount = "meal_count"
        case caloriesKcal = "calories_kcal"
        case proteinG = "protein_g"
        case fatG = "fat_g"
        case carbohydratesG = "carbohydrates_g"
        case targets
        case energyUnit = "energy_unit"
        case calmMode = "calm_mode"
        case lastMealSavedAt = "last_meal_saved_at"
        case lastClientName = "last_client_name"
    }

    /// nil when the server's day is not a valid date.
    func snapshot(now: Date, calendar: Calendar) -> TodaySnapshot? {
        guard let day = APIDate.day(localDate, calendar: calendar) else { return nil }
        let range = { (dto: RangeDTO?) in dto.map { TodaySnapshot.Range(min: $0.min, max: $0.max) } }
        return TodaySnapshot(
            day: day, savedAt: now, caloriesKcal: caloriesKcal, proteinG: proteinG, fatG: fatG,
            carbohydratesG: carbohydratesG, calories: range(targets.caloriesKcal), protein: range(targets.proteinG),
            fat: range(targets.fatG), carbohydrates: range(targets.carbohydratesG),
            energyUnit: EnergyUnit(rawValue: energyUnit) ?? .kcal, calmMode: calmMode, mealCount: mealCount,
            lastMealSavedAt: lastMealSavedAt.flatMap(APIDate.parse), lastAssistant: lastClientName)
    }
}
