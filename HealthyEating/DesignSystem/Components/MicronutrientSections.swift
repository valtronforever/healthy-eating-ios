import SwiftUI

/// One vitamin or mineral value and how much of the day or period it covers.
nonisolated struct MicronutrientValue: Hashable, Sendable {
    var amount: Double
    /// "2 of 3 meals", "on 4 of 7 counted days"; nil when it covers everything.
    var note: String? = nil
    /// The range that applies: the person's goal, else their life stage's reference.
    var range: MicronutrientRange? = nil
}

/// Vitamins, then minerals, as list sections, showing only the nutrients that have a value.
/// Plain amounts, never colors or judgments (neutral feedback rule).
struct MicronutrientSections: View {
    let values: [Micronutrient: MicronutrientValue]

    var body: some View {
        section("Vitamins", Micronutrient.vitamins)
        section("Minerals", Micronutrient.minerals)
    }

    @ViewBuilder
    private func section(_ title: LocalizedStringKey, _ nutrients: [Micronutrient]) -> some View {
        let present = nutrients.filter { values[$0] != nil }
        if !present.isEmpty {
            Section {
                ForEach(present) { nutrient in
                    if let value = values[nutrient] {
                        MicronutrientRow(nutrient: nutrient, value: value)
                    }
                }
            } header: {
                Text(title).sectionTextStyle()
            }
            .listRowBackground(Color.surface)
        }
    }
}

struct MicronutrientRow: View {
    let nutrient: Micronutrient
    let value: MicronutrientValue

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            amountLine
            if let range = value.range, range.min != nil || range.max != nil {
                // The same neutral band as targets: no colors or words for over or under.
                RangeBand(
                    label: nutrient.name, value: value.amount, min: range.min, max: range.max,
                    unit: nutrient.unit, compact: true,
                    caption: NutritionFormat.range(range, nutrient.unit),
                    spokenValue: NutritionFormat.spokenRange(value: value.amount, range, nutrient.unit))
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var amountLine: some View {
        LabeledContent {
            VStack(alignment: .trailing, spacing: 2) {
                Text(verbatim: NutritionFormat.micronutrient(value.amount, nutrient.unit))
                    .metricFont(.small)
                    .foregroundStyle(.ink)
                if let note = value.note {
                    Text(verbatim: note)
                        .font(.footnote)
                        .foregroundStyle(.inkMuted)
                }
            }
        } label: {
            Text(verbatim: nutrient.name).foregroundStyle(.ink)
        }
    }
}

#Preview("Light") {
    List { MicronutrientSections(values: MicronutrientGallery.values) }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.bg)
}

#Preview("Dark") {
    List { MicronutrientSections(values: MicronutrientGallery.values) }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.bg)
        .preferredColorScheme(.dark)
}

#Preview("AX5") {
    List { MicronutrientSections(values: MicronutrientGallery.values) }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.bg)
        .environment(\.dynamicTypeSize, .accessibility5)
}

enum MicronutrientGallery {
    static let values: [Micronutrient: MicronutrientValue] = [
        .vitaminC: .init(amount: 62, note: nil),
        .thiamin: .init(amount: 0.84, note: "2 of 3 meals", range: MicronutrientRange(min: 1.1, max: nil, source: .reference)),
        .vitaminB12: .init(amount: 2.4, note: nil),
        .iron: .init(amount: 11.6, note: nil, range: MicronutrientRange(min: 18, max: 45, source: .reference)),
        .calcium: .init(amount: 640, note: "2 of 3 meals"),
        .selenium: .init(amount: 48, note: nil, range: MicronutrientRange(min: 55, max: 200, source: .personal)),
    ]
}
