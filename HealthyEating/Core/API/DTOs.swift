import Foundation

// Codable mirrors of the backend's /api/v1 schemas (openapi.json). Coding keys are spelled out
// so `APIContractTests` can check them against the contract. Views never see these types:
// `APIClient` maps them to domain models.

nonisolated struct UsualMealDTO: Decodable, Sendable {
    let meal: MealDTO
    let times: Int

    enum CodingKeys: String, CodingKey, CaseIterable {
        case meal, times
    }
}

nonisolated struct UsualMealsDTO: Decodable, Sendable {
    let meals: [UsualMealDTO]

    enum CodingKeys: String, CodingKey, CaseIterable {
        case meals
    }
}

nonisolated struct MealDTO: Decodable, Sendable {
    let id: UUID
    let dishName: String
    let description: String?
    let eatenAt: Date
    let localDate: String
    let portionGrams: Double?
    let caloriesKcal: Double
    let proteinG: Double
    let fatG: Double
    let carbohydratesG: Double
    /// Optional; missing on servers from before fiber, sugar and sodium.
    let fiberG: Double?
    let sugarG: Double?
    let sodiumMg: Double?
    let source: String
    let sourceNote: String?
    /// Set for meals imported from earlier tracking; missing on servers from before the import.
    let importedFrom: String?
    /// Missing on servers from before vitamins and minerals (backend #25).
    let micronutrients: [String: Double]?
    let items: [MealItemDTO]?
    let estimatedFields: [String]
    let confidence: String
    let clientName: String?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey, CaseIterable {
        case id
        case dishName = "dish_name"
        case description
        case eatenAt = "eaten_at"
        case localDate = "local_date"
        case portionGrams = "portion_grams"
        case caloriesKcal = "calories_kcal"
        case proteinG = "protein_g"
        case fatG = "fat_g"
        case carbohydratesG = "carbohydrates_g"
        case fiberG = "fiber_g"
        case sugarG = "sugar_g"
        case sodiumMg = "sodium_mg"
        case source
        case sourceNote = "source_note"
        case importedFrom = "imported_from"
        case micronutrients
        case items
        case estimatedFields = "estimated_fields"
        case confidence
        case clientName = "client_name"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

nonisolated struct MealItemDTO: Decodable, Sendable {
    let name: String
    let grams: Double
    let status: String
    let foodDescription: String?

    enum CodingKeys: String, CodingKey, CaseIterable {
        case name
        case grams
        case status
        case foodDescription = "food_description"
    }
}

nonisolated struct MealListDTO: Decodable, Sendable {
    let meals: [MealDTO]
    let nextCursor: String?

    enum CodingKeys: String, CodingKey, CaseIterable {
        case meals
        case nextCursor = "next_cursor"
    }
}

nonisolated struct MealUpdateResponseDTO: Decodable, Sendable {
    let meal: MealDTO
    let warnings: [String]

    enum CodingKeys: String, CodingKey, CaseIterable {
        case meal, warnings
    }
}

nonisolated struct NutrientTotalDTO: Decodable, Sendable {
    let amount: Double
    let mealCount: Int

    enum CodingKeys: String, CodingKey, CaseIterable {
        case amount
        case mealCount = "meal_count"
    }
}

nonisolated struct OptionalAverageDTO: Decodable, Sendable {
    let average: Double
    let days: Int

    enum CodingKeys: String, CodingKey, CaseIterable {
        case average, days
    }
}

nonisolated struct DaySummaryDTO: Decodable, Sendable {
    let date: String
    let mealCount: Int
    let caloriesKcal: Double
    let proteinG: Double
    let fatG: Double
    let carbohydratesG: Double
    let fiberG: NutrientTotalDTO?
    let sugarG: NutrientTotalDTO?
    let sodiumMg: NutrientTotalDTO?
    /// Missing on servers from before vitamins and minerals (backend #25).
    let micronutrients: [String: NutrientTotalDTO]?
    let estimatedCaloriesShare: Double?
    let status: String?
    let statusSetBy: String?
    let counted: Bool

    enum CodingKeys: String, CodingKey, CaseIterable {
        case date
        case mealCount = "meal_count"
        case caloriesKcal = "calories_kcal"
        case proteinG = "protein_g"
        case fatG = "fat_g"
        case carbohydratesG = "carbohydrates_g"
        case fiberG = "fiber_g"
        case sugarG = "sugar_g"
        case sodiumMg = "sodium_mg"
        case micronutrients
        case estimatedCaloriesShare = "estimated_calories_share"
        case status
        case statusSetBy = "status_set_by"
        case counted
    }
}

nonisolated struct DaysDTO: Decodable, Sendable {
    let days: [DaySummaryDTO]
    let countingRule: String

    enum CodingKeys: String, CodingKey, CaseIterable {
        case days
        case countingRule = "counting_rule"
    }
}

nonisolated struct DayStatusDTO: Decodable, Sendable {
    let date: String
    let status: String
    let setBy: String
    let updatedAt: Date

    enum CodingKeys: String, CodingKey, CaseIterable {
        case date, status
        case setBy = "set_by"
        case updatedAt = "updated_at"
    }
}

nonisolated struct NutrientsDTO: Decodable, Sendable {
    let caloriesKcal: Double
    let proteinG: Double
    let fatG: Double
    let carbohydratesG: Double

    enum CodingKeys: String, CodingKey, CaseIterable {
        case caloriesKcal = "calories_kcal"
        case proteinG = "protein_g"
        case fatG = "fat_g"
        case carbohydratesG = "carbohydrates_g"
    }
}

nonisolated struct PeriodDTO: Decodable, Sendable {
    let firstDay: String
    let lastDay: String
    let countedDays: Int
    let loggedDays: Int
    let averages: NutrientsDTO?
    let estimatedCaloriesShare: Double?
    let fiberG: OptionalAverageDTO?
    let sugarG: OptionalAverageDTO?
    let sodiumMg: OptionalAverageDTO?
    /// Missing on servers from before vitamins and minerals (backend #25).
    let micronutrientAverages: [String: OptionalAverageDTO]?

    enum CodingKeys: String, CodingKey, CaseIterable {
        case firstDay = "first_day"
        case lastDay = "last_day"
        case countedDays = "counted_days"
        case loggedDays = "logged_days"
        case averages
        case estimatedCaloriesShare = "estimated_calories_share"
        case fiberG = "fiber_g"
        case sugarG = "sugar_g"
        case sodiumMg = "sodium_mg"
        case micronutrientAverages = "micronutrient_averages"
    }
}

nonisolated struct TrendsDTO: Decodable, Sendable {
    let windowDays: Int
    let countingRule: String
    let current: PeriodDTO
    let previous: PeriodDTO
    let change: NutrientsDTO?

    enum CodingKeys: String, CodingKey, CaseIterable {
        case windowDays = "window_days"
        case countingRule = "counting_rule"
        case current, previous, change
    }
}

nonisolated struct LeftOutDayDTO: Decodable, Sendable {
    let localDate: String
    let reason: String

    enum CodingKeys: String, CodingKey, CaseIterable {
        case localDate = "local_date"
        case reason
    }
}

nonisolated struct DayGroupDTO: Decodable, Sendable {
    let countedDays: Int
    let averages: NutrientsDTO?

    enum CodingKeys: String, CodingKey, CaseIterable {
        case countedDays = "counted_days"
        case averages
    }
}

nonisolated struct ProteinBucketDTO: Decodable, Sendable {
    let minG: Double
    let maxG: Double?
    let meals: Int

    enum CodingKeys: String, CodingKey, CaseIterable {
        case minG = "min_g"
        case maxG = "max_g"
        case meals
    }
}

nonisolated struct WeeklyReviewDTO: Decodable, Sendable {
    let firstDay: String
    let lastDay: String
    let countingRule: String
    let loggedDays: Int
    let completeDays: Int
    let countedDays: Int
    let averages: NutrientsDTO?
    let leftOut: [LeftOutDayDTO]
    let weekdays: DayGroupDTO
    let weekend: DayGroupDTO
    let mealCount: Int
    let proteinPerMealG: Double?
    let proteinBuckets: [ProteinBucketDTO]
    let lateMeals: Int
    let estimatedValuesShare: Double?
    let lowConfidenceMeals: Int

    enum CodingKeys: String, CodingKey, CaseIterable {
        case firstDay = "first_day"
        case lastDay = "last_day"
        case countingRule = "counting_rule"
        case loggedDays = "logged_days"
        case completeDays = "complete_days"
        case countedDays = "counted_days"
        case averages
        case leftOut = "left_out"
        case weekdays, weekend
        case mealCount = "meal_count"
        case proteinPerMealG = "protein_per_meal_g"
        case proteinBuckets = "protein_buckets"
        case lateMeals = "late_meals"
        case estimatedValuesShare = "estimated_values_share"
        case lowConfidenceMeals = "low_confidence_meals"
    }
}

nonisolated struct TargetRangeDTO: Codable, Sendable {
    let min: Double?
    let max: Double?

    enum CodingKeys: String, CodingKey, CaseIterable {
        case min, max
    }
}

nonisolated struct TargetsDTO: Decodable, Sendable {
    let caloriesKcal: TargetRangeDTO?
    let proteinG: TargetRangeDTO?
    let fatG: TargetRangeDTO?
    let carbohydratesG: TargetRangeDTO?

    enum CodingKeys: String, CodingKey, CaseIterable {
        case caloriesKcal = "calories_kcal"
        case proteinG = "protein_g"
        case fatG = "fat_g"
        case carbohydratesG = "carbohydrates_g"
    }
}

nonisolated struct SettingsDTO: Decodable, Sendable {
    let timezone: String?
    let energyUnit: String
    let calmMode: Bool
    let targets: TargetsDTO
    /// Missing on servers from before weight tracking.
    let weightTracking: Bool?
    let weightUnit: String?

    enum CodingKeys: String, CodingKey, CaseIterable {
        case timezone
        case energyUnit = "energy_unit"
        case calmMode = "calm_mode"
        case targets
        case weightTracking = "weight_tracking"
        case weightUnit = "weight_unit"
    }
}

nonisolated struct WidgetTokenDTO: Decodable, Sendable {
    let token: String

    enum CodingKeys: String, CodingKey, CaseIterable {
        case token
    }
}

nonisolated struct WeightEntryDTO: Decodable, Sendable {
    let id: UUID
    let weightKg: Double
    let measuredAt: Date
    let localDate: String
    let source: String
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey, CaseIterable {
        case id
        case weightKg = "weight_kg"
        case measuredAt = "measured_at"
        case localDate = "local_date"
        case source
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

nonisolated struct TrendPointDTO: Decodable, Sendable {
    let date: String
    let weightKg: Double
    let trendKg: Double

    enum CodingKeys: String, CodingKey, CaseIterable {
        case date
        case weightKg = "weight_kg"
        case trendKg = "trend_kg"
    }
}

nonisolated struct WeightsDTO: Decodable, Sendable {
    let firstDay: String
    let lastDay: String
    let entries: [WeightEntryDTO]
    let trend: [TrendPointDTO]
    let latestTrendKg: Double?
    let weeklyChangeKg: Double?
    let changeDays: Int?

    enum CodingKeys: String, CodingKey, CaseIterable {
        case firstDay = "first_day"
        case lastDay = "last_day"
        case entries, trend
        case latestTrendKg = "latest_trend_kg"
        case weeklyChangeKg = "weekly_change_kg"
        case changeDays = "change_days"
    }
}

nonisolated struct WeightsCreatedDTO: Decodable, Sendable {
    let entries: [WeightEntryDTO]

    enum CodingKeys: String, CodingKey, CaseIterable {
        case entries
    }
}

nonisolated struct WeightsDeletedDTO: Decodable, Sendable {
    let deleted: Int

    enum CodingKeys: String, CodingKey, CaseIterable {
        case deleted
    }
}

nonisolated struct ExpenditureDTO: Decodable, Sendable {
    let firstDay: String
    let lastDay: String
    let countingRule: String
    let countedDays: Int
    let weighIns: Int
    let weighInDays: Int
    let averageIntakeKcal: Double?
    let trendChangeKg: Double?
    let spanDays: Int?
    let maintenanceKcal: Double?
    let confidence: String?
    let reason: String?

    enum CodingKeys: String, CodingKey, CaseIterable {
        case firstDay = "first_day"
        case lastDay = "last_day"
        case countingRule = "counting_rule"
        case countedDays = "counted_days"
        case weighIns = "weigh_ins"
        case weighInDays = "weigh_in_days"
        case averageIntakeKcal = "average_intake_kcal"
        case trendChangeKg = "trend_change_kg"
        case spanDays = "span_days"
        case maintenanceKcal = "maintenance_kcal"
        case confidence, reason
    }
}

nonisolated struct IntegrationStatusDTO: Decodable, Sendable {
    let lastMealSavedAt: Date?
    let lastClientName: String?
    let mealsToday: Int
    /// "ok", "quiet" or "unknown"; missing on servers from before the field existed.
    let arrivalStatus: String?

    enum CodingKeys: String, CodingKey, CaseIterable {
        case lastMealSavedAt = "last_meal_saved_at"
        case lastClientName = "last_client_name"
        case mealsToday = "meals_today"
        case arrivalStatus = "arrival_status"
    }
}

nonisolated struct GrantDTO: Decodable, Sendable {
    let grantId: UUID
    let createdAt: Date
    let lastUsedAt: Date?
    let current: Bool

    enum CodingKeys: String, CodingKey, CaseIterable {
        case grantId = "grant_id"
        case createdAt = "created_at"
        case lastUsedAt = "last_used_at"
        case current
    }
}

nonisolated struct ConnectionDTO: Decodable, Sendable {
    let clientId: String
    let name: String?
    let kind: String
    let grants: [GrantDTO]

    enum CodingKeys: String, CodingKey, CaseIterable {
        case clientId = "client_id"
        case name, kind, grants
    }
}

nonisolated struct ConnectionsDTO: Decodable, Sendable {
    let connections: [ConnectionDTO]

    enum CodingKeys: String, CodingKey, CaseIterable {
        case connections
    }
}

nonisolated struct RevokeDTO: Decodable, Sendable {
    let grantId: UUID
    let signedOut: Bool

    enum CodingKeys: String, CodingKey, CaseIterable {
        case grantId = "grant_id"
        case signedOut = "signed_out"
    }
}

nonisolated struct MeDTO: Decodable, Sendable {
    let id: UUID
    let displayName: String?
    let email: String?
    let linkedLogins: [String]

    enum CodingKeys: String, CodingKey, CaseIterable {
        case id
        case displayName = "display_name"
        case email
        case linkedLogins = "linked_logins"
    }
}

nonisolated struct LoginDTO: Decodable, Sendable {
    let id: UUID
    let provider: String
    let email: String?
    let createdAt: Date
    let lastLoginAt: Date?

    enum CodingKeys: String, CodingKey, CaseIterable {
        case id
        case provider
        case email
        case createdAt = "created_at"
        case lastLoginAt = "last_login_at"
    }
}

nonisolated struct LoginListDTO: Decodable, Sendable {
    let logins: [LoginDTO]

    enum CodingKeys: String, CodingKey, CaseIterable {
        case logins
    }
}

nonisolated struct LinkStartDTO: Decodable, Sendable {
    let url: URL
    let expiresAt: Date

    enum CodingKeys: String, CodingKey, CaseIterable {
        case url
        case expiresAt = "expires_at"
    }
}

nonisolated struct LinkCompleteDTO: Decodable, Sendable {
    /// "linked" or "already_linked".
    let result: String

    enum CodingKeys: String, CodingKey, CaseIterable {
        case result
    }
}

/// Field names of request bodies, checked against the contract like the response keys.
nonisolated enum RequestFields {
    static let mealUpdate = [
        "dish_name", "portion_grams", "calories_kcal", "protein_g", "fat_g", "carbohydrates_g",
        "fiber_g", "sugar_g", "sodium_mg", "eaten_at",
    ]
    static let mealRelog = ["id", "eaten_at"]
    static let settingsUpdate = ["timezone", "energy_unit", "calm_mode", "targets", "weight_tracking", "weight_unit"]
    static let weightCreate = ["weight_kg", "measured_at", "source", "external_id"]
    static let weightsCreate = ["entries"]
    static let weightUpdate = ["weight_kg", "measured_at"]
    static let deleteAllWeights = ["confirm"]
    static let appleHealthDeletions = ["external_ids"]
    static let dayStatusUpdate = ["status"]
    static let deleteAccount = ["confirm"]
    static let linkStart = ["code_challenge", "code_challenge_method"]
    static let linkComplete = ["code", "code_verifier"]
}
