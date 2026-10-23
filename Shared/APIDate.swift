import Foundation

/// Times and local days as the backend writes them. Shared with the widget extension.
nonisolated enum APIDate {
    /// ISO 8601 with a UTC offset, with or without fractional seconds (Python writes up to six
    /// digits; Foundation reads three).
    static func parse(_ text: String) -> Date? {
        var value = text
        if let dot = value.firstIndex(of: "."),
           let end = value[dot...].firstIndex(where: { $0 == "+" || $0 == "-" || $0 == "Z" }) {
            let digits = value[value.index(after: dot)..<end]
            value.replaceSubrange(dot..<end, with: "." + String(digits.prefix(3)).padding(toLength: 3, withPad: "0", startingAt: 0))
            return try? Date(value, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true))
        }
        return try? Date(value, strategy: .iso8601)
    }

    /// A local day ("2026-10-18") as midnight in the device calendar.
    static func day(_ text: String, calendar: Calendar) -> Date? {
        let parts = text.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    /// A date's local day for the API ("2026-10-18").
    static func dayString(_ date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    /// A time with the device's offset, for `eaten_at` in meal edits.
    static func timeString(_ date: Date, timeZone: TimeZone = .current) -> String {
        date.formatted(Date.ISO8601FormatStyle(timeZone: timeZone))
    }
}
