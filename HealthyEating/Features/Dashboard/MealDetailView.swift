import SwiftUI

/// B3 Meal detail (read-only for now): provenance, confidence with its one-line reason, nutrition
/// and which assistant saved the meal. Edit (B4) and delete need backend endpoints first.
struct MealDetailView: View {
    let meal: Meal

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: Spacing.s1) {
                    Text(meal.dishName)
                        .font(.title2Bold)
                        .foregroundStyle(.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.inkMuted)
                }
                .padding(.horizontal, Spacing.s1)
                .plainListRow()

                VStack(alignment: .leading, spacing: Spacing.s3) {
                    FlowLayout(horizontalSpacing: Spacing.s3) {
                        ProvenanceBadge(kind: meal.provenance)
                        if meal.provenance == .estimated, let confidence = meal.confidence {
                            ConfidenceIndicator(level: confidence)
                        }
                    }
                    if let note = meal.sourceNote {
                        Text(verbatim: note)
                            .font(.subheadline)
                            .foregroundStyle(.ink)
                    }
                }
                .cardStyle()
                .plainListRow()
            }
            .listSectionSpacing(Spacing.s3)

            Section {
                valueRow("Calories", NutritionFormat.value(meal.caloriesKcal, .kcal))
                valueRow("Protein", NutritionFormat.value(meal.proteinG, .grams))
                valueRow("Fat", NutritionFormat.value(meal.fatG, .grams))
                valueRow("Carbohydrates", NutritionFormat.value(meal.carbohydratesG, .grams))
                if let portion = meal.portionGrams {
                    valueRow("Portion", NutritionFormat.value(portion, .grams))
                }
            } header: {
                Text("Nutrition").sectionTextStyle()
            } footer: {
                if meal.provenance == .estimated {
                    Text("± marks values \(meal.assistant) estimated. Values you edit become your numbers.")
                        .sectionTextStyle()
                }
            }
            .listRowBackground(Color.surface)

            Section {
                LabeledContent("Saved by") { Text(verbatim: meal.assistant).foregroundStyle(.inkMuted) }
            } header: {
                Text("Source").sectionTextStyle()
            }
            .listRowBackground(Color.surface)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.bg)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var subtitle: String {
        let time = meal.eatenAt.formatted(date: .omitted, time: .shortened)
        guard let portion = meal.portionGrams else {
            return String(localized: "\(time) · via \(meal.assistant)")
        }
        return String(localized: "\(time) · \(NutritionFormat.value(portion, .grams)) · via \(meal.assistant)")
    }

    private func valueRow(_ title: LocalizedStringKey, _ value: String) -> some View {
        LabeledContent {
            HStack(spacing: Spacing.s2) {
                if meal.provenance == .estimated {
                    Image(systemName: "plusminus")
                        .imageScale(.small)
                        .foregroundStyle(.inkMuted)
                        .accessibilityLabel(Text("Estimated"))
                }
                Text(verbatim: value)
                    .fontDesign(.rounded)
                    .monospacedDigit()
                    .foregroundStyle(.ink)
            }
        } label: {
            Text(title).foregroundStyle(.ink)
        }
    }
}

#Preview("Light") {
    NavigationStack { MealDetailView(meal: SampleData.meals[1]) }
}

#Preview("Dark") {
    NavigationStack { MealDetailView(meal: SampleData.meals[1]) }.preferredColorScheme(.dark)
}

#Preview("AX5") {
    NavigationStack { MealDetailView(meal: SampleData.meals[1]) }.environment(\.dynamicTypeSize, .accessibility5)
}
