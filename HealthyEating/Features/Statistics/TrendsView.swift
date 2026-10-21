import SwiftUI

/// Loads Trends: the backend's averages for the window, the days for the chart, and targets.
@MainActor
@Observable
final class TrendsModel {
    struct Snapshot {
        var trends: Trends
        var days: [DayTotals]
        var settings: UserSettings
    }

    private(set) var state: Loadable<Snapshot> = .loading

    func load(window: Int, _ data: any NutritionDataSource, calendar: Calendar = .current) async -> APIError? {
        let today = calendar.startOfDay(for: .now)
        let first = calendar.date(byAdding: .day, value: -(window - 1), to: today) ?? today
        do {
            async let trends = data.trends(window: window)
            async let days = data.days(from: first, to: today)
            async let settings = data.settings()
            state = .loaded(Snapshot(trends: try await trends, days: try await days.days, settings: try await settings))
            return nil
        } catch {
            let apiError = error as? APIError ?? .unexpectedResponse(String(describing: error))
            if state.value == nil { state = .failed(apiError) }
            return apiError
        }
    }
}

/// D1 Trends: the average per counted day over 7, 30 or 90 days with the daily bars, macro
/// averages against their ranges, the comparison with the previous window (worded as lower or
/// higher, never better or worse) and how many days were counted. All numbers come from the
/// backend.
struct TrendsView: View {
    enum Period: Int, CaseIterable, Identifiable {
        case week = 7, month = 30, quarter = 90

        var id: Int { rawValue }

        var title: LocalizedStringKey {
            switch self {
            case .week: "7 days"
            case .month: "30 days"
            case .quarter: "90 days"
            }
        }
    }

    @Environment(AppModel.self) private var app
    @State private var period: Period = .month
    @State private var model = TrendsModel()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Period", selection: $period) {
                        ForEach(Period.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .plainListRow()

                    switch model.state {
                    case .loading:
                        LoadingCards().plainListRow()
                    case .failed(let error):
                        ServerErrorMessage(error: error, host: app.server?.host) { Task { await reload() } }
                            .padding(.top, Spacing.s6)
                            .plainListRow()
                    case .loaded(let snapshot):
                        if snapshot.trends.current.loggedDays == 0 {
                            emptyCard.plainListRow()
                        } else {
                            if !app.calmMode {
                                averageCard(snapshot).plainListRow()
                            }
                            macroCard(snapshot).plainListRow()
                            if !snapshot.trends.current.optionalAverages.isEmpty {
                                OptionalAveragesCard(
                                    averages: snapshot.trends.current.optionalAverages,
                                    countedDays: snapshot.trends.current.countedDays
                                ).plainListRow()
                            }
                        }
                    }
                }
                .listSectionSpacing(Spacing.s4)

                if let snapshot = model.state.value, snapshot.trends.current.loggedDays > 0 {
                    comparisonSection(snapshot)
                }

                Section {
                    NavigationLink {
                        WeeklyReviewView()
                    } label: {
                        HStack(spacing: Spacing.s3) {
                            SymbolTile(systemName: "calendar", small: true)
                            Text("Weekly review").foregroundStyle(.ink)
                        }
                    }
                    .accessibilityIdentifier("weeklyReview")
                }
                .listRowBackground(Color.surface)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.bg)
            .navigationTitle("Trends")
            .refreshable { await reload() }
        }
        .task(id: period) { await reload() }
    }

    private func reload() async {
        guard let data = app.data else { return }
        if let error = await model.load(window: period.rawValue, data) { app.handle(error) }
    }

    private var emptyCard: some View {
        VStack(spacing: Spacing.s1) {
            Text("No days to show yet")
                .font(.headline)
                .foregroundStyle(.ink)
            Text("Averages appear here once meals arrive from your assistant.")
                .foregroundStyle(.inkMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .cardStyle(padding: Spacing.s5)
    }

    private func averageCard(_ snapshot: TrendsModel.Snapshot) -> some View {
        let unit = snapshot.settings.energyUnit
        let average = snapshot.trends.current.averages?.caloriesKcal
        let target = snapshot.settings.targets[.calories] ?? TargetRange()
        return VStack(alignment: .leading, spacing: Spacing.s2) {
            Text("Average per day")
                .font(.subheadline)
                .foregroundStyle(.inkMuted)
            HStack(alignment: .firstTextBaseline, spacing: Spacing.s2) {
                Text(average.map { NutritionFormat.number(unit.amount(fromKcal: $0)) } ?? "–")
                    .metricFont(.regular)
                    .foregroundStyle(.ink)
                Text(unit.nutrientUnit.symbol)
                    .font(.subheadline)
                    .foregroundStyle(.inkMuted)
            }
            .accessibilityElement(children: .combine)
            KcalBarChart(
                days: snapshot.days.map { KcalDay(date: $0.date, kcal: $0.caloriesKcal, state: $0.state) },
                target: target, average: average,
                scaleMax: scaleMax(snapshot.days, target: target),
                title: String(localized: "Calories per day, last \(period.rawValue) days"))
        }
        .cardStyle()
    }

    private func scaleMax(_ days: [DayTotals], target: TargetRange) -> Double {
        let highest = max(days.map(\.caloriesKcal).max() ?? 0, target.max ?? target.min ?? 0)
        return max(1000, (highest * 1.15 / 500).rounded(.up) * 500)
    }

    private func macroCard(_ snapshot: TrendsModel.Snapshot) -> some View {
        let averages = snapshot.trends.current.averages
        let targets = snapshot.settings.targets
        let rows = [(Macro.protein, NutrientField.protein), (.fat, .fat), (.carbs, .carbohydrates)].map { macro, field in
            MacroProgress(macro: macro, value: averages?.value(of: macro) ?? 0, min: targets[field]?.min, max: targets[field]?.max)
        }
        return VStack(spacing: 0) {
            ForEach(rows) { MacroAverageLine(progress: $0) }
        }
        .cardStyle(padding: Spacing.s4)
    }

    private func comparisonSection(_ snapshot: TrendsModel.Snapshot) -> some View {
        let trends = snapshot.trends
        let unit = snapshot.settings.energyUnit
        return Section {
            if let change = trends.change {
                if !app.calmMode {
                    comparisonRow(String(localized: "Calories"), Self.energyChange(change.caloriesKcal, unit: unit))
                }
                comparisonRow(Macro.protein.name, Self.gramChange(change.proteinG))
                comparisonRow(Macro.fat.name, Self.gramChange(change.fatG))
                comparisonRow(Macro.carbs.name, Self.gramChange(change.carbohydratesG))
            } else {
                Text("Not enough counted days in the previous \(period.rawValue) days to compare.")
                    .foregroundStyle(.inkMuted)
            }
        } header: {
            Text("Compared with the previous \(period.rawValue) days").sectionTextStyle()
        } footer: {
            Text(Self.countedLine(trends))
                .sectionTextStyle()
        }
        .listRowBackground(Color.surface)
    }

    private func comparisonRow(_ label: String, _ value: String) -> some View {
        LabeledContent {
            Text(verbatim: value).foregroundStyle(.inkMuted)
        } label: {
            Text(verbatim: label).foregroundStyle(.ink)
        }
    }

    // MARK: Wording (neutral: lower or higher, never better or worse)

    nonisolated static func energyChange(_ kcal: Double, unit: EnergyUnit) -> String {
        guard abs(kcal) >= 20 else { return String(localized: "About the same") }
        let amount = NutritionFormat.value(abs(unit.amount(fromKcal: kcal)), unit.nutrientUnit)
        return kcal < 0 ? String(localized: "\(amount) lower") : String(localized: "\(amount) higher")
    }

    nonisolated static func gramChange(_ grams: Double) -> String {
        guard abs(grams) >= 2 else { return String(localized: "About the same") }
        let amount = NutritionFormat.value(abs(grams), .grams)
        return grams < 0 ? String(localized: "\(amount) lower") : String(localized: "\(amount) higher")
    }

    nonisolated static func countedLine(_ trends: Trends) -> String {
        let counted = trends.current.countedDays
        let window = trends.windowDays
        let left = window - counted
        switch trends.countingRule {
        case .completeDays:
            return String(localized: "Averages use \(counted) of \(window) days: the days marked complete (\(left) partial, unmarked or not logged days left out).")
        case .loggedDays:
            return String(localized: "Averages use \(counted) of \(window) days (\(left) partial or not logged days left out). Today counts once you mark it complete.")
        }
    }
}

/// One macro average with its colored dot, value and target range.
struct MacroAverageLine: View {
    let progress: MacroProgress
    @ScaledMetric(relativeTo: .body) private var dotSize: CGFloat = 8
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: Spacing.s2))
        layout {
            HStack(spacing: Spacing.s2) {
                Circle().fill(progress.macro.color).frame(width: dotSize, height: dotSize)
                Text(progress.macro.name).font(.body).foregroundStyle(.ink)
            }
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: Spacing.s2) }
            HStack(alignment: .firstTextBaseline, spacing: Spacing.s2) {
                Text(NutritionFormat.value(progress.value, .grams))
                    .metricFont(.small)
                    .foregroundStyle(.ink)
                Text(NutritionFormat.shortTarget(min: progress.min, max: progress.max))
                    .font(.footnote)
                    .foregroundStyle(.inkMuted)
            }
        }
        .padding(.vertical, Spacing.s2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(progress.macro.name)
        .accessibilityValue(NutritionFormat.spokenTarget(value: progress.value, min: progress.min, max: progress.max, unit: .grams))
    }
}

#Preview("Light") {
    TrendsView().environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.skipOnboarding]))
}

#Preview("Dark") {
    TrendsView().environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.skipOnboarding]))
        .preferredColorScheme(.dark)
}

#Preview("AX5") {
    TrendsView().environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.skipOnboarding]))
        .environment(\.dynamicTypeSize, .accessibility5)
}
