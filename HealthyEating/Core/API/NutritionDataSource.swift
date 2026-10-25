import Foundation

/// What the screens read and change. `APIClient` serves it from the person's server;
/// `SampleDataSource` serves the design boards' sample data to previews, UI tests and
/// screenshots, without a network.
nonisolated protocol NutritionDataSource: Sendable {
    /// All meals of one local day, newest first.
    func meals(on day: Date) async throws(APIError) -> [Meal]
    /// Dishes eaten at least twice in the last 90 days, most often first.
    func usualMeals() async throws(APIError) -> [UsualMeal]
    /// Logs one of the person's meals again: the app never creates meals from scratch.
    func relog(_ mealID: UUID, as newID: UUID, at date: Date) async throws(APIError) -> Meal
    /// All meals of a range of local days, newest first (every page).
    func allMeals(from: Date, to: Date) async throws(APIError) -> [Meal]
    func days(from: Date, to: Date) async throws(APIError) -> DayRange
    func trends(window: Int) async throws(APIError) -> Trends
    /// The local week, Monday to Sunday, that contains `week`.
    func weeklyReview(week: Date) async throws(APIError) -> WeeklyReview
    func account() async throws(APIError) -> Account
    /// The social logins that sign in to this account, oldest first.
    func logins() async throws(APIError) -> [Login]
    /// Starts adding a login with a PKCE challenge; returns the page to open in the web sheet.
    func startLink(challenge: String) async throws(APIError) -> URL
    /// Finishes adding a login with the web sheet's code and the PKCE verifier.
    func completeLink(code: String, verifier: String) async throws(APIError) -> LinkResult
    /// Removes a login; the account's only login stays.
    func deleteLogin(_ id: UUID) async throws(APIError)
    func settings() async throws(APIError) -> UserSettings
    func updateSettings(_ change: APIClient.SettingsChange) async throws(APIError) -> UserSettings
    func integrationStatus() async throws(APIError) -> IntegrationState
    func weights(from: Date, to: Date) async throws(APIError) -> WeightHistory
    func addWeight(kg: Double, at date: Date) async throws(APIError) -> WeighIn
    func updateWeight(_ id: UUID, kg: Double?, at date: Date?) async throws(APIError) -> WeighIn
    func deleteWeight(_ id: UUID) async throws(APIError)
    func deleteAllWeights() async throws(APIError) -> Int
    /// Sends Apple Health weigh-ins (at most `APIClient.maxWeightBatch`); the server refuses them
    /// while weight tracking is off and stores a sample sent twice once. Returns how many it kept.
    func importWeights(_ weights: [HealthWeight]) async throws(APIError) -> Int
    /// Deletes Apple Health weigh-ins whose samples were deleted in Apple Health (by sample id,
    /// at most `APIClient.maxWeightBatch`); unknown ids are ignored. Returns how many it deleted.
    func deleteAppleHealthWeights(_ sampleIDs: [UUID]) async throws(APIError) -> Int
    func energyEstimate() async throws(APIError) -> EnergyEstimate
    /// A read-only token for the widgets, tied to this sign-in (`WidgetAccess`).
    func createWidgetToken() async throws(APIError) -> String
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
        try await allMeals(from: day, to: day)
    }

    func allMeals(from: Date, to: Date) async throws(APIError) -> [Meal] {
        var meals: [Meal] = []
        var cursor: String?
        repeat {
            let page = try await self.meals(from: from, to: to, cursor: cursor, limit: 200)
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
