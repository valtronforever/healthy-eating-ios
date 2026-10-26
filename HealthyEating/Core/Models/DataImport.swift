import Foundation

/// What importing a Healthy Eating export adds to the account (`POST /api/v1/import`, backend
/// #27): first as a preview, then as the result. Entries the account already has are skipped.
nonisolated struct ImportSummary: Equatable, Sendable {
    nonisolated enum Format: String, Sendable {
        case json, csv
    }

    /// An entry of the file that is not valid and is left out.
    nonisolated struct Rejected: Equatable, Sendable {
        nonisolated enum Kind: String, Sendable {
            case meal, weight
        }

        let kind: Kind
        /// Position among the file's meals or weigh-ins, from 1 (the server counts from 0).
        let position: Int
        let reason: String
    }

    let isPreview: Bool
    let format: Format
    let exportedAt: Date?
    let newMeals: Int
    let knownMeals: Int
    let newWeights: Int
    let knownWeights: Int
    let daysMarked: Int
    /// Local days of the earliest and latest new meal.
    let firstDay: Date?
    let lastDay: Date?
    let rejectedCount: Int
    /// The first entries left out (the server names at most 50).
    let rejected: [Rejected]

    var addsNothing: Bool { newMeals == 0 && newWeights == 0 }
}
