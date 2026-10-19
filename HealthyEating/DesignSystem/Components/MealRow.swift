import SwiftUI

/// One logged meal in a list: time, dish name, kcal, macros, provenance, confidence and the
/// assistant that saved it. Put it in a `NavigationLink` inside an inset grouped list; the whole
/// row is the tap target. At accessibility sizes everything stacks. See design/system/components/MealRow.
struct MealRow: View {
    let meal: Meal
    /// Calm mode: hides calories.
    var hideKcal = false

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .subheadline) private var timeWidth: CGFloat = 46

    var body: some View {
        let stacked = dynamicTypeSize.isAccessibilitySize
        let outer = stacked
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.s1))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: Spacing.s3))
        outer {
            Text(meal.eatenAt, format: .dateTime.hour().minute())
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(.inkMuted)
                .frame(minWidth: stacked ? nil : timeWidth, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                top(stacked: stacked)
                Text(NutritionFormat.macroLine(protein: meal.proteinG, fat: meal.fatG, carbs: meal.carbohydratesG))
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.inkMuted)
                FlowLayout {
                    ProvenanceBadge(kind: meal.provenance)
                    if meal.provenance == .estimated, let confidence = meal.confidence {
                        ConfidenceIndicator(level: confidence, short: true)
                    }
                    Text("via \(meal.assistant)")
                        .font(.footnote)
                        .foregroundStyle(.inkMuted)
                }
                .padding(.top, 3)
            }
        }
        .padding(.vertical, Spacing.s1)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func top(stacked: Bool) -> some View {
        let layout = stacked
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: Spacing.s2))
        layout {
            Text(meal.dishName)
                .font(.headline)
                .foregroundStyle(.ink)
                .frame(maxWidth: stacked ? nil : .infinity, alignment: .leading)
            if !hideKcal {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(NutritionFormat.number(meal.caloriesKcal))
                        .metricFont(.small)
                        .foregroundStyle(.ink)
                    Text(NutrientUnit.kcal.symbol)
                        .font(.subheadline)
                        .foregroundStyle(.inkMuted)
                }
                .fixedSize()
            }
        }
    }
}

#Preview("Light") {
    MealRowGallery()
}

#Preview("Dark") {
    MealRowGallery().preferredColorScheme(.dark)
}

#Preview("AX5") {
    MealRowGallery().environment(\.dynamicTypeSize, .accessibility5)
}

private struct MealRowGallery: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Meals") {
                    ForEach(SampleData.meals) { meal in
                        NavigationLink(value: meal) { MealRow(meal: meal) }
                    }
                }
                .listRowBackground(Color.surface)
                Section("Calm mode") {
                    MealRow(meal: SampleData.meals[1], hideKcal: true)
                }
                .listRowBackground(Color.surface)
            }
            .scrollContentBackground(.hidden)
            .background(Color.bg)
        }
    }
}
