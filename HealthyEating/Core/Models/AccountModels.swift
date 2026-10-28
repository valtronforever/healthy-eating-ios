import Foundation

/// The signed-in account (`GET /api/v1/me`).
nonisolated struct Account: Sendable, Equatable {
    var displayName: String?
    var email: String?
    /// Social logins linked to the account: "google", "microsoft", "apple" (or "dev").
    var linkedLogins: [String]

    /// "Google and Apple" for the account row; two logins of one provider name it once.
    var loginsText: String {
        var names: [String] = []
        for name in linkedLogins.map(Login.providerName) where !names.contains(name) {
            names.append(name)
        }
        return names.formatted(.list(type: .and))
    }
}

/// One social login that signs in to the account (`GET /api/v1/me/logins`, #20).
nonisolated struct Login: Identifiable, Sendable, Equatable {
    let id: UUID
    /// "google", "microsoft", "apple" (or "dev" on development servers).
    var provider: String
    var email: String?
    var createdAt: Date
    var lastLoginAt: Date?

    var providerName: String { Self.providerName(provider) }

    static func providerName(_ provider: String) -> String {
        switch provider {
        case "google": "Google"
        case "microsoft": "Microsoft"
        case "apple": "Apple"
        default: provider.capitalized
        }
    }
}

/// How adding a login ended. Accounts are never merged: a login of another account stays there.
nonisolated enum LinkResult: Sendable, Equatable {
    case linked
    /// It was one of this account's logins already.
    case alreadyLinked
    /// It belongs to another Healthy Eating account, so it was not added.
    case otherAccount
    /// The person closed the web sheet or chose Cancel there.
    case cancelled
}

/// A day's totals and completeness, computed by the backend (`GET /api/v1/days`).
nonisolated struct DayTotals: Identifiable, Hashable, Sendable {
    /// The local day, as midnight in the device calendar.
    let date: Date
    var mealCount: Int
    var caloriesKcal: Double
    var proteinG: Double
    var fatG: Double
    var carbohydratesG: Double
    /// Share of the day's calories the assistant estimated (0 to 1); nil without calories.
    var estimatedCaloriesShare: Double?
    var status: DayMark?
    var markedBy: MarkSetter?
    /// Whether the day counts for averages.
    var counted: Bool
    /// Fiber, sugar and sodium over the meals of the day that have them.
    var optional: [OptionalNutrient: OptionalTotal] = [:]
    /// Vitamins and minerals over the meals of the day that have them.
    var micronutrients: [Micronutrient: OptionalTotal] = [:]

    var id: Date { date }

    /// The calendar shape. A marked day shows its mark. An unmarked day with meals looks complete
    /// when it counts for averages (the person never marks days) and partial when it does not
    /// (once they mark days, unmarked ones are left out).
    var state: DayState {
        if status == .complete { return .complete }
        if status == .partial { return .partial }
        guard mealCount > 0 else { return .none }
        return counted ? .complete : .partial
    }
}

/// A day the person (or their assistant) marked.
nonisolated enum DayMark: String, Sendable, Codable {
    case complete, partial
}

nonisolated enum MarkSetter: String, Sendable, Codable {
    case user, assistant
}

/// Which days count for averages: only complete ones once any day is marked complete.
nonisolated enum CountingRule: String, Sendable, Codable {
    case completeDays = "complete_days"
    case loggedDays = "logged_days"
}

nonisolated struct DayRange: Sendable {
    var days: [DayTotals]
    var countingRule: CountingRule
}

/// An optional nutrient's day total, over the meals that have a value for it.
nonisolated struct OptionalTotal: Sendable, Hashable {
    var amount: Double
    var mealCount: Int
}

/// An optional nutrient's average, over the counted days that have a value for it.
nonisolated struct OptionalAverage: Sendable, Hashable {
    var average: Double
    var days: Int
}

/// Averages per counted day for one window (`GET /api/v1/trends`).
nonisolated struct TrendPeriod: Sendable, Equatable {
    var firstDay: Date
    var lastDay: Date
    var countedDays: Int
    var loggedDays: Int
    var averages: NutrientValues?
    var estimatedCaloriesShare: Double?
    var optionalAverages: [OptionalNutrient: OptionalAverage] = [:]
    /// Vitamins and minerals over the counted days on which every meal has a value.
    var micronutrientAverages: [Micronutrient: OptionalAverage] = [:]
}

nonisolated struct NutrientValues: Sendable, Equatable {
    var caloriesKcal: Double
    var proteinG: Double
    var fatG: Double
    var carbohydratesG: Double

    func value(of macro: Macro) -> Double {
        switch macro {
        case .protein: proteinG
        case .fat: fatG
        case .carbs: carbohydratesG
        }
    }
}

nonisolated struct Trends: Sendable, Equatable {
    var windowDays: Int
    var countingRule: CountingRule
    var current: TrendPeriod
    var previous: TrendPeriod
    /// current minus previous; nil unless both have counted days.
    var change: NutrientValues?
}

/// One local week, Monday to Sunday, as neutral facts (`GET /api/v1/weekly-review`).
nonisolated struct WeeklyReview: Sendable, Equatable {
    /// Why the averages leave a day out.
    enum LeftOutReason: String, Sendable {
        case future
        case inProgress = "in_progress"
        case notLogged = "not_logged"
        case partial
        case notMarkedComplete = "not_marked_complete"
    }

    struct LeftOutDay: Sendable, Equatable {
        var date: Date
        var reason: LeftOutReason
    }

    struct DayGroup: Sendable, Equatable {
        var countedDays: Int
        var averages: NutrientValues?
    }

    struct ProteinBucket: Sendable, Equatable {
        var minG: Double
        /// nil for the last, open bucket.
        var maxG: Double?
        var meals: Int
    }

    var firstDay: Date
    var lastDay: Date
    var countingRule: CountingRule
    var loggedDays: Int
    var completeDays: Int
    var countedDays: Int
    /// Average per counted day, counted like Trends; nil when no day counts.
    var averages: NutrientValues?
    var leftOut: [LeftOutDay]
    var weekdays: DayGroup
    var weekend: DayGroup
    /// Every meal of the week, counted day or not.
    var mealCount: Int
    var proteinPerMealG: Double?
    var proteinBuckets: [ProteinBucket]
    var lateMeals: Int
    /// Share of the meals' values the assistant estimated (0 to 1); the rest are the person's own.
    var estimatedValuesShare: Double?
    var lowConfidenceMeals: Int
    /// Vitamins and minerals over the counted days on which every meal has a value.
    var micronutrientAverages: [Micronutrient: OptionalAverage] = [:]
}

/// A target range; either bound may be open. Targets are ranges, never limits.
nonisolated struct TargetRange: Sendable, Equatable {
    var min: Double?
    var max: Double?
}

/// The person's settings, stored on their server (`/api/v1/me/settings`).
nonisolated struct UserSettings: Sendable, Equatable {
    var timeZone: String?
    var energyUnit: EnergyUnit
    var calmMode: Bool
    var targets: [NutrientField: TargetRange]
    /// Opt-in: off until the first weigh-in or until the person turns it on. Off hides weight.
    var weightTracking = false
    var weightUnit: WeightUnit = .kg
    /// Optional; nil shows vitamins and minerals without reference values.
    var referenceGroup: ReferenceGroup?
    /// The group's reference values from the server; empty when the group is off.
    var micronutrientReferences: [Micronutrient: ReferenceRange] = [:]
    /// The person's own vitamin and mineral ranges (backend #35); only nutrients with one.
    var micronutrientGoals: [Micronutrient: TargetRange] = [:]
    /// The range that applies per nutrient: the goal, else the reference; from the server.
    var micronutrientRanges: [Micronutrient: MicronutrientRange] = [:]
}

/// The unit the person wants weight shown in (a server setting). Values always arrive in kg.
nonisolated enum WeightUnit: String, Sendable, CaseIterable {
    case kg, lb

    static let kgPerLb = 0.45359237

    var symbol: String {
        switch self {
        case .kg: String(localized: "kg", comment: "Unit symbol for kilograms")
        case .lb: String(localized: "lb", comment: "Unit symbol for pounds")
        }
    }

    func amount(fromKg kg: Double) -> Double { self == .kg ? kg : kg / Self.kgPerLb }
    func kg(from amount: Double) -> Double { self == .kg ? amount : amount * Self.kgPerLb }
}

nonisolated enum WeightSource: String, Sendable {
    case app, assistant
    case appleHealth = "apple_health"
}

/// One weigh-in (`/api/v1/weights`).
nonisolated struct WeighIn: Identifiable, Sendable, Hashable {
    let id: UUID
    var weightKg: Double
    var measuredAt: Date
    var source: WeightSource
    /// When the server last changed it (Apple Health sync version); nil in sample data.
    var updatedAt: Date?
}

/// The smoothed trend after a day with weigh-ins.
nonisolated struct WeightTrendDay: Sendable, Hashable {
    /// The local day, as midnight in the device calendar.
    var date: Date
    /// Mean of the day's weigh-ins.
    var weightKg: Double
    var trendKg: Double
}

nonisolated struct WeightHistory: Sendable, Equatable {
    var firstDay: Date
    var lastDay: Date
    /// Oldest first.
    var entries: [WeighIn]
    var trend: [WeightTrendDay]
    var latestTrendKg: Double?
    /// Trend change per 7 days over the last 28 days; nil when the history is too short.
    var weeklyChangeKg: Double?
    var changeDays: Int?
}

/// "You maintain at about X kcal", from the person's own log and weight trend
/// (`/api/v1/expenditure`).
nonisolated struct EnergyEstimate: Sendable, Equatable {
    enum MissingData: String, Sendable {
        case loggedDays = "not_enough_logged_days"
        case weighIns = "not_enough_weigh_ins"
    }

    var countedDays: Int
    var weighIns: Int
    var weighInDays: Int
    var averageIntakeKcal: Double?
    var maintenanceKcal: Double?
    var confidence: Confidence?
    var missing: MissingData?
}

/// Is the assistant integration working? (`GET /api/v1/integration-status`)
nonisolated struct IntegrationState: Sendable, Equatable {
    var lastMealSavedAt: Date?
    var lastAssistant: String?
    var mealsToday: Int
    /// Whether meals still arrive as usual, judged by the server from the person's own pattern.
    var arrival: ArrivalStatus = .unknown
}

/// The server's `arrival_status`: about the integration, never about how much the person eats.
nonisolated enum ArrivalStatus: String, Sendable {
    /// Meals arrive as usual.
    case ok
    /// Nothing arrived yesterday, or today later than usual: the assistant may not be saving meals.
    case quiet
    /// New account, irregular pattern, or a server without the field.
    case unknown
}

/// An AI assistant or app session signed in to the account (`GET /api/v1/connections`).
nonisolated struct Connection: Identifiable, Sendable, Equatable {
    enum Kind: String, Sendable { case aiAssistant = "ai_assistant", iosApp = "ios_app" }

    struct SignIn: Identifiable, Sendable, Equatable {
        let id: UUID
        var createdAt: Date
        var lastUsedAt: Date?
        /// The sign-in of this app.
        var isCurrent: Bool
    }

    let id: String
    var name: String?
    var kind: Kind
    var signIns: [SignIn]
}
