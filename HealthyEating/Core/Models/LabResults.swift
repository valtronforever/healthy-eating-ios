import Foundation

/// The analytes the server knows (backend #37): it converts their values to a canonical unit
/// and names the vitamin or mineral they relate to. Any other result keeps only its printed name.
nonisolated enum LabAnalyte: String, Sendable, CaseIterable, Identifiable {
    case vitaminD = "vitamin_d_25oh"
    case vitaminB12 = "vitamin_b12"
    case folate
    case ferritin
    case iron
    case transferrinSaturation = "transferrin_saturation"
    case hemoglobin
    case magnesium
    case calcium
    case potassium
    case sodium
    case zinc
    case selenium
    case cholesterolTotal = "cholesterol_total"
    case ldlCholesterol = "ldl_cholesterol"
    case hdlCholesterol = "hdl_cholesterol"
    case triglycerides
    case glucose
    case hba1c
    case tsh

    var id: String { rawValue }

    var name: String {
        switch self {
        case .vitaminD: String(localized: "25-OH vitamin D")
        case .vitaminB12: String(localized: "Vitamin B12")
        case .folate: String(localized: "Folate")
        case .ferritin: String(localized: "Ferritin")
        case .iron: String(localized: "Serum iron")
        case .transferrinSaturation: String(localized: "Transferrin saturation")
        case .hemoglobin: String(localized: "Hemoglobin")
        case .magnesium: String(localized: "Magnesium")
        case .calcium: String(localized: "Calcium")
        case .potassium: String(localized: "Potassium")
        case .sodium: String(localized: "Sodium")
        case .zinc: String(localized: "Zinc")
        case .selenium: String(localized: "Selenium")
        case .cholesterolTotal: String(localized: "Total cholesterol")
        case .ldlCholesterol: String(localized: "LDL cholesterol")
        case .hdlCholesterol: String(localized: "HDL cholesterol")
        case .triglycerides: String(localized: "Triglycerides")
        case .glucose: String(localized: "Glucose")
        case .hba1c: String(localized: "HbA1c")
        case .tsh: String(localized: "TSH")
        }
    }
}

/// One lab report as the assistant saved it from the chat (backend #37): the sample day and
/// its results in the report's order. The app only shows and deletes them.
nonisolated struct LabReport: Sendable, Equatable, Identifiable {
    var id: UUID
    var takenOn: Date
    var results: [LabResult]
}

/// One value of a lab report, as printed, and in the analyte's canonical unit where the
/// server could convert it. Never judged: a value outside the lab's range looks like any other.
nonisolated struct LabResult: Sendable, Equatable, Identifiable {
    nonisolated enum Comparator: String, Sendable {
        case below = "<"
        case above = ">"
    }

    nonisolated struct Canonical: Sendable, Equatable {
        var value: Double
        var unit: String
        var referenceLow: Double?
        var referenceHigh: Double?
    }

    var id: UUID
    /// As printed on the report.
    var name: String
    var analyte: LabAnalyte?
    var value: Double
    /// Printed with the value, as in "< 0.5".
    var comparator: Comparator?
    var unit: String?
    /// The lab's range as printed, in `unit`.
    var referenceLow: Double?
    var referenceHigh: Double?
    var canonical: Canonical?
    var relatedNutrient: Micronutrient?
}

/// The results of one analyte over all reports: a known analyte by its code, any other by its
/// printed name (without case or surrounding spaces).
nonisolated struct LabAnalyteHistory: Sendable, Equatable, Identifiable {
    nonisolated struct Entry: Sendable, Equatable, Identifiable {
        var takenOn: Date
        var reportID: UUID
        var result: LabResult

        var id: UUID { result.id }
    }

    var id: String
    var title: String
    var analyte: LabAnalyte?
    /// Newest first; never empty.
    var entries: [Entry]

    var latest: Entry { entries[0] }
    var relatedNutrient: Micronutrient? { entries.lazy.compactMap(\.result.relatedNutrient).first }

    static func key(_ result: LabResult) -> String {
        if let analyte = result.analyte { return "analyte.\(analyte.rawValue)" }
        return "name.\(result.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
    }

    /// One history per analyte, ordered as the newest report lists them, then older ones.
    /// `reports` are newest first, as the server sends them.
    static func histories(_ reports: [LabReport]) -> [LabAnalyteHistory] {
        var order: [String] = []
        var byKey: [String: LabAnalyteHistory] = [:]
        for report in reports {
            for result in report.results {
                let key = key(result)
                let entry = Entry(takenOn: report.takenOn, reportID: report.id, result: result)
                if byKey[key] == nil {
                    order.append(key)
                    byKey[key] = LabAnalyteHistory(id: key, title: result.analyte?.name ?? result.name, analyte: result.analyte, entries: [])
                }
                byKey[key]?.entries.append(entry)
            }
        }
        return order.compactMap { byKey[$0] }
    }
}

/// What the analyte chart draws: printed values when all share a unit, else the server's
/// canonical values, else the values in the newest unit. The rest are counted as left out.
nonisolated struct LabChartSeries: Sendable, Equatable {
    nonisolated struct Point: Sendable, Equatable, Identifiable {
        var id: UUID
        var date: Date
        var value: Double
        var comparator: LabResult.Comparator?
        var low: Double?
        var high: Double?
    }

    var unit: String?
    /// Oldest first.
    var points: [Point]
    /// Shown in the canonical unit, converted from the units on the reports.
    var converted: Bool
    /// Values in another unit that could not be converted.
    var leftOut: Int

    /// The same range at every point: drawn as one band across the chart.
    var sharedRange: (low: Double?, high: Double?)? {
        guard let first = points.first, first.low != nil || first.high != nil else { return nil }
        let same = points.allSatisfy { $0.low == first.low && $0.high == first.high }
        return same ? (first.low, first.high) : nil
    }

    var hasRange: Bool { points.contains { $0.low != nil || $0.high != nil } }

    /// A unit as printed, compared without case, spaces or the spelling of micro (as the server does).
    static func unitKey(_ unit: String?) -> String {
        let key = (unit ?? "").filter { !$0.isWhitespace }.lowercased()
        return key.replacingOccurrences(of: "µ", with: "u").replacingOccurrences(of: "μ", with: "u")
            .replacingOccurrences(of: "mcg", with: "ug")
    }

    init(unit: String?, points: [Point], converted: Bool, leftOut: Int) {
        self.unit = unit
        self.points = points
        self.converted = converted
        self.leftOut = leftOut
    }

    init(_ history: LabAnalyteHistory) {
        let entries = history.entries
        let printed = { (entry: LabAnalyteHistory.Entry) in
            Point(id: entry.id, date: entry.takenOn, value: entry.result.value, comparator: entry.result.comparator,
                  low: entry.result.referenceLow, high: entry.result.referenceHigh)
        }
        let latestKey = Self.unitKey(history.latest.result.unit)
        if entries.allSatisfy({ Self.unitKey($0.result.unit) == latestKey }) {
            self.init(unit: history.latest.result.unit, points: entries.reversed().map(printed), converted: false, leftOut: 0)
            return
        }
        let canonical = entries.filter { $0.result.canonical != nil }
        if let unit = canonical.first?.result.canonical?.unit {
            let points = canonical.reversed().compactMap { entry -> Point? in
                guard let value = entry.result.canonical else { return nil }
                return Point(id: entry.id, date: entry.takenOn, value: value.value, comparator: entry.result.comparator,
                             low: value.referenceLow, high: value.referenceHigh)
            }
            self.init(unit: unit, points: points, converted: true, leftOut: entries.count - points.count)
            return
        }
        let sameUnit = entries.filter { Self.unitKey($0.result.unit) == latestKey }
        self.init(unit: history.latest.result.unit, points: sameUnit.reversed().map(printed), converted: false,
                  leftOut: entries.count - sameUnit.count)
    }
}

/// The wording of lab values: as printed, never judged.
nonisolated enum LabFormat {
    /// "13.1", "0.823", "1,250".
    static func number(_ value: Double, locale: Locale = .current) -> String {
        value.formatted(.number.precision(.fractionLength(0...3)).locale(locale))
    }

    /// "18 ng/mL", "< 0.5 mg/dL", "12" without a unit.
    static func value(_ value: Double, comparator: LabResult.Comparator? = nil, unit: String?, locale: Locale = .current) -> String {
        var text = number(value, locale: locale)
        if let comparator { text = "\(comparator.rawValue) \(text)" }
        guard let unit, !unit.isEmpty else { return text }
        return "\(text) \(unit)"
    }

    static func value(_ result: LabResult, locale: Locale = .current) -> String {
        value(result.value, comparator: result.comparator, unit: result.unit, locale: locale)
    }

    /// "Lab range 30–100 ng/mL", "Lab range at least 30 ng/mL", "Lab range up to 5.2 mmol/L";
    /// nil when the report printed no range.
    static func range(low: Double?, high: Double?, unit: String?, locale: Locale = .current) -> String? {
        let suffix = unit.map { $0.isEmpty ? "" : " \($0)" } ?? ""
        switch (low, high) {
        case let (low?, high?):
            return String(localized: "Lab range \(number(low, locale: locale))–\(number(high, locale: locale))\(suffix)")
        case let (low?, nil):
            return String(localized: "Lab range at least \(number(low, locale: locale))\(suffix)")
        case let (nil, high?):
            return String(localized: "Lab range up to \(number(high, locale: locale))\(suffix)")
        case (nil, nil):
            return nil
        }
    }

    static func range(_ result: LabResult, locale: Locale = .current) -> String? {
        range(low: result.referenceLow, high: result.referenceHigh, unit: result.unit, locale: locale)
    }

    /// "1 result", "4 results".
    static func resultCount(_ count: Int) -> String {
        count == 1 ? String(localized: "1 result") : String(localized: "\(count) results")
    }

    /// "Oct 20, 2026".
    static func day(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }
}
