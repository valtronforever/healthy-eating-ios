import SwiftUI

/// B3 Meal detail: provenance per value, confidence with its one-line reason, nutrition, which
/// assistant saved the meal, Edit (B4) and Delete with a confirmation.
struct MealDetailView: View {
    @State var meal: Meal
    /// Called after the meal was changed or deleted, so the list reloads.
    var onChange: () -> Void = {}

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var editing = false
    @State private var confirmingDelete = false
    @State private var isDeleting = false
    @State private var error: APIError?
    @State private var warnings: [String] = []

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

                if let error {
                    Banner(kind: .error, message: error.message, detail: error.detail).plainListRow()
                }
                ForEach(warnings, id: \.self) { warning in
                    Banner(kind: .info, message: warning).plainListRow()
                }

                VStack(alignment: .leading, spacing: Spacing.s3) {
                    FlowLayout(horizontalSpacing: Spacing.s3) {
                        ProvenanceBadge(kind: meal.provenance)
                        if meal.provenance == .estimated, let confidence = meal.confidence {
                            ConfidenceIndicator(level: confidence)
                        }
                    }
                    if let note = Self.shownNote(meal) {
                        Text(verbatim: note)
                            .font(.subheadline)
                            .foregroundStyle(.ink)
                    }
                    if let imported = Self.importedLine(meal) {
                        Text(verbatim: imported)
                            .font(.subheadline)
                            .foregroundStyle(.inkMuted)
                            .accessibilityIdentifier("importedFrom")
                    }
                }
                .cardStyle()
                .plainListRow()
            }
            .listSectionSpacing(Spacing.s3)

            Section {
                if !app.calmMode {
                    valueRow("Calories", NutritionFormat.value(meal.caloriesKcal, .kcal), field: .calories)
                }
                valueRow("Protein", NutritionFormat.value(meal.proteinG, .grams), field: .protein)
                valueRow("Fat", NutritionFormat.value(meal.fatG, .grams), field: .fat)
                valueRow("Carbohydrates", NutritionFormat.value(meal.carbohydratesG, .grams), field: .carbohydrates)
                ForEach(OptionalNutrient.allCases.filter { meal.optional[$0] != nil }) { nutrient in
                    optionalRow(nutrient)
                }
                if let portion = meal.portionGrams {
                    valueRow("Portion", NutritionFormat.value(portion, .grams), field: nil)
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

            Section {
                Button("Delete meal") { confirmingDelete = true }
                    .buttonStyle(.action(.destructive))
                    .disabled(isDeleting)
                    .plainListRow()
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.bg)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { editing = true }
            }
        }
        .sheet(isPresented: $editing) {
            MealEditView(meal: meal) { updated, warnings in
                meal = updated
                self.warnings = warnings
                error = nil
                onChange()
            }
        }
        .confirmationDialog("Delete this meal?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete meal", role: .destructive) { Task { await delete() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("It is removed from your history and averages. This can’t be undone.")
        }
    }

    private var subtitle: String {
        let time = meal.eatenAt.formatted(date: .omitted, time: .shortened)
        let calendar = Calendar.current
        let when: String
        if calendar.isDateInToday(meal.eatenAt) {
            when = String(localized: "Today, \(time)")
        } else if calendar.isDateInYesterday(meal.eatenAt) {
            when = String(localized: "Yesterday, \(time)")
        } else {
            when = meal.eatenAt.formatted(.dateTime.month(.abbreviated).day().hour().minute())
        }
        guard let portion = meal.portionGrams else {
            return String(localized: "\(when) · via \(meal.assistant)")
        }
        return String(localized: "\(when) · \(NutritionFormat.value(portion, .grams)) · via \(meal.assistant)")
    }

    private func valueRow(_ title: LocalizedStringKey, _ value: String, field: NutrientField?) -> some View {
        LabeledContent {
            HStack(spacing: Spacing.s2) {
                if let field, meal.estimatedFields.contains(field) {
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

    private func optionalRow(_ nutrient: OptionalNutrient) -> some View {
        LabeledContent {
            HStack(spacing: Spacing.s2) {
                if meal.estimatedOptional.contains(nutrient) {
                    Image(systemName: "plusminus")
                        .imageScale(.small)
                        .foregroundStyle(.inkMuted)
                        .accessibilityLabel(Text("Estimated"))
                }
                Text(verbatim: NutritionFormat.value(meal.optional[nutrient] ?? 0, nutrient.unit))
                    .fontDesign(.rounded)
                    .monospacedDigit()
                    .foregroundStyle(.ink)
            }
        } label: {
            Text(verbatim: nutrient.name).foregroundStyle(.ink)
        }
    }

    private func delete() async {
        guard let data = app.data else { return }
        isDeleting = true
        defer { isDeleting = false }
        do throws(APIError) {
            try await data.deleteMeal(meal.id)
            onChange()
            dismiss()
        } catch .notFound {
            onChange()
            dismiss()
        } catch {
            self.error = error
            app.handle(error)
        }
    }

    /// "Imported from ChatGPT project" for meals from earlier tracking (backend #27).
    nonisolated static func importedLine(_ meal: Meal) -> String? {
        guard let source = meal.importedFrom, !source.isEmpty else { return nil }
        return String(localized: "Imported from \(source)")
    }

    /// The source note, unless it only repeats where an imported meal came from.
    nonisolated static func shownNote(_ meal: Meal) -> String? {
        guard let note = meal.sourceNote, !note.isEmpty, note != meal.importedFrom else { return nil }
        return note
    }
}

#Preview("Light") {
    NavigationStack { MealDetailView(meal: SampleData.meals[1]) }
        .environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.skipOnboarding]))
}

#Preview("Dark") {
    NavigationStack { MealDetailView(meal: SampleData.meals[1]) }
        .environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.skipOnboarding]))
        .preferredColorScheme(.dark)
}

#Preview("Imported") {
    var meal = SampleData.meals[0]
    meal.importedFrom = "ChatGPT project"
    meal.sourceNote = "ChatGPT project"
    return NavigationStack { MealDetailView(meal: meal) }
        .environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.skipOnboarding]))
}

#Preview("AX5") {
    NavigationStack { MealDetailView(meal: SampleData.meals[1]) }
        .environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.skipOnboarding]))
        .environment(\.dynamicTypeSize, .accessibility5)
}
