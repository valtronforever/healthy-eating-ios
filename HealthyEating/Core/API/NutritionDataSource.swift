import Foundation

/// What the screens read and change. `APIClient` serves it from the person's server;
/// `SampleDataSource` serves the design boards' sample data to previews, UI tests and
/// screenshots, without a network.
nonisolated protocol NutritionDataSource: Sendable {
    /// All meals of one local day, newest first.
    func meals(on day: Date) async throws(APIError) -> [Meal]
    func days(from: Date, to: Date) async throws(APIError) -> DayRange
    func trends(window: Int) async throws(APIError) -> Trends
    func account() async throws(APIError) -> Account
    func settings() async throws(APIError) -> UserSettings
    func updateSettings(_ change: APIClient.SettingsChange) async throws(APIError) -> UserSettings
    func integrationStatus() async throws(APIError) -> IntegrationState
    func connections() async throws(APIError) -> [Connection]
    /// Returns true if the revoked sign-in was this app's own.
    func revoke(signIn id: UUID) async throws(APIError) -> Bool
    /// Marks a day complete or partial; nil removes the mark.
    func setMark(_ mark: DayMark?, on day: Date) async throws(APIError)
    func update(_ id: UUID, with edit: APIClient.MealEdit) async throws(APIError) -> (meal: Meal, warnings: [String])
    func deleteMeal(_ id: UUID) async throws(APIError)
    func export(format: String) async throws(APIError) -> URL
    func deleteAccount() async throws(APIError)
}

nonisolated extension APIClient: NutritionDataSource {
    func meals(on day: Date) async throws(APIError) -> [Meal] {
        var meals: [Meal] = []
        var cursor: String?
        repeat {
            let page = try await self.meals(from: day, to: day, cursor: cursor)
            meals += page.meals
            cursor = page.nextCursor
        } while cursor != nil
        return meals
    }

    func setMark(_ mark: DayMark?, on day: Date) async throws(APIError) {
        if let mark {
            try await self.mark(day, as: mark)
            return
        }
        do {
            try await clearMark(day)
        } catch .notFound {
            // Not marked: nothing to remove.
        }
    }
}

/// A value a screen loads from the server.
enum Loadable<Value> {
    case loading
    case loaded(Value)
    case failed(APIError)

    var value: Value? {
        if case .loaded(let value) = self { return value }
        return nil
    }
}
