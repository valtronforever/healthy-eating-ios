import SwiftUI

/// Vitamin and mineral goals (ios#45, backend #35): every nutrient with the range that applies
/// and where it comes from. The person's own goal replaces their life stage's reference for that
/// nutrient. Ranges only, never judged.
struct MicronutrientGoalsView: View {
    let settings: UserSettings
    var onSave: (APIClient.SettingsChange) async -> APIError?

    var body: some View {
        List {
            section("Vitamins", Micronutrient.vitamins)
            section("Minerals", Micronutrient.minerals)
            Section {
                EmptyView()
            } footer: {
                Text(verbatim: Self.footer(settings.referenceGroup)).sectionTextStyle()
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.bg)
        .navigationTitle("Vitamin and mineral goals")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func section(_ title: LocalizedStringKey, _ nutrients: [Micronutrient]) -> some View {
        Section {
            ForEach(nutrients) { nutrient in
                NavigationLink {
                    MicronutrientGoalEditor(
                        nutrient: nutrient, goal: settings.micronutrientGoals[nutrient],
                        reference: settings.micronutrientReferences[nutrient],
                        group: settings.referenceGroup, onSave: onSave)
                } label: {
                    LabeledContent {
                        Text(verbatim: Self.summary(settings.micronutrientRanges[nutrient], nutrient.unit))
                            .foregroundStyle(.inkMuted)
                    } label: {
                        Text(verbatim: nutrient.name).foregroundStyle(.ink)
                    }
                }
                .accessibilityIdentifier("goal.\(nutrient.rawValue)")
            }
        } header: {
            Text(title).sectionTextStyle()
        }
        .listRowBackground(Color.surface)
    }

    /// "Your goal at least 50 µg", "Reference 8–45 mg" or "Not set".
    nonisolated static func summary(_ range: MicronutrientRange?, _ unit: NutrientUnit) -> String {
        guard let range, range.min != nil || range.max != nil else { return String(localized: "Not set") }
        return NutritionFormat.range(range, unit)
    }

    nonisolated static func footer(_ group: ReferenceGroup?) -> String {
        let source = group.map {
            String(localized: "References are the US Dietary Reference Intakes for \($0.name), from the NIH Office of Dietary Supplements.")
        } ?? String(localized: "Choose a life stage in Settings to see reference values.")
        return source + " " + String(localized: "Your goal replaces the reference for its nutrient. A doctor’s advice comes first.")
    }
}

/// The range editor for one vitamin or mineral, like the target ranges: either bound may stay
/// empty, never a single number, nothing judged.
struct MicronutrientGoalEditor: View {
    let nutrient: Micronutrient
    let goal: TargetRange?
    let reference: ReferenceRange?
    let group: ReferenceGroup?
    var onSave: (APIClient.SettingsChange) async -> APIError?

    @Environment(\.dismiss) private var dismiss
    @State private var low = ""
    @State private var high = ""
    @State private var error: String?
    @State private var isSaving = false

    var body: some View {
        Form {
            Section {
                boundRow("From", text: $low)
                boundRow("To", text: $high)
            } header: {
                Text(verbatim: nutrient.name).sectionTextStyle()
            } footer: {
                VStack(alignment: .leading, spacing: Spacing.s2) {
                    if let line = Self.referenceLine(reference, group, nutrient.unit) { Text(verbatim: line) }
                    Text("Leave a field empty for an open range. Your days are shown against this range, never judged by it.")
                    if let error { Text(verbatim: error) }
                }
                .sectionTextStyle()
            }
            .listRowBackground(Color.surface)
            if goal != nil {
                Section {
                    Button(reference == nil ? "Remove your goal" : "Use the reference instead") {
                        Task { await save(.some(nil)) }
                    }
                    .disabled(isSaving)
                    .accessibilityIdentifier("removeGoal")
                }
                .listRowBackground(Color.surface)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.bg)
        .navigationTitle(Text(verbatim: nutrient.name))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { Task { await save(change) } }
                    .disabled(isSaving || change == nil)
            }
        }
        .onAppear {
            low = Self.text(goal?.min)
            high = Self.text(goal?.max)
        }
    }

    private func boundRow(_ title: LocalizedStringKey, text: Binding<String>) -> some View {
        HStack {
            Text(title).foregroundStyle(.ink)
            Spacer()
            TextField("", text: text, prompt: Text("Open"))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .metricFont(.small)
                .accessibilityLabel(Text(title))
            Text(verbatim: nutrient.unit.symbol).foregroundStyle(.inkMuted)
        }
    }

    /// The new goal; `.some(nil)` removes it; nil when nothing changed.
    private var change: TargetRange?? {
        let range = TargetRange(min: MealEditView.number(low), max: MealEditView.number(high))
        let empty = range.min == nil && range.max == nil
        if empty { return goal == nil ? nil : .some(nil) }
        return range == goal ? nil : .some(range)
    }

    private func save(_ change: TargetRange??) async {
        guard let change else { return }
        if let message = Self.problem(change ?? nil) {
            error = message
            return
        }
        isSaving = true
        defer { isSaving = false }
        if let failure = await onSave(APIClient.SettingsChange(micronutrientGoals: [nutrient: change])) {
            error = failure.message
        } else {
            dismiss()
        }
    }

    /// Why a range can't be saved: reversed, or one number for both ends (a goal is a range).
    nonisolated static func problem(_ range: TargetRange?) -> String? {
        guard let low = range?.min, let high = range?.max else { return nil }
        if low > high { return String(localized: "The start of a range can’t be above its end.") }
        if low == high { return String(localized: "A goal is a range. Leave one field empty or use two different numbers.") }
        return nil
    }

    /// "Reference 18–45 mg (Women 31–50)." when a life stage is chosen.
    nonisolated static func referenceLine(_ reference: ReferenceRange?, _ group: ReferenceGroup?, _ unit: NutrientUnit) -> String? {
        guard let reference, let group else { return nil }
        let range = NutritionFormat.range(MicronutrientRange(min: reference.min, max: reference.max, source: .reference), unit)
        return String(localized: "\(range) (\(group.name)).")
    }

    /// Up to two decimals (vitamin B12 2.4 µg, thiamin 1.15 mg), no grouping.
    nonisolated static func text(_ value: Double?, locale: Locale = .current) -> String {
        value?.formatted(.number.precision(.fractionLength(0...2)).grouping(.never).locale(locale)) ?? ""
    }
}

private let previewSettings = UserSettings(
    timeZone: "Europe/Berlin", energyUnit: .kcal, calmMode: false, targets: [:],
    referenceGroup: .women31to50,
    micronutrientReferences: SampleData.references(for: .women31to50),
    micronutrientGoals: [.vitaminD: TargetRange(min: 50, max: nil)],
    micronutrientRanges: SampleData.references(for: .women31to50)
        .mapValues { MicronutrientRange(min: $0.min, max: $0.max, source: .reference) }
        .merging([.vitaminD: MicronutrientRange(min: 50, max: nil, source: .personal)]) { $1 })

#Preview("Light") {
    NavigationStack { MicronutrientGoalsView(settings: previewSettings) { _ in nil } }
}

#Preview("Dark") {
    NavigationStack { MicronutrientGoalsView(settings: previewSettings) { _ in nil } }
        .preferredColorScheme(.dark)
}

#Preview("AX5") {
    NavigationStack { MicronutrientGoalsView(settings: previewSettings) { _ in nil } }
        .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Editor") {
    NavigationStack {
        MicronutrientGoalEditor(
            nutrient: .iron, goal: TargetRange(min: 10, max: 20), reference: ReferenceRange(min: 18, max: 45),
            group: .women31to50) { _ in nil }
    }
}
