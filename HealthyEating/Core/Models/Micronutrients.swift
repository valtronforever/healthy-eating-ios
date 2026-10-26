import Foundation

/// Vitamins and minerals (backend #25). The server computes them from USDA reference data for
/// the food items the assistant listed; the app only shows them. Codes match the API, and the
/// unit is the code's suffix.
nonisolated enum Micronutrient: String, Sendable, CaseIterable, Identifiable {
    case vitaminA = "vitamin_a_ug"
    case vitaminC = "vitamin_c_mg"
    case vitaminD = "vitamin_d_ug"
    case vitaminE = "vitamin_e_mg"
    case vitaminK = "vitamin_k_ug"
    case thiamin = "thiamin_mg"
    case riboflavin = "riboflavin_mg"
    case niacin = "niacin_mg"
    case vitaminB6 = "vitamin_b6_mg"
    case folate = "folate_ug"
    case vitaminB12 = "vitamin_b12_ug"
    case calcium = "calcium_mg"
    case iron = "iron_mg"
    case magnesium = "magnesium_mg"
    case phosphorus = "phosphorus_mg"
    case potassium = "potassium_mg"
    case zinc = "zinc_mg"
    case selenium = "selenium_ug"

    var id: String { rawValue }

    var name: String {
        switch self {
        case .vitaminA: String(localized: "Vitamin A")
        case .vitaminC: String(localized: "Vitamin C")
        case .vitaminD: String(localized: "Vitamin D")
        case .vitaminE: String(localized: "Vitamin E")
        case .vitaminK: String(localized: "Vitamin K")
        case .thiamin: String(localized: "Thiamin (B1)")
        case .riboflavin: String(localized: "Riboflavin (B2)")
        case .niacin: String(localized: "Niacin (B3)")
        case .vitaminB6: String(localized: "Vitamin B6")
        case .folate: String(localized: "Folate")
        case .vitaminB12: String(localized: "Vitamin B12")
        case .calcium: String(localized: "Calcium")
        case .iron: String(localized: "Iron")
        case .magnesium: String(localized: "Magnesium")
        case .phosphorus: String(localized: "Phosphorus")
        case .potassium: String(localized: "Potassium")
        case .zinc: String(localized: "Zinc")
        case .selenium: String(localized: "Selenium")
        }
    }

    var unit: NutrientUnit { rawValue.hasSuffix("_ug") ? .micrograms : .milligrams }

    var isVitamin: Bool { self.rawValue.hasPrefix("vitamin") || [.thiamin, .riboflavin, .niacin, .folate].contains(self) }

    static var vitamins: [Micronutrient] { allCases.filter(\.isVitamin) }
    static var minerals: [Micronutrient] { allCases.filter { !$0.isVitamin } }
}

/// A food of a meal with its weight, and the USDA food its vitamins and minerals came from.
nonisolated struct MealItem: Hashable, Sendable {
    enum Status: String, Sendable {
        /// Its vitamins and minerals come from `foodDescription`.
        case matched
        /// No reference food fits well enough: it has none.
        case weak, none
    }

    var name: String
    var grams: Double
    var status: Status
    var foodDescription: String?
}

nonisolated extension NutritionFormat {
    /// A vitamin or mineral amount: whole numbers from 10, one decimal from 1, two below
    /// ("0.25 mg", "2.4 µg", "18 mg").
    static func micronutrient(_ value: Double, _ unit: NutrientUnit, locale: Locale = .current) -> String {
        let digits = value >= 10 ? 0 : value >= 1 ? 1 : 2
        let number = value.formatted(.number.precision(.fractionLength(0...digits)).locale(locale))
        return "\(number) \(unit.symbol)"
    }
}
