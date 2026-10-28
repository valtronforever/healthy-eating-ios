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

/// The optional life stage whose reference values Settings shows for vitamins and minerals
/// (backend #34). The person picks it; no birth date or age is stored.
nonisolated enum ReferenceGroup: String, Sendable, CaseIterable {
    case women19to30 = "women_19_30"
    case women31to50 = "women_31_50"
    case women51to70 = "women_51_70"
    case women71plus = "women_71_plus"
    case men19to30 = "men_19_30"
    case men31to50 = "men_31_50"
    case men51to70 = "men_51_70"
    case men71plus = "men_71_plus"
    case pregnancy19to30 = "pregnancy_19_30"
    case pregnancy31to50 = "pregnancy_31_50"
    case breastfeeding19to30 = "breastfeeding_19_30"
    case breastfeeding31to50 = "breastfeeding_31_50"

    /// The server's name, also the two names from before backend #34, which used the values
    /// for ages 31 to 50.
    init?(serverName: String) {
        switch serverName {
        case "adult_women": self = .women31to50
        case "adult_men": self = .men31to50
        default: self.init(rawValue: serverName)
        }
    }

    /// "Women 31–50", "Breastfeeding 19–30".
    var name: String { "\(stage.name) \(ages)" }

    var stage: Stage {
        switch self {
        case .women19to30, .women31to50, .women51to70, .women71plus: .women
        case .men19to30, .men31to50, .men51to70, .men71plus: .men
        case .pregnancy19to30, .pregnancy31to50: .pregnancy
        case .breastfeeding19to30, .breastfeeding31to50: .breastfeeding
        }
    }

    /// "19–30", "71 and older".
    var ages: String {
        switch self {
        case .women19to30, .men19to30, .pregnancy19to30, .breastfeeding19to30: String(localized: "19–30")
        case .women31to50, .men31to50, .pregnancy31to50, .breastfeeding31to50: String(localized: "31–50")
        case .women51to70, .men51to70: String(localized: "51–70")
        case .women71plus, .men71plus: String(localized: "71 and older")
        }
    }

    nonisolated enum Stage: CaseIterable {
        case women, men, pregnancy, breastfeeding

        var name: String {
            switch self {
            case .women: String(localized: "Women")
            case .men: String(localized: "Men")
            case .pregnancy: String(localized: "Pregnancy")
            case .breastfeeding: String(localized: "Breastfeeding")
            }
        }

        var groups: [ReferenceGroup] { ReferenceGroup.allCases.filter { $0.stage == self } }
    }
}

/// A reference value from the server: `min` is the RDA or AI, `max` the upper limit where it
/// applies to food. Reference values, never targets.
nonisolated struct ReferenceRange: Hashable, Sendable {
    var min: Double
    var max: Double?
}

/// The daily range that applies to a vitamin or mineral (backend #35): the person's own goal,
/// else the reference of their life stage. Either bound may be open for a goal.
nonisolated struct MicronutrientRange: Hashable, Sendable {
    enum Source: String, Sendable {
        case reference, personal
    }

    var min: Double?
    var max: Double?
    var source: Source
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

/// A supplement or packaged food whose vitamins and minerals come from its label or the person,
/// never estimated (server status `label`).
nonisolated struct LabelItem: Hashable, Sendable {
    var name: String
    /// Weight, when known (a capsule has none).
    var grams: Double?
    var values: [Micronutrient: Double]
}

nonisolated extension NutritionFormat {
    /// "Reference 8–45 mg", "Reference at least 1.1 mg", "Your goal at least 50 µg", "Your goal
    /// up to 30 mg": never "target", never judged.
    static func range(_ range: MicronutrientRange, _ unit: NutrientUnit, locale: Locale = .current) -> String {
        let amount = { (v: Double) in micronutrient(v, unit, locale: locale) }
        let number = { (v: Double) in amount(v).replacingOccurrences(of: " \(unit.symbol)", with: "") }
        let goal = range.source == .personal
        switch (range.min, range.max) {
        case let (low?, high?):
            return goal
                ? String(localized: "Your goal \(number(low))–\(amount(high))")
                : String(localized: "Reference \(number(low))–\(amount(high))")
        case let (low?, nil):
            return goal
                ? String(localized: "Your goal at least \(amount(low))")
                : String(localized: "Reference at least \(amount(low))")
        case let (nil, high?):
            return goal
                ? String(localized: "Your goal up to \(amount(high))")
                : String(localized: "Reference up to \(amount(high))")
        case (nil, nil):
            return ""
        }
    }

    /// "5.3 milligrams, reference 8 to 45 milligrams" for VoiceOver.
    static func spokenRange(value: Double, _ range: MicronutrientRange, _ unit: NutrientUnit, locale: Locale = .current) -> String {
        let spoken = { (v: Double) in unit.spokenValue(micronutrient(v, unit, locale: locale).replacingOccurrences(of: " \(unit.symbol)", with: "")) }
        let goal = range.source == .personal
        switch (range.min, range.max) {
        case let (low?, high?):
            return goal
                ? String(localized: "\(spoken(value)), your goal \(spoken(low)) to \(spoken(high))")
                : String(localized: "\(spoken(value)), reference \(spoken(low)) to \(spoken(high))")
        case let (low?, nil):
            return goal
                ? String(localized: "\(spoken(value)), your goal at least \(spoken(low))")
                : String(localized: "\(spoken(value)), reference at least \(spoken(low))")
        case let (nil, high?):
            return goal
                ? String(localized: "\(spoken(value)), your goal up to \(spoken(high))")
                : String(localized: "\(spoken(value)), reference up to \(spoken(high))")
        case (nil, nil):
            return spoken(value)
        }
    }

    /// A vitamin or mineral amount: whole numbers from 10, one decimal from 1, two below
    /// ("0.25 mg", "2.4 µg", "18 mg").
    static func micronutrient(_ value: Double, _ unit: NutrientUnit, locale: Locale = .current) -> String {
        let digits = value >= 10 ? 0 : value >= 1 ? 1 : 2
        let number = value.formatted(.number.precision(.fractionLength(0...digits)).locale(locale))
        return "\(number) \(unit.symbol)"
    }
}
