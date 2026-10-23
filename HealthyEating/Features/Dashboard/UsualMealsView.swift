import SwiftUI

/// Usual meals with one-tap re-log (ios#39), opened from Today: dishes eaten at least twice in
/// the last 90 days. Choosing one logs it again with the same values and provenance at a time
/// the person picks (default now). The app never creates meals from scratch; new food is
/// logged in the chat (decision ios#13).
struct UsualMealsView: View {
    var energyUnit: EnergyUnit = .kcal
    /// Called after a meal was logged, so Today reloads.
    var onLogged: () -> Void = {}

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var state: Loadable<[UsualMeal]> = .loading

    var body: some View {
        NavigationStack {
            List {
                switch state {
                case .loading:
                    LoadingCards().plainListRow()
                case .failed(let error):
                    ServerErrorMessage(error: error, host: app.server?.host) { Task { await reload() } }
                        .padding(.top, Spacing.s6)
                        .plainListRow()
                case .loaded(let meals) where meals.isEmpty:
                    VStack(spacing: Spacing.s1) {
                        Text("No usual meals yet")
                            .font(.headline)
                            .foregroundStyle(.ink)
                        Text("Meals you log at least twice within 90 days appear here, ready to log again.")
                            .foregroundStyle(.inkMuted)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .cardStyle(padding: Spacing.s5)
                    .plainListRow()
                case .loaded(let meals):
                    Section {
                        ForEach(meals) { usual in
                            NavigationLink {
                                RelogMealView(usual: usual, energyUnit: energyUnit) {
                                    onLogged()
                                    dismiss()
                                }
                            } label: {
                                row(usual)
                            }
                        }
                    } footer: {
                        Text("Logging a meal again copies its values and where they came from. New food is logged in your chat.")
                            .sectionTextStyle()
                    }
                    .listRowBackground(Color.surface)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.bg)
            .navigationTitle("Usual meals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task { await reload() }
        }
    }

    private func row(_ usual: UsualMeal) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(usual.meal.dishName)
                .font(.headline)
                .foregroundStyle(.ink)
            Text(verbatim: Self.valuesLine(usual.meal, energyUnit: energyUnit, calm: app.calmMode))
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(.inkMuted)
            Text(verbatim: Self.timesLine(usual.times))
                .font(.footnote)
                .foregroundStyle(.inkMuted)
        }
        .padding(.vertical, Spacing.s1)
        .accessibilityElement(children: .combine)
    }

    private func reload() async {
        guard let data = app.data else { return }
        do throws(APIError) {
            state = .loaded(try await data.usualMeals())
        } catch {
            if state.value == nil { state = .failed(error) }
            app.handle(error)
        }
    }

    /// "380 kcal · P 14 g · F 9 g · C 58 g"; the macros only in Calm mode.
    nonisolated static func valuesLine(_ meal: Meal, energyUnit: EnergyUnit, calm: Bool, locale: Locale = .current) -> String {
        let macros = NutritionFormat.macroLine(protein: meal.proteinG, fat: meal.fatG, carbs: meal.carbohydratesG, locale: locale)
        return calm ? macros : "\(NutritionFormat.energy(meal.caloriesKcal, in: energyUnit, locale: locale)) · \(macros)"
    }

    nonisolated static func timesLine(_ times: Int) -> String {
        String(localized: "\(times) times in the last 90 days")
    }
}

/// One usual meal: its values and provenance, when it was eaten (default now) and "Log meal".
struct RelogMealView: View {
    let usual: UsualMeal
    var energyUnit: EnergyUnit = .kcal
    var onLogged: () -> Void

    @Environment(AppModel.self) private var app
    @State private var date = Date.now
    /// Chosen once, so a retried request saves the meal only once.
    @State private var newID = UUID()
    @State private var isSaving = false
    @State private var error: APIError?

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: Spacing.s2) {
                    Text(usual.meal.dishName)
                        .font(.headline)
                        .foregroundStyle(.ink)
                    Text(verbatim: UsualMealsView.valuesLine(usual.meal, energyUnit: energyUnit, calm: app.calmMode))
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(.inkMuted)
                    FlowLayout {
                        ProvenanceBadge(kind: usual.meal.provenance)
                        if usual.meal.provenance == .estimated, let confidence = usual.meal.confidence {
                            ConfidenceIndicator(level: confidence, short: true)
                        }
                    }
                }
                .padding(.vertical, Spacing.s1)
                DatePicker("When", selection: $date, in: ...Date.now)
                    .accessibilityIdentifier("relogTime")
            } footer: {
                if let error {
                    Text(verbatim: error.message).sectionTextStyle()
                }
            }
            .listRowBackground(Color.surface)

            Section {
                Button("Log meal") { Task { await save() } }
                    .buttonStyle(.action(.primary))
                    .disabled(isSaving)
                    .accessibilityIdentifier("logMeal")
                    .plainListRow()
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.bg)
        .navigationTitle("Log again")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func save() async {
        guard let data = app.data else { return }
        isSaving = true
        defer { isSaving = false }
        do throws(APIError) {
            _ = try await data.relog(usual.meal.id, as: newID, at: date)
            onLogged()
        } catch {
            self.error = error
            app.handle(error)
        }
    }
}

#Preview("Light") {
    UsualMealsView()
        .environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.skipOnboarding]))
}

#Preview("Dark") {
    UsualMealsView()
        .environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.skipOnboarding]))
        .preferredColorScheme(.dark)
}

#Preview("AX5") {
    UsualMealsView()
        .environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.skipOnboarding]))
        .environment(\.dynamicTypeSize, .accessibility5)
}
