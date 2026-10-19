import Foundation

/// One method per `/api/v1` operation, returning domain models.
nonisolated extension APIClient {
    // MARK: Meals

    struct MealPage: Sendable {
        var meals: [Meal]
        var nextCursor: String?
    }

    /// Meals on the local days `from`...`to`, newest first (`listMeals`).
    func meals(from: Date? = nil, to: Date? = nil, cursor: String? = nil, limit: Int = 100) async throws(APIError) -> MealPage {
        var query = [URLQueryItem(name: "limit", value: String(limit))]
        if let from { query.append(URLQueryItem(name: "from", value: APIDate.dayString(from, calendar: calendar))) }
        if let to { query.append(URLQueryItem(name: "to", value: APIDate.dayString(to, calendar: calendar))) }
        if let cursor { query.append(URLQueryItem(name: "cursor", value: cursor)) }
        let page = try await send(Request(path: "meals", query: query), as: MealListDTO.self)
        return MealPage(meals: page.meals.map(Self.meal), nextCursor: page.nextCursor)
    }

    func meal(_ id: UUID) async throws(APIError) -> Meal {
        Self.meal(try await send(Request(path: "meals/\(id.uuidString.lowercased())"), as: MealDTO.self))
    }

    struct MealEdit: Sendable, Equatable {
        var dishName: String?
        /// `.some(nil)` removes the portion weight.
        var portionGrams: Double??
        var caloriesKcal: Double?
        var proteinG: Double?
        var fatG: Double?
        var carbohydratesG: Double?
        var eatenAt: Date?
    }

    /// Corrects the meal in place (`updateMeal`). Changed values become the person's own.
    func update(_ id: UUID, with edit: MealEdit) async throws(APIError) -> (meal: Meal, warnings: [String]) {
        var fields: [String: Any?] = [:]
        if let dishName = edit.dishName { fields["dish_name"] = dishName }
        // `portionGrams` is `.some(nil)` to remove the weight: send JSON null, not "no change".
        if let portion = edit.portionGrams { fields["portion_grams"] = .some(portion ?? NSNull()) }
        if let value = edit.caloriesKcal { fields["calories_kcal"] = value }
        if let value = edit.proteinG { fields["protein_g"] = value }
        if let value = edit.fatG { fields["fat_g"] = value }
        if let value = edit.carbohydratesG { fields["carbohydrates_g"] = value }
        if let eatenAt = edit.eatenAt { fields["eaten_at"] = APIDate.timeString(eatenAt) }
        let request = Request(method: "PATCH", path: "meals/\(id.uuidString.lowercased())", body: Self.json(fields))
        let response = try await send(request, as: MealUpdateResponseDTO.self)
        return (Self.meal(response.meal), response.warnings)
    }

    func deleteMeal(_ id: UUID) async throws(APIError) {
        _ = try await data(for: Request(method: "DELETE", path: "meals/\(id.uuidString.lowercased())"))
    }

    // MARK: Days and trends

    func days(from: Date, to: Date) async throws(APIError) -> DayRange {
        let query = [
            URLQueryItem(name: "from", value: APIDate.dayString(from, calendar: calendar)),
            URLQueryItem(name: "to", value: APIDate.dayString(to, calendar: calendar)),
        ]
        let response = try await send(Request(path: "days", query: query), as: DaysDTO.self)
        let days = try response.days.map { (dto) throws(APIError) -> DayTotals in
            guard let date = APIDate.day(dto.date, calendar: calendar) else { throw .unexpectedResponse("day \(dto.date)") }
            return DayTotals(
                date: date, mealCount: dto.mealCount, caloriesKcal: dto.caloriesKcal, proteinG: dto.proteinG,
                fatG: dto.fatG, carbohydratesG: dto.carbohydratesG, estimatedCaloriesShare: dto.estimatedCaloriesShare,
                status: dto.status.flatMap(DayMark.init(rawValue:)), markedBy: dto.statusSetBy.flatMap(MarkSetter.init(rawValue:)),
                counted: dto.counted)
        }
        return DayRange(days: days, countingRule: CountingRule(rawValue: response.countingRule) ?? .loggedDays)
    }

    func mark(_ day: Date, as mark: DayMark) async throws(APIError) {
        let request = Request(method: "PUT", path: "days/\(APIDate.dayString(day, calendar: calendar))/status", body: Self.json(["status": mark.rawValue]))
        _ = try await data(for: request)
    }

    func clearMark(_ day: Date) async throws(APIError) {
        _ = try await data(for: Request(method: "DELETE", path: "days/\(APIDate.dayString(day, calendar: calendar))/status"))
    }

    func trends(window: Int) async throws(APIError) -> Trends {
        let dto = try await send(Request(path: "trends", query: [URLQueryItem(name: "window", value: String(window))]), as: TrendsDTO.self)
        return Trends(
            windowDays: dto.windowDays,
            countingRule: CountingRule(rawValue: dto.countingRule) ?? .loggedDays,
            current: try period(dto.current),
            previous: try period(dto.previous),
            change: dto.change.map(Self.nutrients))
    }

    private func period(_ dto: PeriodDTO) throws(APIError) -> TrendPeriod {
        guard let first = APIDate.day(dto.firstDay, calendar: calendar), let last = APIDate.day(dto.lastDay, calendar: calendar) else {
            throw .unexpectedResponse("period \(dto.firstDay)")
        }
        return TrendPeriod(
            firstDay: first, lastDay: last, countedDays: dto.countedDays, loggedDays: dto.loggedDays,
            averages: dto.averages.map(Self.nutrients), estimatedCaloriesShare: dto.estimatedCaloriesShare)
    }

    // MARK: Account

    func account() async throws(APIError) -> Account {
        let dto = try await send(Request(path: "me"), as: MeDTO.self)
        return Account(displayName: dto.displayName, email: dto.email, linkedLogins: dto.linkedLogins)
    }

    func settings() async throws(APIError) -> UserSettings {
        Self.settings(try await send(Request(path: "me/settings"), as: SettingsDTO.self))
    }

    struct SettingsChange: Sendable {
        /// `.some(nil)` clears the time zone.
        var timeZone: String??
        var energyUnit: EnergyUnit?
        var calmMode: Bool?
        /// A nil range removes that target.
        var targets: [NutrientField: TargetRange?] = [:]
    }

    func updateSettings(_ change: SettingsChange) async throws(APIError) -> UserSettings {
        var fields: [String: Any?] = [:]
        if let timeZone = change.timeZone { fields["timezone"] = .some(timeZone ?? NSNull()) }
        if let unit = change.energyUnit { fields["energy_unit"] = unit.rawValue }
        if let calm = change.calmMode { fields["calm_mode"] = calm }
        if !change.targets.isEmpty {
            var targets: [String: Any] = [:]
            for (field, range) in change.targets {
                if let range {
                    targets[field.rawValue] = ["min": range.min as Any? ?? NSNull(), "max": range.max as Any? ?? NSNull()]
                } else {
                    targets[field.rawValue] = NSNull()
                }
            }
            fields["targets"] = targets
        }
        let request = Request(method: "PATCH", path: "me/settings", body: Self.json(fields))
        return Self.settings(try await send(request, as: SettingsDTO.self))
    }

    func integrationStatus() async throws(APIError) -> IntegrationState {
        let dto = try await send(Request(path: "integration-status"), as: IntegrationStatusDTO.self)
        return IntegrationState(lastMealSavedAt: dto.lastMealSavedAt, lastAssistant: dto.lastClientName, mealsToday: dto.mealsToday)
    }

    func connections() async throws(APIError) -> [Connection] {
        let dto = try await send(Request(path: "connections"), as: ConnectionsDTO.self)
        return dto.connections.map { connection in
            Connection(
                id: connection.clientId, name: connection.name,
                kind: Connection.Kind(rawValue: connection.kind) ?? .aiAssistant,
                signIns: connection.grants.map {
                    Connection.SignIn(id: $0.grantId, createdAt: $0.createdAt, lastUsedAt: $0.lastUsedAt, isCurrent: $0.current)
                })
        }
    }

    /// Revokes one sign-in. Returns true if it was this app's own (the app is then signed out).
    func revoke(signIn id: UUID) async throws(APIError) -> Bool {
        try await send(Request(method: "DELETE", path: "connections/\(id.uuidString.lowercased())"), as: RevokeDTO.self).signedOut
    }

    /// Downloads all data to a temporary file for the share sheet (`exportData`).
    func export(format: String) async throws(APIError) -> URL {
        let data = try await data(for: Request(path: "export", query: [URLQueryItem(name: "format", value: format)]))
        let name = "healthy-eating-export-\(APIDate.dayString(.now, calendar: calendar)).\(format == "csv" ? "zip" : "json")"
        let url = FileManager.default.temporaryDirectory.appending(path: name)
        do {
            try data.write(to: url, options: [.atomic, .completeFileProtection])
        } catch {
            throw .unexpectedResponse("could not save the export")
        }
        return url
    }

    func deleteAccount() async throws(APIError) {
        _ = try await data(for: Request(method: "DELETE", path: "me", body: Self.json(["confirm": "delete-account"])))
    }

    // MARK: Mapping

    static func meal(_ dto: MealDTO) -> Meal {
        Meal(
            id: dto.id, eatenAt: dto.eatenAt, dishName: dto.dishName, caloriesKcal: dto.caloriesKcal,
            proteinG: dto.proteinG, fatG: dto.fatG, carbohydratesG: dto.carbohydratesG, portionGrams: dto.portionGrams,
            estimatedFields: Set(dto.estimatedFields.compactMap(NutrientField.init(rawValue:))),
            confidence: Confidence(rawValue: dto.confidence),
            assistant: dto.clientName ?? String(localized: "your AI assistant"),
            sourceNote: dto.sourceNote)
    }

    static func nutrients(_ dto: NutrientsDTO) -> NutrientValues {
        NutrientValues(caloriesKcal: dto.caloriesKcal, proteinG: dto.proteinG, fatG: dto.fatG, carbohydratesG: dto.carbohydratesG)
    }

    static func settings(_ dto: SettingsDTO) -> UserSettings {
        let pairs: [(NutrientField, TargetRangeDTO?)] = [
            (.calories, dto.targets.caloriesKcal), (.protein, dto.targets.proteinG),
            (.fat, dto.targets.fatG), (.carbohydrates, dto.targets.carbohydratesG),
        ]
        var targets: [NutrientField: TargetRange] = [:]
        for (field, range) in pairs {
            if let range { targets[field] = TargetRange(min: range.min, max: range.max) }
        }
        return UserSettings(
            timeZone: dto.timezone, energyUnit: EnergyUnit(rawValue: dto.energyUnit) ?? .kcal,
            calmMode: dto.calmMode, targets: targets)
    }
}
