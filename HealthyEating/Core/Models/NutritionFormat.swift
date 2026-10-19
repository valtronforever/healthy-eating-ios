import Foundation

/// Canonical units the backend returns. The app formats them, it never converts or recomputes them.
nonisolated enum NutrientUnit: Sendable {
    case kcal, kilojoules, grams

    var symbol: String {
        switch self {
        case .kcal: String(localized: "kcal", comment: "Unit symbol for kilocalories")
        case .kilojoules: String(localized: "kJ", comment: "Unit symbol for kilojoules")
        case .grams: String(localized: "g", comment: "Unit symbol for grams")
        }
    }

    func spokenValue(_ formattedNumber: String) -> String {
        switch self {
        case .kcal: String(localized: "\(formattedNumber) kilocalories")
        case .kilojoules: String(localized: "\(formattedNumber) kilojoules")
        case .grams: String(localized: "\(formattedNumber) grams")
        }
    }
}

/// The unit the person wants energy shown in (a server setting). Values always arrive in kcal;
/// kJ is a display conversion only.
nonisolated enum EnergyUnit: String, Sendable, CaseIterable {
    case kcal
    case kj

    var nutrientUnit: NutrientUnit {
        self == .kcal ? .kcal : .kilojoules
    }

    /// The value in this unit, converted with `Measurement` (1 kcal = 4.184 kJ).
    func amount(fromKcal kcal: Double) -> Double {
        switch self {
        case .kcal: kcal
        case .kj: Measurement(value: kcal, unit: UnitEnergy.kilocalories).converted(to: .kilojoules).value
        }
    }
}

/// Display formatting for nutrition values, following the design system's copy rules:
/// locale grouping ("1,200"), the unit after a space ("77 g"), ranges with an en dash and
/// no spaces ("1,900–2,200 kcal").
nonisolated enum NutritionFormat {
    static func number(_ value: Double, locale: Locale = .current) -> String {
        value.formatted(.number.precision(.fractionLength(0)).locale(locale))
    }

    static func value(_ value: Double, _ unit: NutrientUnit, locale: Locale = .current) -> String {
        "\(number(value, locale: locale)) \(unit.symbol)"
    }

    static func range(_ min: Double, _ max: Double, _ unit: NutrientUnit? = nil, locale: Locale = .current) -> String {
        let numbers = "\(number(min, locale: locale))–\(number(max, locale: locale))"
        guard let unit else { return numbers }
        return "\(numbers) \(unit.symbol)"
    }

    /// An energy value from the backend (always kcal), shown in the person's unit.
    static func energy(_ kcal: Double, in unit: EnergyUnit, locale: Locale = .current) -> String {
        value(unit.amount(fromKcal: kcal), unit.nutrientUnit, locale: locale)
    }

    /// An energy range (a target) in the person's unit.
    static func energyRange(_ minKcal: Double, _ maxKcal: Double, in unit: EnergyUnit, locale: Locale = .current) -> String {
        range(unit.amount(fromKcal: minKcal), unit.amount(fromKcal: maxKcal), unit.nutrientUnit, locale: locale)
    }

    /// The short macro line of a meal row: "P 46 g · F 18 g · C 62 g".
    static func macroLine(protein: Double, fat: Double, carbs: Double, locale: Locale = .current) -> String {
        let p = value(protein, .grams, locale: locale)
        let f = value(fat, .grams, locale: locale)
        let c = value(carbs, .grams, locale: locale)
        return String(localized: "P \(p) · F \(f) · C \(c)", comment: "Macro line: protein, fat, carbohydrates")
    }

    /// VoiceOver phrase for a value against its target: "77 grams, target 110 to 140 grams".
    static func spokenRange(value: Double, min: Double, max: Double, unit: NutrientUnit, locale: Locale = .current) -> String {
        let spokenValue = unit.spokenValue(number(value, locale: locale))
        let low = number(min, locale: locale)
        let high = unit.spokenValue(number(max, locale: locale))
        return String(localized: "\(spokenValue), target \(low) to \(high)")
    }
}

/// Relative times for status lines: "just now", "20 min ago", "2 h ago", "yesterday at 20:15".
nonisolated enum RelativeTimeFormat {
    static func string(for date: Date, now: Date = .now, calendar: Calendar = .current, locale: Locale = .current) -> String {
        let seconds = now.timeIntervalSince(date)
        if seconds < 60 {
            return String(localized: "just now")
        }
        if seconds < 3600 {
            let minutes = Int(seconds / 60)
            return String(localized: "\(minutes) min ago")
        }
        let time = date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: locale, calendar: calendar, timeZone: calendar.timeZone))
        if calendar.isDate(date, inSameDayAs: now) {
            let hours = Int(seconds / 3600)
            return String(localized: "\(hours) h ago")
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: yesterday) {
            return String(localized: "yesterday at \(time)")
        }
        let day = date.formatted(Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).month(.abbreviated).day())
        return String(localized: "\(day) at \(time)")
    }
}
