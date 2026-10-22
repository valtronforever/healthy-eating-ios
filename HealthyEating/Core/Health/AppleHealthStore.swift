import Foundation
import HealthKit

/// One body mass sample from another source in Apple Health (a scale, the Health app). Its
/// HealthKit UUID goes to the server as `external_id`, so a sample sent twice is stored once.
nonisolated struct HealthWeight: Sendable, Equatable {
    let id: UUID
    let kg: Double
    let measuredAt: Date
}

/// A weigh-in from the chat or the app, written to Apple Health. The sample carries the server
/// id as its sync identifier and `version` as its sync version, so a correction replaces the
/// sample and the import never reads it back.
nonisolated struct HealthWrite: Sendable, Equatable {
    let serverID: UUID
    let kg: Double
    let measuredAt: Date
    let version: Int
}

/// A sample the app wrote that is gone from Apple Health: deleted by the person, or replaced by
/// a newer version of the same weigh-in.
nonisolated struct DeletedHealthWrite: Sendable, Equatable {
    let serverID: UUID
    let version: Int
}

/// What changed in Apple Health since the last read.
nonisolated struct AppleHealthChanges: Sendable, Equatable {
    /// New samples from other sources.
    var added: [HealthWeight] = []
    /// Other sources' samples deleted (HealthKit UUIDs, the server's `external_id`).
    var deleted: [UUID] = []
    /// The app's own samples that are gone.
    var deletedWrites: [DeletedHealthWrite] = []
    var anchor: Data?

    var isEmpty: Bool { added.isEmpty && deleted.isEmpty && deletedWrites.isEmpty }
}

/// A nutrient the app writes to Apple Health for each meal.
nonisolated enum HealthNutrient: String, Sendable, CaseIterable, Codable {
    case energy, protein, fat, carbohydrates, fiber, sugar, sodium

    var identifier: HKQuantityTypeIdentifier {
        switch self {
        case .energy: .dietaryEnergyConsumed
        case .protein: .dietaryProtein
        case .fat: .dietaryFatTotal
        case .carbohydrates: .dietaryCarbohydrates
        case .fiber: .dietaryFiber
        case .sugar: .dietarySugar
        case .sodium: .dietarySodium
        }
    }

    /// The server's canonical unit for it.
    var unit: HKUnit {
        switch self {
        case .energy: .kilocalorie()
        case .sodium: .gramUnit(with: .milli)
        default: .gram()
        }
    }

    var type: HKQuantityType { HKQuantityType(identifier) }
}

/// A meal from the server written to Apple Health as one food correlation, with its name and the
/// values it has. Meals only go this way: the app never creates meals.
nonisolated struct HealthMeal: Sendable, Equatable {
    let serverID: UUID
    let eatenAt: Date
    let dishName: String
    let values: [HealthNutrient: Double]
    let version: Int

    init(_ meal: Meal, version: Int) {
        serverID = meal.id
        eatenAt = meal.eatenAt
        dishName = meal.dishName
        var values: [HealthNutrient: Double] = [
            .energy: meal.caloriesKcal, .protein: meal.proteinG, .fat: meal.fatG, .carbohydrates: meal.carbohydratesG,
        ]
        values[.fiber] = meal.optional[.fiber]
        values[.sugar] = meal.optional[.sugar]
        values[.sodium] = meal.optional[.sodium]
        self.values = values
        self.version = version
    }
}

/// The sync identifier of samples the app writes: `healthy-eating:<server weigh-in id>`.
nonisolated enum AppleHealthSyncID {
    static let prefix = "healthy-eating:"

    static func make(_ serverID: UUID) -> String { prefix + serverID.uuidString.lowercased() }

    static func serverID(_ syncID: String?) -> UUID? {
        guard let syncID, syncID.hasPrefix(prefix) else { return nil }
        return UUID(uuidString: String(syncID.dropFirst(prefix.count)))
    }

    /// A meal's food correlation: `healthy-eating-meal:<meal id>`.
    static func meal(_ serverID: UUID) -> String { "healthy-eating-meal:" + serverID.uuidString.lowercased() }

    /// One nutrient sample inside it: `healthy-eating-meal:<meal id>:energy`.
    static func meal(_ serverID: UUID, _ nutrient: HealthNutrient) -> String { meal(serverID) + ":" + nutrient.rawValue }
}

/// Apple Health: body weight both ways (ios#32) and meals from the server (ios#31), behind a
/// protocol so tests and screenshots never touch HealthKit.
protocol AppleHealthStore: Sendable {
    var isAvailable: Bool { get }
    /// Whether the person allowed writing body mass (reading never tells).
    var canWrite: Bool { get }
    /// The nutrients the person allowed writing.
    var writableNutrients: Set<HealthNutrient> { get }
    /// Shows the system sheet for body mass (read and write) and the nutrients (write). HealthKit
    /// never says whether read access was granted; without it queries just return nothing.
    func requestAccess() async throws
    /// Shows the sheet only for types the person was never asked about (a newer app version
    /// added them); in the foreground only.
    func requestAccessIfNeeded() async
    /// Changes after `anchor` (every sample when nil, without deletions) and the anchor to
    /// continue from.
    func changes(after anchor: Data?) async throws -> AppleHealthChanges
    /// Writes or replaces the app's samples for these weigh-ins.
    func save(_ writes: [HealthWrite]) async throws
    /// Deletes the app's samples for these weigh-ins (never other sources' samples).
    func delete(serverIDs: [UUID]) async throws
    /// Writes or replaces these meals; a value a meal no longer has is deleted.
    func saveMeals(_ meals: [HealthMeal]) async throws
    /// Deletes the app's correlations and samples for these meals.
    func deleteMeals(serverIDs: [UUID]) async throws
}

nonisolated struct SystemAppleHealthStore: AppleHealthStore {
    private let store = HKHealthStore()
    private let bodyMass = HKQuantityType(.bodyMass)
    private let kilograms = HKUnit.gramUnit(with: .kilo)

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }
    var canWrite: Bool { store.authorizationStatus(for: bodyMass) == .sharingAuthorized }
    var writableNutrients: Set<HealthNutrient> {
        Set(HealthNutrient.allCases.filter { store.authorizationStatus(for: $0.type) == .sharingAuthorized })
    }

    private var shareTypes: Set<HKSampleType> { Set([bodyMass] + HealthNutrient.allCases.map(\.type)) }

    func requestAccess() async throws {
        try await store.requestAuthorization(toShare: shareTypes, read: [bodyMass])
    }

    func requestAccessIfNeeded() async {
        guard (try? await store.statusForAuthorizationRequest(toShare: shareTypes, read: [bodyMass])) == .shouldRequest else { return }
        try? await requestAccess()
    }

    func changes(after anchor: Data?) async throws -> AppleHealthChanges {
        let start = anchor.flatMap { try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: $0) }
        let query = HKAnchoredObjectQueryDescriptor(predicates: [.quantitySample(type: bodyMass)], anchor: start)
        let result = try await query.result(for: store)
        var changes = AppleHealthChanges()
        for sample in result.addedSamples where AppleHealthSyncID.serverID(Self.syncID(sample.metadata)) == nil {
            changes.added.append(HealthWeight(id: sample.uuid, kg: sample.quantity.doubleValue(for: kilograms), measuredAt: sample.startDate))
        }
        for object in result.deletedObjects {
            if let serverID = AppleHealthSyncID.serverID(Self.syncID(object.metadata)) {
                let version = (object.metadata?[HKMetadataKeySyncVersion] as? NSNumber)?.intValue ?? 0
                changes.deletedWrites.append(DeletedHealthWrite(serverID: serverID, version: version))
            } else {
                changes.deleted.append(object.uuid)
            }
        }
        changes.anchor = try? NSKeyedArchiver.archivedData(withRootObject: result.newAnchor, requiringSecureCoding: true)
        return changes
    }

    func save(_ writes: [HealthWrite]) async throws {
        let samples = writes.map { write in
            HKQuantitySample(
                type: bodyMass, quantity: HKQuantity(unit: kilograms, doubleValue: write.kg),
                start: write.measuredAt, end: write.measuredAt,
                metadata: [HKMetadataKeySyncIdentifier: AppleHealthSyncID.make(write.serverID),
                           HKMetadataKeySyncVersion: write.version])
        }
        try await store.save(samples)
    }

    func delete(serverIDs: [UUID]) async throws {
        let predicate = HKQuery.predicateForObjects(
            withMetadataKey: HKMetadataKeySyncIdentifier, allowedValues: serverIDs.map(AppleHealthSyncID.make))
        _ = try await store.deleteObjects(of: bodyMass, predicate: predicate)
    }

    func saveMeals(_ meals: [HealthMeal]) async throws {
        let writable = writableNutrients
        var correlations: [HKCorrelation] = []
        var missing: [HealthNutrient: [String]] = [:]
        for meal in meals {
            var samples: Set<HKSample> = []
            for nutrient in HealthNutrient.allCases {
                guard let value = meal.values[nutrient], writable.contains(nutrient) else {
                    missing[nutrient, default: []].append(AppleHealthSyncID.meal(meal.serverID, nutrient))
                    continue
                }
                samples.insert(HKQuantitySample(
                    type: nutrient.type, quantity: HKQuantity(unit: nutrient.unit, doubleValue: value),
                    start: meal.eatenAt, end: meal.eatenAt,
                    metadata: [HKMetadataKeySyncIdentifier: AppleHealthSyncID.meal(meal.serverID, nutrient),
                               HKMetadataKeySyncVersion: meal.version, HKMetadataKeyFoodType: meal.dishName]))
            }
            guard !samples.isEmpty else { continue }
            correlations.append(HKCorrelation(
                type: HKCorrelationType(.food), start: meal.eatenAt, end: meal.eatenAt, objects: samples,
                metadata: [HKMetadataKeySyncIdentifier: AppleHealthSyncID.meal(meal.serverID),
                           HKMetadataKeySyncVersion: meal.version, HKMetadataKeyFoodType: meal.dishName]))
        }
        // A value a corrected meal no longer has (sodium removed) must not stay behind.
        for (nutrient, ids) in missing where writable.contains(nutrient) {
            let predicate = HKQuery.predicateForObjects(withMetadataKey: HKMetadataKeySyncIdentifier, allowedValues: ids)
            _ = try? await store.deleteObjects(of: nutrient.type, predicate: predicate)
        }
        if !correlations.isEmpty { try await store.save(correlations) }
    }

    func deleteMeals(serverIDs: [UUID]) async throws {
        let writable = writableNutrients
        let correlationIDs = serverIDs.map(AppleHealthSyncID.meal)
        _ = try? await store.deleteObjects(
            of: HKCorrelationType(.food),
            predicate: HKQuery.predicateForObjects(withMetadataKey: HKMetadataKeySyncIdentifier, allowedValues: correlationIDs))
        for nutrient in HealthNutrient.allCases where writable.contains(nutrient) {
            let ids = serverIDs.map { AppleHealthSyncID.meal($0, nutrient) }
            let predicate = HKQuery.predicateForObjects(withMetadataKey: HKMetadataKeySyncIdentifier, allowedValues: ids)
            _ = try await store.deleteObjects(of: nutrient.type, predicate: predicate)
        }
    }

    private static func syncID(_ metadata: [String: Any]?) -> String? {
        metadata?[HKMetadataKeySyncIdentifier] as? String
    }
}

/// UI tests and screenshots: three weigh-ins from this week, once; writes go nowhere.
nonisolated struct PlaceholderAppleHealthStore: AppleHealthStore {
    var isAvailable: Bool { true }
    var canWrite: Bool { true }
    var writableNutrients: Set<HealthNutrient> { Set(HealthNutrient.allCases) }

    func requestAccess() async throws {}
    func requestAccessIfNeeded() async {}

    func changes(after anchor: Data?) async throws -> AppleHealthChanges {
        guard anchor == nil else { return AppleHealthChanges(anchor: anchor) }
        let added = [(2, 78.6), (1, 78.5), (0, 78.4)].map { daysAgo, kg in
            HealthWeight(id: UUID(), kg: kg, measuredAt: Date.now.addingTimeInterval(Double(-daysAgo) * 86_400 - 3600))
        }
        return AppleHealthChanges(added: added, anchor: Data("placeholder".utf8))
    }

    func save(_ writes: [HealthWrite]) async throws {}
    func delete(serverIDs: [UUID]) async throws {}
    func saveMeals(_ meals: [HealthMeal]) async throws {}
    func deleteMeals(serverIDs: [UUID]) async throws {}
}
