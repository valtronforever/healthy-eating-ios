import SwiftUI

/// Adds a weigh-in typed in the app, or corrects or deletes one (ios#41). The only data entry in
/// the app besides correcting meals. The weight is typed in the person's unit and sent in kg.
/// No celebration or warning about the value: it is a plain number.
struct WeighInForm: View {
    /// nil adds a new weigh-in.
    var entry: WeighIn?
    let unit: WeightUnit
    var onSaved: () -> Void = {}

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var date = Date.now
    @State private var isSaving = false
    @State private var error: APIError?
    @State private var confirmingDelete = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Weight").foregroundStyle(.ink)
                        Spacer()
                        TextField("0.0", text: $text)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .fontDesign(.rounded)
                            .monospacedDigit()
                            .frame(maxWidth: 120)
                            .accessibilityIdentifier("weightValue")
                        Text(verbatim: unit.symbol).foregroundStyle(.inkMuted)
                    }
                    DatePicker("When", selection: $date, in: ...Date.now)
                } footer: {
                    if let message = Self.problem(text, unit: unit) ?? error?.message {
                        Text(verbatim: message).sectionTextStyle()
                    }
                }
                .listRowBackground(Color.surface)

                if entry != nil {
                    Section {
                        Button("Delete weigh-in") { confirmingDelete = true }
                            .buttonStyle(.action(.destructive))
                            .plainListRow()
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.bg)
            .navigationTitle(entry == nil ? "Add weigh-in" : "Edit weigh-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(isSaving || Self.kg(from: text, unit: unit) == nil)
                }
            }
            .confirmationDialog("Delete this weigh-in?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete weigh-in", role: .destructive) { Task { await delete() } }
                Button("Cancel", role: .cancel) {}
            }
            .onAppear(perform: fill)
        }
    }

    private func fill() {
        guard let entry else { return }
        text = Self.text(entry.weightKg, unit: unit)
        date = entry.measuredAt
    }

    private func save() async {
        guard let data = app.data, let kg = Self.kg(from: text, unit: unit) else { return }
        isSaving = true
        defer { isSaving = false }
        do throws(APIError) {
            if let entry {
                _ = try await data.updateWeight(entry.id, kg: kg, at: date)
            } else {
                _ = try await data.addWeight(kg: kg, at: date)
            }
            onSaved()
            dismiss()
        } catch {
            self.error = error
            app.handle(error)
        }
    }

    private func delete() async {
        guard let data = app.data, let entry else { return }
        do throws(APIError) {
            try await data.deleteWeight(entry.id)
            onSaved()
            dismiss()
        } catch .notFound {
            onSaved()
            dismiss()
        } catch {
            self.error = error
            app.handle(error)
        }
    }

    // MARK: Parsing (the person's unit in, kg out)

    /// The weight in kg, or nil when the text is not a plausible weight (20 to 400 kg).
    nonisolated static func kg(from text: String, unit: WeightUnit) -> Double? {
        // Either decimal separator is accepted, whatever the locale.
        let normalized = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized) else { return nil }
        let kg = unit.kg(from: value)
        guard (20...400).contains(kg) else { return nil }
        return (kg * 100).rounded() / 100
    }

    nonisolated static func text(_ kg: Double, unit: WeightUnit, locale: Locale = .current) -> String {
        unit.amount(fromKg: kg).formatted(.number.precision(.fractionLength(1)).locale(locale).grouping(.never))
    }

    nonisolated static func problem(_ text: String, unit: WeightUnit) -> String? {
        guard !text.isEmpty, kg(from: text, unit: unit) == nil else { return nil }
        let low = unit.amount(fromKg: 20).rounded(), high = unit.amount(fromKg: 400).rounded()
        return String(localized: "Enter a weight between \(Int(low)) and \(Int(high)) \(unit.symbol).")
    }
}
