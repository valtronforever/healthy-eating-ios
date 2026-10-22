import SwiftUI

/// The top of Today: calories so far as the one hero number, then each macro against its
/// target range. Nothing on the card changes color with the value.
/// See design/system/components/SummaryCard.
struct SummaryCard: View {
    let kcal: Double
    let kcalTarget: TargetRange
    let macros: [MacroProgress]
    /// Energy is stored in kcal and shown in the person's unit.
    var energyUnit: EnergyUnit = .kcal
    /// Calm mode: hides the calorie block, keeps the macros.
    var calm = false
    /// One factual line, already localized, for example "Logged 6 of the last 7 days."
    var footer: String?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s5) {
            if !calm {
                VStack(alignment: .leading, spacing: Spacing.s2) {
                    figure
                    RangeBand(label: String(localized: "Calories"), value: energyUnit.amount(fromKcal: kcal),
                              min: kcalTarget.min.map(energyUnit.amount(fromKcal:)),
                              max: kcalTarget.max.map(energyUnit.amount(fromKcal:)),
                              unit: energyUnit.nutrientUnit, compact: true)
                }
            }
            VStack(alignment: .leading, spacing: Spacing.s4) {
                ForEach(macros) { progress in
                    RangeBand(label: progress.macro.name, value: progress.value,
                              min: progress.min, max: progress.max, macro: progress.macro)
                }
            }
            if let footer {
                Text(verbatim: footer)
                    .font(.footnote)
                    .foregroundStyle(.inkMuted)
            }
        }
        .cardStyle()
    }

    private var figure: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.s1))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: Spacing.s2))
        return layout {
            Text(NutritionFormat.number(energyUnit.amount(fromKcal: kcal)))
                .metricFont(.xl)
                .foregroundStyle(.ink)
            Text(energyUnit == .kcal ? "kcal so far" : "kJ so far")
                .font(.subheadline)
                .foregroundStyle(.inkMuted)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview("Light") {
    SummaryCardGallery().previewCard()
}

#Preview("Dark") {
    SummaryCardGallery().previewCard().preferredColorScheme(.dark)
}

#Preview("AX5") {
    ScrollView { SummaryCardGallery().previewCard() }
        .environment(\.dynamicTypeSize, .accessibility5)
}

struct SummaryCardGallery: View {
    var body: some View {
        VStack(spacing: Spacing.s5) {
            SummaryCard(kcal: SampleData.kcalSoFar, kcalTarget: SampleData.kcalTarget, macros: SampleData.macros)
            SummaryCard(kcal: SampleData.kcalSoFar, kcalTarget: SampleData.kcalTarget, macros: SampleData.macros,
                        calm: true, footer: TodayView.consistencyLine(6))
        }
    }
}
