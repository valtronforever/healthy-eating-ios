import Foundation

/// The unit the person wants energy shown in (a server setting). Values always arrive in kcal;
/// kJ is a display conversion only. Shared with the widget extension.
nonisolated enum EnergyUnit: String, Sendable, CaseIterable, Codable {
    case kcal
    case kj

    /// The value in this unit, converted with `Measurement` (1 kcal = 4.184 kJ).
    func amount(fromKcal kcal: Double) -> Double {
        switch self {
        case .kcal: kcal
        case .kj: Measurement(value: kcal, unit: UnitEnergy.kilocalories).converted(to: .kilojoules).value
        }
    }

    /// "kcal" or "kJ".
    var symbol: String {
        switch self {
        case .kcal: String(localized: "kcal", comment: "Unit symbol for kilocalories")
        case .kj: String(localized: "kJ", comment: "Unit symbol for kilojoules")
        }
    }
}
