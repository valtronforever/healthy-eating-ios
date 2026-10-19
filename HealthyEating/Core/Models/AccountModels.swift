import Foundation

/// The signed-in account (`GET /api/v1/me`).
nonisolated struct Account: Sendable, Equatable {
    var displayName: String?
    var email: String?
    /// Social logins linked to the account: "google", "microsoft", "apple" (or "dev").
    var linkedLogins: [String]

    /// "Google and Apple" for the account row.
    var loginsText: String {
        let names = linkedLogins.map { login -> String in
            switch login {
            case "google": "Google"
            case "microsoft": "Microsoft"
            case "apple": "Apple"
            default: login.capitalized
            }
        }
        return names.formatted(.list(type: .and))
    }
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

/// Averages per counted day for one window (`GET /api/v1/trends`).
nonisolated struct TrendPeriod: Sendable, Equatable {
    var firstDay: Date
    var lastDay: Date
    var countedDays: Int
    var loggedDays: Int
    var averages: NutrientValues?
    var estimatedCaloriesShare: Double?
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
}

/// Is the assistant integration working? (`GET /api/v1/integration-status`)
nonisolated struct IntegrationState: Sendable, Equatable {
    var lastMealSavedAt: Date?
    var lastAssistant: String?
    var mealsToday: Int
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
