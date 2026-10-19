import Foundation

/// Where a meal's numbers came from. The design system allows exactly these two labels.
nonisolated enum Provenance: String, Sendable, CaseIterable {
    /// The person's own calculation ("Your numbers").
    case user
    /// The assistant's estimate ("Estimated").
    case estimated
}

/// How sure the assistant was about an estimate. Only shown for estimated values.
nonisolated enum Confidence: String, Sendable, CaseIterable {
    case low, medium, high
}

/// The three macronutrients, in the order the app always shows them.
nonisolated enum Macro: String, Sendable, CaseIterable, Identifiable {
    case protein, fat, carbs

    var id: String { rawValue }

    /// Full localized name: "Protein", "Fat", "Carbohydrates".
    var name: String {
        switch self {
        case .protein: String(localized: "Protein")
        case .fat: String(localized: "Fat")
        case .carbs: String(localized: "Carbohydrates")
        }
    }
}

/// How completely a calendar day was logged. Shown as a shape, never as a color alone.
nonisolated enum DayState: String, Sendable {
    case complete, partial, none, future
}

/// The four values every meal has, with the backend's field names.
nonisolated enum NutrientField: String, Sendable, CaseIterable, Codable {
    case calories = "calories_kcal"
    case protein = "protein_g"
    case fat = "fat_g"
    case carbohydrates = "carbohydrates_g"
}

/// One logged meal, as the backend stores it (`meals` table).
nonisolated struct Meal: Identifiable, Hashable, Sendable {
    let id: UUID
    var eatenAt: Date
    var dishName: String
    var caloriesKcal: Double
    var proteinG: Double
    var fatG: Double
    var carbohydratesG: Double
    var portionGrams: Double?
    /// Values the assistant estimated; the others came from the person's own calculation.
    var estimatedFields: Set<NutrientField>
    /// How sure the assistant was. Only shown for estimated values.
    var confidence: Confidence?
    /// The assistant that saved the meal, as plain text ("Claude", "ChatGPT").
    var assistant: String
    /// Where existing numbers came from, or a one-line explanation of an estimate.
    var sourceNote: String?

    /// "Estimated" as soon as one value was estimated; "Your numbers" otherwise.
    var provenance: Provenance { estimatedFields.isEmpty ? .user : .estimated }

    init(
        id: UUID, eatenAt: Date, dishName: String, caloriesKcal: Double, proteinG: Double, fatG: Double,
        carbohydratesG: Double, portionGrams: Double?, estimatedFields: Set<NutrientField>,
        confidence: Confidence?, assistant: String, sourceNote: String?
    ) {
        self.id = id
        self.eatenAt = eatenAt
        self.dishName = dishName
        self.caloriesKcal = caloriesKcal
        self.proteinG = proteinG
        self.fatG = fatG
        self.carbohydratesG = carbohydratesG
        self.portionGrams = portionGrams
        self.estimatedFields = estimatedFields
        self.confidence = confidence
        self.assistant = assistant
        self.sourceNote = sourceNote
    }

    /// Sample data and previews: every value estimated, or none.
    init(
        id: UUID, eatenAt: Date, dishName: String, caloriesKcal: Double, proteinG: Double, fatG: Double,
        carbohydratesG: Double, portionGrams: Double?, provenance: Provenance, confidence: Confidence?,
        assistant: String, sourceNote: String?
    ) {
        self.init(
            id: id, eatenAt: eatenAt, dishName: dishName, caloriesKcal: caloriesKcal, proteinG: proteinG,
            fatG: fatG, carbohydratesG: carbohydratesG, portionGrams: portionGrams,
            estimatedFields: provenance == .estimated ? Set(NutrientField.allCases) : [],
            confidence: confidence, assistant: assistant, sourceNote: sourceNote)
    }

    func grams(of macro: Macro) -> Double {
        switch macro {
        case .protein: proteinG
        case .fat: fatG
        case .carbs: carbohydratesG
        }
    }
}

/// A day's value for one macro against its target range.
nonisolated struct MacroProgress: Identifiable, Hashable, Sendable {
    let macro: Macro
    var value: Double
    var min: Double
    var max: Double

    var id: Macro { macro }
}

/// Calories for one day in a trend chart.
nonisolated struct KcalDay: Identifiable, Hashable, Sendable {
    let date: Date
    var kcal: Double
    var state: DayState

    var id: Date { date }
}

/// One day on the weight chart: an optional raw weigh-in and the smoothed trend.
nonisolated struct WeightPoint: Identifiable, Hashable, Sendable {
    let index: Int
    var raw: Double?
    var trend: Double

    var id: Int { index }
}
