import SwiftUI

/// One past day, opened from History: the same summary and meal list as Today, and the day's
/// completeness mark (complete, partial or not marked).
struct DayView: View {
    let date: Date
    /// Called after a meal or the mark changed, so History reloads.
    var onChange: () -> Void = {}

    @Environment(AppModel.self) private var app
    @State private var state: Loadable<Snapshot> = .loading
    @State private var markError: APIError?
    @State private var isMarking = false

    struct Snapshot {
        var meals: [Meal]
        var day: DayTotals?
        var settings: UserSettings
    }

    var body: some View {
        content
            .background(Color.bg)
            .navigationTitle(Text(date, format: .dateTime.weekday(.wide).month(.abbreviated).day()))
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Meal.self) { meal in
                MealDetailView(meal: meal) {
                    Task { await reload() }
                    onChange()
                }
            }
            .task { await reload() }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .loading:
            ScrollView { LoadingCards().padding(.horizontal, Spacing.s4) }
        case .failed(let error):
            ScrollView {
                ServerErrorMessage(error: error, host: app.server?.host) { Task { await reload() } }
                    .padding(.top, Spacing.s8)
            }
        case .loaded(let snapshot):
            List {
                Section {
                    if let markError {
                        Banner(kind: .error, message: markError.message).plainListRow()
                    }
                    DaySummaryCard(day: snapshot.day, settings: snapshot.settings, calm: app.calmMode).plainListRow()
                }
                .listSectionSpacing(Spacing.s3)

                if snapshot.meals.isEmpty {
                    Section {
                        Text("No meals logged on this day.")
                            .foregroundStyle(.inkMuted)
                            .frame(maxWidth: .infinity)
                            .cardStyle(padding: Spacing.s5)
                            .plainListRow()
                    }
                } else {
                    Section {
                        ForEach(snapshot.meals) { meal in
                            NavigationLink(value: meal) {
                                MealRow(meal: meal, hideKcal: app.calmMode)
                            }
                        }
                    } header: {
                        Text("Meals").sectionTextStyle()
                    }
                    .listRowBackground(Color.surface)
                }

                Section {
                    Picker("This day", selection: markBinding(snapshot.day?.status)) {
                        Text("Complete").tag(DayMark?.some(.complete))
                        Text("Partial").tag(DayMark?.some(.partial))
                        Text("Not marked").tag(DayMark?.none)
                    }
                    .pickerStyle(.segmented)
                    .disabled(isMarking)
                    .plainListRow()
                } header: {
                    Text("Mark this day").sectionTextStyle()
                } footer: {
                    Text("Complete: every meal of the day is logged. Partial: some are missing. Your averages use complete days once you mark one.")
                        .sectionTextStyle()
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .refreshable { await reload() }
        }
    }

    private func markBinding(_ current: DayMark?) -> Binding<DayMark?> {
        Binding(get: { current }, set: { mark in Task { await setMark(mark) } })
    }

    private func reload() async {
        guard let data = app.data else { return }
        do {
            async let meals = data.meals(on: date)
            async let days = data.days(from: date, to: date)
            async let settings = data.settings()
            state = .loaded(Snapshot(meals: try await meals, day: try await days.days.first, settings: try await settings))
        } catch {
            let apiError = error as? APIError ?? .unexpectedResponse(String(describing: error))
            if state.value == nil { state = .failed(apiError) }
            app.handle(apiError)
        }
    }

    private func setMark(_ mark: DayMark?) async {
        guard let data = app.data else { return }
        isMarking = true
        defer { isMarking = false }
        do throws(APIError) {
            try await data.setMark(mark, on: date)
            markError = nil
            await reload()
            onChange()
        } catch {
            markError = error
            app.handle(error)
        }
    }
}

/// The summary card for a day's totals against the target ranges (Today and past days).
struct DaySummaryCard: View {
    let day: DayTotals?
    let settings: UserSettings
    var calm = false

    var body: some View {
        let targets = settings.targets
        let macros = [(Macro.protein, NutrientField.protein), (.fat, .fat), (.carbs, .carbohydrates)].map { macro, field in
            MacroProgress(macro: macro, value: value(of: macro), min: targets[field]?.min, max: targets[field]?.max)
        }
        return SummaryCard(
            kcal: day?.caloriesKcal ?? 0, kcalTarget: targets[.calories] ?? TargetRange(),
            macros: macros, energyUnit: settings.energyUnit, calm: calm)
    }

    private func value(of macro: Macro) -> Double {
        guard let day else { return 0 }
        switch macro {
        case .protein: return day.proteinG
        case .fat: return day.fatG
        case .carbs: return day.carbohydratesG
        }
    }
}

#Preview("Light") {
    NavigationStack { DayView(date: .now.addingTimeInterval(-86_400)) }
        .environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.skipOnboarding]))
}

#Preview("Dark") {
    NavigationStack { DayView(date: .now.addingTimeInterval(-86_400)) }
        .environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.skipOnboarding]))
        .preferredColorScheme(.dark)
}

#Preview("AX5") {
    NavigationStack { DayView(date: .now.addingTimeInterval(-86_400)) }
        .environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.skipOnboarding]))
        .environment(\.dynamicTypeSize, .accessibility5)
}
