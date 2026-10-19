import SwiftUI

/// Target ranges for calories and macros. Either bound may stay empty ("at least 110 g").
/// Ranges, never single numbers or limits: being over or under is shown the same way.
struct TargetsView: View {
    let settings: UserSettings
    var onSave: (APIClient.SettingsChange) async -> APIError?

    @Environment(\.dismiss) private var dismiss
    @State private var mins: [NutrientField: String] = [:]
    @State private var maxes: [NutrientField: String] = [:]
    @State private var error: String?
    @State private var isSaving = false

    private let fields: [(NutrientField, LocalizedStringKey)] = [
        (.calories, "Calories"), (.protein, "Protein"), (.fat, "Fat"), (.carbohydrates, "Carbohydrates"),
    ]

    var body: some View {
        Form {
            ForEach(fields, id: \.0) { field, title in
                Section {
                    boundRow("From", field: field, text: minBinding(field))
                    boundRow("To", field: field, text: maxBinding(field))
                } header: {
                    Text(title).sectionTextStyle()
                }
                .listRowBackground(Color.surface)
            }
            Section {
                EmptyView()
            } footer: {
                VStack(alignment: .leading, spacing: Spacing.s2) {
                    Text("Leave a field empty for an open range. Your days are shown against these ranges, never judged by them.")
                    if let error { Text(verbatim: error) }
                }
                .sectionTextStyle()
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.bg)
        .navigationTitle("Target ranges")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { Task { await save() } }
                    .disabled(isSaving || change == nil)
            }
        }
        .onAppear(perform: fill)
    }

    private func unit(for field: NutrientField) -> NutrientUnit {
        field == .calories ? settings.energyUnit.nutrientUnit : .grams
    }

    private func boundRow(_ title: LocalizedStringKey, field: NutrientField, text: Binding<String>) -> some View {
        HStack {
            Text(title).foregroundStyle(.ink)
            Spacer()
            TextField("", text: text, prompt: Text("Open"))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .metricFont(.small)
                .accessibilityLabel(Text(title))
            Text(verbatim: unit(for: field).symbol).foregroundStyle(.inkMuted)
        }
    }

    private func minBinding(_ field: NutrientField) -> Binding<String> {
        Binding(get: { mins[field] ?? "" }, set: { mins[field] = $0 })
    }

    private func maxBinding(_ field: NutrientField) -> Binding<String> {
        Binding(get: { maxes[field] ?? "" }, set: { maxes[field] = $0 })
    }

    /// Values shown in the person's energy unit, stored in kcal.
    private func shown(_ kcalOrGrams: Double?, _ field: NutrientField) -> String {
        guard let value = kcalOrGrams else { return "" }
        let amount = field == .calories ? settings.energyUnit.amount(fromKcal: value) : value
        return MealEditView.text(amount.rounded())
    }

    private func stored(_ text: String, _ field: NutrientField) -> Double? {
        guard let value = MealEditView.number(text) else { return nil }
        guard field == .calories, settings.energyUnit == .kj else { return value }
        return (Measurement(value: value, unit: UnitEnergy.kilojoules).converted(to: .kilocalories).value).rounded()
    }

    private func fill() {
        for (field, _) in fields {
            mins[field] = shown(settings.targets[field]?.min, field)
            maxes[field] = shown(settings.targets[field]?.max, field)
        }
    }

    /// Only targets that changed; nil when nothing changed.
    private var change: APIClient.SettingsChange? {
        var targets: [NutrientField: TargetRange?] = [:]
        for (field, _) in fields {
            let low = stored(mins[field] ?? "", field)
            let high = stored(maxes[field] ?? "", field)
            let old = settings.targets[field]
            let unchanged = (mins[field] ?? "") == shown(old?.min, field) && (maxes[field] ?? "") == shown(old?.max, field)
            if unchanged { continue }
            targets[field] = (low == nil && high == nil) ? .some(nil) : .some(TargetRange(min: low, max: high))
        }
        return targets.isEmpty ? nil : APIClient.SettingsChange(targets: targets)
    }

    private func save() async {
        guard let change else { return }
        let reversed = change.targets.values.contains { range in
            guard let low = range?.min, let high = range?.max else { return false }
            return low > high
        }
        if reversed {
            error = String(localized: "The start of a range can’t be above its end.")
            return
        }
        isSaving = true
        defer { isSaving = false }
        if let failure = await onSave(change) {
            error = failure.message
        } else {
            dismiss()
        }
    }
}
