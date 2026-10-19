import SwiftUI

/// B4 Edit meal: name, time, values and portion. A value the person changes becomes their own
/// number (the badge switches to "Your numbers"); the server decides and stores that.
/// New meals are never created here: food is logged in the chat.
struct MealEditView: View {
    let meal: Meal
    var onSaved: (Meal, [String]) -> Void

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var time: Date
    @State private var values: [NutrientField: String]
    @State private var portion: String
    @State private var isSaving = false
    @State private var error: APIError?
    /// The value boxes line up in one column, as on the board.
    @ScaledMetric(relativeTo: .body) private var fieldWidth: CGFloat = 92
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(meal: Meal, onSaved: @escaping (Meal, [String]) -> Void) {
        self.meal = meal
        self.onSaved = onSaved
        _name = State(initialValue: meal.dishName)
        _time = State(initialValue: meal.eatenAt)
        _values = State(initialValue: [
            .calories: Self.text(meal.caloriesKcal), .protein: Self.text(meal.proteinG),
            .fat: Self.text(meal.fatG), .carbohydrates: Self.text(meal.carbohydratesG),
        ])
        _portion = State(initialValue: meal.portionGrams.map(Self.text) ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Dish name", text: $name)
                        .accessibilityIdentifier("dishName")
                    DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                } header: {
                    Text("Meal").sectionTextStyle()
                } footer: {
                    if let message = fieldError("dish_name") ?? fieldError("eaten_at") {
                        Text(verbatim: message).sectionTextStyle()
                    }
                }
                .listRowBackground(Color.surface)

                Section {
                    valueRow("Calories", field: .calories, unit: .kcal)
                    valueRow("Protein", field: .protein, unit: .grams)
                    valueRow("Fat", field: .fat, unit: .grams)
                    valueRow("Carbohydrates", field: .carbohydrates, unit: .grams)
                    numberRow("Portion", text: $portion, unit: .grams, badge: nil, identifier: "portion_grams")
                } header: {
                    Text("Values").sectionTextStyle()
                } footer: {
                    VStack(alignment: .leading, spacing: Spacing.s2) {
                        Text("Values you change are saved as your numbers.")
                        if let error, case .invalid = error {} else if let error {
                            Text(verbatim: error.message)
                        }
                    }
                    .sectionTextStyle()
                }
                .listRowBackground(Color.surface)
            }
            .scrollContentBackground(.hidden)
            .background(Color.bg)
            .navigationTitle("Edit meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(!hasChanges || !isValid || isSaving)
                }
            }
            .interactiveDismissDisabled(hasChanges)
        }
    }

    // MARK: Rows

    private func valueRow(_ title: LocalizedStringKey, field: NutrientField, unit: NutrientUnit) -> some View {
        let changed = Self.number(values[field] ?? "") != original(field)
        let estimated = meal.estimatedFields.contains(field) && !changed
        return numberRow(title, text: binding(for: field), unit: unit,
                         badge: estimated ? .estimated : .user, identifier: field.rawValue)
    }

    private func numberRow(
        _ title: LocalizedStringKey, text: Binding<String>, unit: NutrientUnit, badge: Provenance?, identifier: String
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s1) {
            // The layout depends only on the text size, never on the content, so a row does not
            // jump (and lose the keyboard) when its badge changes while typing.
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Spacing.s2) { rowContent(title, text: text, unit: unit, badge: badge, identifier: identifier) }
            } else {
                HStack(spacing: Spacing.s2) { rowContent(title, text: text, unit: unit, badge: badge, identifier: identifier) }
            }
            if let message = fieldError(identifier) {
                Text(verbatim: message).font(.footnote).foregroundStyle(.inkMuted)
            }
        }
    }

    @ViewBuilder
    private func rowContent(
        _ title: LocalizedStringKey, text: Binding<String>, unit: NutrientUnit, badge: Provenance?, identifier: String
    ) -> some View {
        Text(title).foregroundStyle(.ink).lineLimit(2).minimumScaleFactor(0.8).layoutPriority(1)
        Spacer(minLength: 0)
        if let badge { ProvenanceBadge(kind: badge) }
        HStack(spacing: 4) {
            TextField("", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .metricFont(.small)
                .accessibilityLabel(Text(title))
                .accessibilityIdentifier(identifier)
            Text(unit.symbol).foregroundStyle(.inkMuted).lineLimit(1).fixedSize()
        }
        .frame(width: fieldWidth, alignment: .trailing)
        .padding(.horizontal, Spacing.s3)
        .padding(.vertical, Spacing.s2)
        .background(Color.surfaceSunken, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
    }

    private func binding(for field: NutrientField) -> Binding<String> {
        Binding(get: { values[field] ?? "" }, set: { values[field] = $0 })
    }

    // MARK: Values

    private func original(_ field: NutrientField) -> Double {
        switch field {
        case .calories: meal.caloriesKcal
        case .protein: meal.proteinG
        case .fat: meal.fatG
        case .carbohydrates: meal.carbohydratesG
        }
    }

    private var edit: APIClient.MealEdit {
        var edit = APIClient.MealEdit()
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed != meal.dishName { edit.dishName = trimmed }
        if time != meal.eatenAt { edit.eatenAt = time }
        for field in NutrientField.allCases {
            guard let value = Self.number(values[field] ?? ""), value != original(field) else { continue }
            switch field {
            case .calories: edit.caloriesKcal = value
            case .protein: edit.proteinG = value
            case .fat: edit.fatG = value
            case .carbohydrates: edit.carbohydratesG = value
            }
        }
        let newPortion = Self.number(portion)
        if newPortion != meal.portionGrams { edit.portionGrams = .some(newPortion) }
        return edit
    }

    private var hasChanges: Bool { edit != APIClient.MealEdit() }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && NutrientField.allCases.allSatisfy { Self.number(values[$0] ?? "") != nil }
            && (portion.isEmpty || Self.number(portion) != nil)
    }

    private func fieldError(_ field: String) -> String? {
        if case .invalid(_, let fields) = error { return fields[field] }
        return nil
    }

    private func save() async {
        guard let data = app.data else { return }
        isSaving = true
        defer { isSaving = false }
        do throws(APIError) {
            let result = try await data.update(meal.id, with: edit)
            onSaved(result.meal, result.warnings)
            dismiss()
        } catch {
            self.error = error
            app.handle(error)
        }
    }

    // MARK: Number text

    static func text(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)).grouping(.never))
    }

    /// Reads a number typed with the device's decimal separator; nil for empty or invalid text.
    static func number(_ text: String, locale: Locale = .current) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        return try? Double(trimmed, format: .number.locale(locale))
    }
}

#Preview("Light") {
    MealEditView(meal: SampleData.meals[1]) { _, _ in }
        .environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.skipOnboarding]))
}

#Preview("Dark") {
    MealEditView(meal: SampleData.meals[1]) { _, _ in }
        .environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.skipOnboarding]))
        .preferredColorScheme(.dark)
}

#Preview("AX5") {
    MealEditView(meal: SampleData.meals[1]) { _, _ in }
        .environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.skipOnboarding]))
        .environment(\.dynamicTypeSize, .accessibility5)
}
