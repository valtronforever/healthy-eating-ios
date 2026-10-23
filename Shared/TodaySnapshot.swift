import Foundation
import Security

/// What the widgets show (ios#35): today's totals against the person's ranges, written by the app
/// whenever Today loads and in background refresh. The widgets only read it: they never reach the
/// server and never see a token. Shared by the app and the widget extension.
nonisolated struct TodaySnapshot: Codable, Equatable, Sendable {
    /// A target range; either bound may be open.
    struct Range: Codable, Equatable, Sendable {
        var min: Double?
        var max: Double?
    }

    /// The local day the totals are for (midnight in the device calendar).
    var day: Date
    /// When the app wrote it.
    var savedAt: Date
    var caloriesKcal: Double
    var proteinG: Double
    var fatG: Double
    var carbohydratesG: Double
    var calories: Range?
    var protein: Range?
    var fat: Range?
    var carbohydrates: Range?
    var energyUnit: EnergyUnit
    /// Calm mode hides calories in the widgets too.
    var calmMode: Bool
    var mealCount: Int
    /// When the latest meal reached the server, and through which assistant.
    var lastMealSavedAt: Date?
    var lastAssistant: String?

    static let widgetKind = "TodayWidget"

    /// Whether it is about today; after midnight the widgets ask to open the app instead.
    func isCurrent(now: Date = .now, calendar: Calendar = .current) -> Bool {
        calendar.isDate(day, inSameDayAs: now)
    }

    // MARK: Storage

    static func load(from storage: any SnapshotStorage = KeychainSnapshotStorage()) -> TodaySnapshot? {
        storage.read().flatMap { try? JSONDecoder().decode(TodaySnapshot.self, from: $0) }
    }

    func save(to storage: any SnapshotStorage = KeychainSnapshotStorage()) {
        storage.write(try? JSONEncoder().encode(self))
    }

    /// Signing out removes it, so the widgets show nothing of the account.
    static func remove(from storage: any SnapshotStorage = KeychainSnapshotStorage()) {
        storage.write(nil)
    }

    // MARK: Wording

    /// "1,200" in the person's unit, with locale grouping.
    func energy(locale: Locale = .current) -> String {
        Self.number(energyUnit.amount(fromKcal: caloriesKcal), locale: locale)
    }

    /// "kcal · 1,900–2,200" under the hero number, or just "kcal" without a range.
    func energyCaption(locale: Locale = .current) -> String {
        guard let range = calories.flatMap({ Self.range($0, convert: energyUnit.amount(fromKcal:), locale: locale) }) else {
            return energyUnit.symbol
        }
        return "\(energyUnit.symbol) · \(range)"
    }

    /// "Target 110–140 g"-style range text for a macro, or nil without one.
    static func range(_ range: Range, convert: (Double) -> Double = { $0 }, locale: Locale = .current) -> String? {
        switch (range.min, range.max) {
        case let (min?, max?): "\(number(convert(min), locale: locale))–\(number(convert(max), locale: locale))"
        case let (min?, nil): String(localized: "from \(number(convert(min), locale: locale))")
        case let (nil, max?): String(localized: "up to \(number(convert(max), locale: locale))")
        case (nil, nil): nil
        }
    }

    static func number(_ value: Double, locale: Locale = .current) -> String {
        value.formatted(.number.precision(.fractionLength(0)).locale(locale))
    }

    static func grams(_ value: Double, locale: Locale = .current) -> String {
        "\(number(value, locale: locale)) g"
    }

    /// The first line of the rectangular Lock Screen widget: "1,200 kcal · P 77 g", or the macros
    /// only in Calm mode.
    func lockScreenHeadline(locale: Locale = .current) -> String {
        let protein = "P \(Self.grams(proteinG, locale: locale))"
        return calmMode ? "\(protein) · F \(Self.grams(fatG, locale: locale))" : "\(energy(locale: locale)) \(energyUnit.symbol) · \(protein)"
    }

    /// The second line: "F 32 g · C 144 g", or carbohydrates only in Calm mode.
    func lockScreenDetail(locale: Locale = .current) -> String {
        let carbs = "C \(Self.grams(carbohydratesG, locale: locale))"
        return calmMode ? carbs : "F \(Self.grams(fatG, locale: locale)) · \(carbs)"
    }

    /// "Saved 20 min ago via Claude" at minute precision ("just now", "2 h ago"), or "No meals yet
    /// today"; nil when the server sent no save time.
    func savedLine(now: Date = .now) -> String? {
        if mealCount == 0 { return String(localized: "No meals yet today") }
        guard let saved = lastMealSavedAt else { return nil }
        let minutes = Int(max(now.timeIntervalSince(saved), 0) / 60)
        let age = switch minutes {
        case ..<1: String(localized: "just now")
        case ..<60: String(localized: "\(minutes) min ago")
        case ..<(24 * 60): String(localized: "\(minutes / 60) h ago")
        default: String(localized: "\(minutes / (24 * 60)) d ago")
        }
        guard let lastAssistant else { return String(localized: "Saved \(age)") }
        return String(localized: "Saved \(age) via \(lastAssistant)")
    }

    /// The end of a bar's track: past the range's upper bound (like the app's range band), or
    /// the value when it is further. Being over and under look the same.
    static func scale(_ value: Double, _ range: Range?) -> Double {
        let bound = range?.max ?? range?.min ?? value
        return Swift.max(value, bound * 1.3, 1)
    }
}

/// Where the snapshot lives, so tests can use memory.
nonisolated protocol SnapshotStorage: Sendable {
    func read() -> Data?
    /// nil deletes it.
    func write(_ data: Data?)
}

/// A Keychain item in the access group the app and the widget share
/// (`<team>.io.github.valtronforever.HealthyEating.shared`). A free Apple developer team can't
/// use App Groups, but every team can share Keychain groups under its own prefix. Readable after
/// the first unlock, so Lock Screen widgets work while the phone is locked. The app's tokens stay
/// in its own group, which the widget can't read.
nonisolated struct KeychainSnapshotStorage: SnapshotStorage {
    static let service = "io.github.valtronforever.HealthyEating.widget"
    /// "today" for the snapshot, "access" for the widget token (`WidgetAccess`).
    var account = "today"

    /// The full group name from the app's Info.plist; the widget reads without one (its only group).
    var accessGroup: String? = Bundle.main.object(forInfoDictionaryKey: "SharedKeychainGroup") as? String

    private var base: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: Self.service, kSecAttrAccount as String: account]
    }

    func read() -> Data? {
        var query = base
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    func write(_ data: Data?) {
        SecItemDelete(base as CFDictionary)
        guard let data else { return }
        var item = base
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        if let accessGroup, !accessGroup.hasPrefix("."), !accessGroup.hasPrefix("$") {
            item[kSecAttrAccessGroup as String] = accessGroup
        }
        SecItemAdd(item as CFDictionary, nil)
    }
}

/// Tests and previews.
nonisolated final class MemorySnapshotStorage: SnapshotStorage, @unchecked Sendable {
    private var data: Data?
    init() {}
    func read() -> Data? { data }
    func write(_ data: Data?) { self.data = data }
}
