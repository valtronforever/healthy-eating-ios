import Foundation

/// Sync with Apple Health: body weight both ways (ios#32) and meals from the server (ios#31).
/// Runs when the app becomes active and in background refresh; the server cannot reach Apple
/// Health itself.
///
/// Meals: those of the last year are written as one food correlation each (energy, protein, fat,
/// carbohydrates, and fiber, sugar and sodium when the meal has them), replaced when corrected
/// and deleted when deleted on the server. Never read back: the app never creates meals.
///
/// Weight, only while weight tracking is on:
///
/// 1. Apple Health to the server: new samples from other sources (scales, the Health app) are
///    sent as `apple_health` weigh-ins, their deletions are sent too, and deleting one of the
///    app's own samples deletes that weigh-in. Read with an anchored query; the anchor moves on
///    only when everything reached the server, and an empty first read keeps no anchor (Apple
///    Health returns nothing while read access is off).
/// 2. The server to Apple Health: weigh-ins from the chat or the app of the last year are written
///    as the app's own samples, replaced when corrected and deleted when deleted on the server.
///
/// `written` remembers which version of each weigh-in is in Apple Health. A replaced sample is
/// reported as deleted with its old version, which never deletes the weigh-in.
@MainActor
final class AppleHealthSync {
    struct Written: Codable, Equatable {
        var version: Int
        var measuredAt: Date
    }

    private enum Keys {
        static let anchor = "appleHealthSyncAnchor"
        static let written = "appleHealthWritten"
        static let writtenMeals = "appleHealthWrittenMeals"
    }

    static let keys = [Keys.anchor, Keys.written, Keys.writtenMeals]
    /// How far back server weigh-ins are written to Apple Health (the API's longest range).
    static let writeDays = 365

    private let health: any AppleHealthStore
    private let defaults: UserDefaults

    init(health: any AppleHealthStore, defaults: UserDefaults) {
        self.health = health
        self.defaults = defaults
    }

    /// Which version of each weigh-in is in Apple Health.
    private(set) var written: [UUID: Written] {
        get { stored(Keys.written) }
        set { store(newValue, Keys.written) }
    }

    /// Which version of each meal is in Apple Health.
    private(set) var writtenMeals: [UUID: Written] {
        get { stored(Keys.writtenMeals) }
        set { store(newValue, Keys.writtenMeals) }
    }

    private func stored(_ key: String) -> [UUID: Written] {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode([UUID: Written].self, from: $0) } ?? [:]
    }

    private func store(_ value: [UUID: Written], _ key: String) {
        defaults.set(try? JSONEncoder().encode(value), forKey: key)
    }

    /// The sync version of a weigh-in: when the server last changed it, in milliseconds. Without
    /// a change time (sample data) it is 0, so any real change is newer.
    nonisolated static func version(_ weighIn: WeighIn) -> Int { milliseconds(weighIn.updatedAt) }

    /// The sync version of a meal, the same way.
    nonisolated static func version(_ meal: Meal) -> Int { milliseconds(meal.updatedAt) }

    nonisolated private static func milliseconds(_ date: Date?) -> Int {
        date.map { Int(($0.timeIntervalSince1970 * 1000).rounded()) } ?? 0
    }

    /// One sync. Returns how many changes it made (meals written or deleted, weigh-ins imported,
    /// deleted or written), or nil when Apple Health could not be read.
    func run(_ data: any NutritionDataSource, calendar: Calendar = .current, now: Date = .now) async throws(APIError) -> Int? {
        var changes = try await pushMeals(data, calendar: calendar, now: now)
        guard try await data.settings().weightTracking else { return changes }
        guard let fromHealth = try await pull(data) else { return nil }
        changes += fromHealth
        changes += try await push(data, calendar: calendar, now: now)
        return changes
    }

    func forget() {
        for key in Self.keys { defaults.removeObject(forKey: key) }
    }

    // MARK: Meals to Apple Health

    /// Meals written per call, so a first sync of a year of meals goes in steps.
    static let mealBatch = 100

    private func pushMeals(_ data: any NutritionDataSource, calendar: Calendar, now: Date) async throws(APIError) -> Int {
        guard health.writableNutrients.contains(.energy) else { return 0 }
        let today = calendar.startOfDay(for: now)
        let first = calendar.date(byAdding: .day, value: -Self.writeDays, to: today) ?? today
        let meals = try await data.allMeals(from: first, to: today)
        var written = writtenMeals
        let writes = meals.compactMap { meal -> HealthMeal? in
            let version = Self.version(meal)
            return written[meal.id]?.version == version ? nil : HealthMeal(meal, version: version)
        }
        let current = Set(meals.map(\.id))
        let gone = written.filter { !current.contains($0.key) && $0.value.measuredAt >= first }.map(\.key)
        var count = 0
        do {
            for batch in writes.chunks(of: Self.mealBatch) {
                try await health.saveMeals(batch)
                for meal in batch { written[meal.serverID] = Written(version: meal.version, measuredAt: meal.eatenAt) }
                count += batch.count
            }
            if !gone.isEmpty {
                try await health.deleteMeals(serverIDs: gone)
                for id in gone { written[id] = nil }
                count += gone.count
            }
        } catch {
            // Keep what was written; the rest is tried again next time.
        }
        writtenMeals = written
        return count
    }

    // MARK: Apple Health to the server

    private func pull(_ data: any NutritionDataSource) async throws(APIError) -> Int? {
        let anchor = defaults.data(forKey: Keys.anchor)
        let changes: AppleHealthChanges
        do {
            changes = try await health.changes(after: anchor)
        } catch {
            return nil
        }
        guard anchor != nil || !changes.isEmpty else { return 0 }
        var count = 0
        for batch in changes.added.chunks(of: APIClient.maxWeightBatch) {
            count += try await data.importWeights(batch)
        }
        for batch in changes.deleted.chunks(of: APIClient.maxWeightBatch) {
            count += try await data.deleteAppleHealthWeights(batch)
        }
        var written = written
        for gone in changes.deletedWrites where written[gone.serverID]?.version == gone.version {
            do throws(APIError) {
                try await data.deleteWeight(gone.serverID)
                count += 1
            } catch .notFound {
            }
            written[gone.serverID] = nil
        }
        self.written = written
        defaults.set(changes.anchor, forKey: Keys.anchor)
        return count
    }

    // MARK: The server to Apple Health

    private func push(_ data: any NutritionDataSource, calendar: Calendar, now: Date) async throws(APIError) -> Int {
        guard health.canWrite else { return 0 }
        let today = calendar.startOfDay(for: now)
        let first = calendar.date(byAdding: .day, value: -Self.writeDays, to: today) ?? today
        let entries = try await data.weights(from: first, to: today).entries.filter { $0.source != .appleHealth }
        var written = written
        let writes = entries.compactMap { entry -> HealthWrite? in
            let version = Self.version(entry)
            guard written[entry.id]?.version != version else { return nil }
            return HealthWrite(serverID: entry.id, kg: entry.weightKg, measuredAt: entry.measuredAt, version: version)
        }
        let current = Set(entries.map(\.id))
        let gone = written.filter { !current.contains($0.key) && $0.value.measuredAt >= first }.map(\.key)
        do {
            if !writes.isEmpty { try await health.save(writes) }
            if !gone.isEmpty { try await health.delete(serverIDs: gone) }
        } catch {
            return 0
        }
        for write in writes { written[write.serverID] = Written(version: write.version, measuredAt: write.measuredAt) }
        for id in gone { written[id] = nil }
        self.written = written
        return writes.count + gone.count
    }
}

extension Array {
    /// Consecutive slices of at most `size` elements.
    nonisolated func chunks(of size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map { Array(self[$0..<Swift.min($0 + size, count)]) }
    }
}
