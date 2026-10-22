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

/// The sync identifier of samples the app writes: `healthy-eating:<server weigh-in id>`.
nonisolated enum AppleHealthSyncID {
    static let prefix = "healthy-eating:"

    static func make(_ serverID: UUID) -> String { prefix + serverID.uuidString.lowercased() }

    static func serverID(_ syncID: String?) -> UUID? {
        guard let syncID, syncID.hasPrefix(prefix) else { return nil }
        return UUID(uuidString: String(syncID.dropFirst(prefix.count)))
    }
}

/// Body weight in Apple Health, both ways (ios#32), behind a protocol so tests and screenshots
/// never touch HealthKit.
protocol AppleHealthWeights: Sendable {
    var isAvailable: Bool { get }
    /// Whether the person allowed writing body mass (reading never tells).
    var canWrite: Bool { get }
    /// Shows the system sheet for reading and writing body mass. HealthKit never says whether
    /// read access was granted; without it queries just return nothing.
    func requestAccess() async throws
    /// Changes after `anchor` (every sample when nil, without deletions) and the anchor to
    /// continue from.
    func changes(after anchor: Data?) async throws -> AppleHealthChanges
    /// Writes or replaces the app's samples for these weigh-ins.
    func save(_ writes: [HealthWrite]) async throws
    /// Deletes the app's samples for these weigh-ins (never other sources' samples).
    func delete(serverIDs: [UUID]) async throws
}

nonisolated struct SystemAppleHealthWeights: AppleHealthWeights {
    private let store = HKHealthStore()
    private let bodyMass = HKQuantityType(.bodyMass)
    private let kilograms = HKUnit.gramUnit(with: .kilo)

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }
    var canWrite: Bool { store.authorizationStatus(for: bodyMass) == .sharingAuthorized }

    func requestAccess() async throws {
        try await store.requestAuthorization(toShare: [bodyMass], read: [bodyMass])
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

    private static func syncID(_ metadata: [String: Any]?) -> String? {
        metadata?[HKMetadataKeySyncIdentifier] as? String
    }
}

/// UI tests and screenshots: three weigh-ins from this week, once; writes go nowhere.
nonisolated struct PlaceholderAppleHealthWeights: AppleHealthWeights {
    var isAvailable: Bool { true }
    var canWrite: Bool { true }

    func requestAccess() async throws {}

    func changes(after anchor: Data?) async throws -> AppleHealthChanges {
        guard anchor == nil else { return AppleHealthChanges(anchor: anchor) }
        let added = [(2, 78.6), (1, 78.5), (0, 78.4)].map { daysAgo, kg in
            HealthWeight(id: UUID(), kg: kg, measuredAt: Date.now.addingTimeInterval(Double(-daysAgo) * 86_400 - 3600))
        }
        return AppleHealthChanges(added: added, anchor: Data("placeholder".utf8))
    }

    func save(_ writes: [HealthWrite]) async throws {}
    func delete(serverIDs: [UUID]) async throws {}
}
