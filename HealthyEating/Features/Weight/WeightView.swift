import SwiftUI

/// Loads D3: settings, the last 28 days of weigh-ins with the trend, and the energy estimate.
@MainActor
@Observable
final class WeightModel {
    struct Snapshot {
        var settings: UserSettings
        var history: WeightHistory
        var estimate: EnergyEstimate?
    }

    static let days = 28

    private(set) var state: Loadable<Snapshot> = .loading

    func load(_ data: any NutritionDataSource, calendar: Calendar = .current) async -> APIError? {
        let today = calendar.startOfDay(for: .now)
        let first = calendar.date(byAdding: .day, value: -(Self.days - 1), to: today) ?? today
        do {
            let settings = try await data.settings()
            guard settings.weightTracking else {
                state = .loaded(Snapshot(
                    settings: settings,
                    history: WeightHistory(firstDay: first, lastDay: today, entries: [], trend: []),
                    estimate: nil))
                return nil
            }
            async let history = data.weights(from: first, to: today)
            async let estimate = data.energyEstimate()
            state = .loaded(Snapshot(settings: settings, history: try await history, estimate: try await estimate))
            return nil
        } catch {
            let apiError = error as? APIError ?? .unexpectedResponse(String(describing: error))
            if state.value == nil { state = .failed(apiError) }
            return apiError
        }
    }
}

/// D3 Weight and energy (ios#33): opt-in. Off: what it is and "Turn on". On: the smoothed trend
/// with weigh-ins faded, "you maintain at about X kcal" with its confidence (hidden in Calm mode),
/// weigh-ins and the controls. No celebration or warning about any change.
struct WeightView: View {
    /// Called after the setting or the weigh-ins changed, so Trends can refresh its row.
    var onChange: () -> Void = {}

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var model = WeightModel()
    @State private var adding = false
    @State private var showingMethod = false
    @State private var deletingAll = false

    var body: some View {
        Group {
            switch model.state {
            case .loading:
                List { LoadingCards().plainListRow() }
            case .failed(let error):
                List {
                    ServerErrorMessage(error: error, host: app.server?.host) { Task { await reload() } }
                        .padding(.top, Spacing.s6)
                        .plainListRow()
                }
            case .loaded(let snapshot):
                if snapshot.settings.weightTracking {
                    on(snapshot)
                } else {
                    off
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.bg)
        .navigationTitle(model.state.value?.settings.weightTracking == true ? "Weight and energy" : "")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await reload() }
        .task { await reload() }
    }

    private func reload() async {
        guard let data = app.data else { return }
        // Sync with Apple Health first, so pulling to refresh shows new weigh-ins.
        await app.syncAppleHealth()
        if let error = await model.load(data) { app.handle(error) }
    }

    private func setTracking(_ on: Bool) async {
        guard let data = app.data else { return }
        do throws(APIError) {
            _ = try await data.updateSettings(.init(weightTracking: on))
        } catch {
            app.handle(error)
        }
        onChange()
        await reload()
    }

    // MARK: Off (D3 off)

    private var off: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s5) {
                WeightTrendChart(points: SampleData.weightPoints, yRange: 77.5...80, showsAxes: false)
                    .accessibilityHidden(true)
                    .cardStyle()
                Text("Optional: weight and energy")
                    .font(.title2Bold)
                    .foregroundStyle(.ink)
                Text("Healthy Eating can smooth your weigh-ins into a trend and estimate how many calories you maintain at, using your own log.")
                    .foregroundStyle(.inkMuted)
                VStack(alignment: .leading, spacing: Spacing.s4) {
                    point("eye.slash", "Off by default. Your first weigh-in turns it on.")
                    point("heart.text.square", "Weight comes from your chat, Apple Health or manual entry.")
                    point("lock.shield", "Stored only on your server. Hide it or delete all weight data at any time.")
                }
                VStack(spacing: Spacing.s3) {
                    Button("Turn on") { Task { await setTracking(true) } }
                        .buttonStyle(.action(.secondary))
                        .accessibilityIdentifier("turnOnWeight")
                    Button("Not now") { dismiss() }
                        .buttonStyle(.action(.plain))
                }
                .padding(.top, Spacing.s4)
            }
            .padding(Spacing.s4)
        }
    }

    private func point(_ symbol: String, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: Spacing.s3) {
            SymbolTile(systemName: symbol, small: true)
            Text(text).foregroundStyle(.ink)
        }
    }

    // MARK: On (D3 on)

    private func on(_ snapshot: WeightModel.Snapshot) -> some View {
        let unit = snapshot.settings.weightUnit
        return List {
            VStack(spacing: Spacing.s4) {
                trendCard(snapshot.history, unit: unit)
                if !app.calmMode, let estimate = snapshot.estimate {
                    energyCard(estimate, unit: snapshot.settings.energyUnit)
                }
            }
            .plainListRow()
            Section {
                NavigationLink {
                    WeighInsView(unit: unit) { Task { await reload() } }
                } label: {
                    Text("Weigh-ins").foregroundStyle(.ink)
                }
                .accessibilityIdentifier("weighIns")
                Button("Add weigh-in") { adding = true }
                    .accessibilityIdentifier("addWeighIn")
                AppleHealthSyncToggle { Task { await reload() } }
                Toggle("Show on Trends", isOn: Binding(
                    get: { snapshot.settings.weightTracking },
                    set: { on in Task { await setTracking(on) } }))
                Button("Delete all weight data") { deletingAll = true }
                    .foregroundStyle(.destructive)
            } footer: {
                Text("Weight stays on your server. Turning this off hides it; deleting removes every weigh-in.")
                    .sectionTextStyle()
            }
            .listRowBackground(Color.surface)
        }
        .sheet(isPresented: $adding) {
            WeighInForm(unit: unit) { Task { await reload() } }
        }
        .sheet(isPresented: $showingMethod) { methodSheet }
        .confirmationDialog("Delete all weight data?", isPresented: $deletingAll, titleVisibility: .visible) {
            Button("Delete all weight data", role: .destructive) { Task { await deleteAll() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Every weigh-in is removed from your server. This can’t be undone.")
        }
    }

    private func deleteAll() async {
        guard let data = app.data else { return }
        do throws(APIError) {
            _ = try await data.deleteAllWeights()
        } catch {
            app.handle(error)
        }
        onChange()
        await reload()
    }

    private func trendCard(_ history: WeightHistory, unit: WeightUnit) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s1) {
            if let latest = history.latestTrendKg {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.s2) {
                    Text(unit.amount(fromKg: latest), format: .number.precision(.fractionLength(1)))
                        .metricFont(.regular)
                        .foregroundStyle(.ink)
                    Text(verbatim: String(localized: "\(unit.symbol) trend"))
                        .font(.subheadline)
                        .foregroundStyle(.inkMuted)
                }
                .accessibilityElement(children: .combine)
                if let change = history.weeklyChangeKg, let days = history.changeDays {
                    Text(verbatim: WeightFormat.weeklyChange(change, days: days, unit: unit))
                        .font(.subheadline)
                        .foregroundStyle(.inkMuted)
                }
                let chart = Self.chart(history, unit: unit)
                WeightTrendChart(
                    points: chart.points, yRange: chart.range, yStep: chart.step, xLabels: chart.labels,
                    lastIndex: chart.lastIndex, unit: unit)
                    .padding(.top, Spacing.s2)
            } else {
                Text("No weigh-ins in the last 4 weeks")
                    .font(.headline)
                    .foregroundStyle(.ink)
                Text("Tell your assistant your weight, or add a weigh-in below.")
                    .foregroundStyle(.inkMuted)
            }
        }
        .cardStyle()
    }

    private func energyCard(_ estimate: EnergyEstimate, unit: EnergyUnit) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            Text("Energy estimate").font(.subheadline).foregroundStyle(.inkMuted)
            if let kcal = estimate.maintenanceKcal {
                Text(Self.maintainLine(kcal: kcal, unit: unit))
                    .foregroundStyle(.ink)
                FlowLayout(horizontalSpacing: Spacing.s3) {
                    if let confidence = estimate.confidence {
                        ConfidenceIndicator(level: confidence)
                    }
                    Text(verbatim: Self.basisLine(estimate))
                        .font(.footnote)
                        .foregroundStyle(.inkMuted)
                }
            } else {
                Text(verbatim: Self.missingLine(estimate))
                    .foregroundStyle(.ink)
            }
            Button { showingMethod = true } label: {
                Label("How this is calculated", systemImage: "info.circle")
            }
            .foregroundStyle(.accent)
            .buttonStyle(.borderless)
        }
        .cardStyle()
    }

    private var methodSheet: some View {
        NavigationStack {
            ScrollView {
                Text("""
                Healthy Eating compares what you logged with what your weight did over the last 4 weeks.

                It takes the average calories of the days that count for your averages, and the change of your smoothed weight trend over the same weeks. About 7,700 kcal match one kilogram of body weight. If the trend went down, you used more than you logged; if it went up, less.

                Because it uses your own log, a steady over- or underestimate in it is part of both sides, so the result fits your log. It needs at least 14 logged days and weigh-ins on 6 days spread over 2 weeks. More days and more weigh-ins give a higher confidence.

                The trend smooths day-to-day changes in weight, which come mostly from water and food, not from body tissue.
                """)
                .foregroundStyle(.ink)
                .padding(Spacing.s4)
            }
            .background(Color.bg)
            .navigationTitle("How this is calculated")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { showingMethod = false } }
            }
        }
    }

    // MARK: Wording and chart data

    /// "Based on your log and weight, you maintain at about **2,350 kcal** per day."
    static func maintainLine(kcal: Double, unit: EnergyUnit) -> AttributedString {
        let amount = NutritionFormat.energy(kcal, in: unit)
        var text = AttributedString(localized: "Based on your log and weight, you maintain at about \(amount) per day.")
        if let range = text.range(of: amount) {
            text[range].inlinePresentationIntent = .stronglyEmphasized
        }
        return text
    }

    nonisolated static func basisLine(_ estimate: EnergyEstimate) -> String {
        String(localized: "\(estimate.countedDays) days of log, \(estimate.weighIns) weigh-ins")
    }

    nonisolated static func missingLine(_ estimate: EnergyEstimate) -> String {
        switch estimate.missing {
        case .loggedDays:
            String(localized: "Not enough logged days yet: the estimate needs 14 in the last 4 weeks (now \(estimate.countedDays)).")
        case .weighIns, nil:
            String(localized: "Not enough weigh-ins yet: the estimate needs weigh-ins on 6 days spread over 2 weeks.")
        }
    }

    nonisolated struct ChartData {
        var points: [WeightPoint]
        var range: ClosedRange<Double>
        var step: Double
        var labels: [Int: String]
        var lastIndex: Int
    }

    /// Chart points by day index over the 28 days, in the person's unit, with a padded range.
    nonisolated static func chart(_ history: WeightHistory, unit: WeightUnit, calendar: Calendar = .current) -> ChartData {
        let points = history.trend.map { day in
            WeightPoint(
                index: max(0, calendar.dateComponents([.day], from: history.firstDay, to: day.date).day ?? 0),
                raw: unit.amount(fromKg: day.weightKg), trend: unit.amount(fromKg: day.trendKg))
        }
        let values = points.flatMap { [$0.trend] + ($0.raw.map { [$0] } ?? []) }
        let low = (values.min() ?? 0), high = (values.max() ?? 1)
        let step: Double = high - low > 6 ? 2 : (unit == .lb ? 2 : 1)
        let range = ((low - 0.2) / step).rounded(.down) * step...((high + 0.2) / step).rounded(.up) * step
        let lastIndex = max(calendar.dateComponents([.day], from: history.firstDay, to: history.lastDay).day ?? 27, 1)
        let format = Date.FormatStyle().month(.abbreviated).day()
        var labels: [Int: String] = [:]
        for index in [0, lastIndex / 2, lastIndex] {
            if let date = calendar.date(byAdding: .day, value: index, to: history.firstDay) {
                labels[index] = date.formatted(format)
            }
        }
        return ChartData(points: points, range: range, step: step, labels: labels, lastIndex: lastIndex)
    }
}

#Preview("Light") {
    NavigationStack { WeightView() }
        .environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.skipOnboarding]))
}

#Preview("Dark") {
    NavigationStack { WeightView() }
        .environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.skipOnboarding]))
        .preferredColorScheme(.dark)
}

#Preview("AX5") {
    NavigationStack { WeightView() }
        .environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.skipOnboarding]))
        .environment(\.dynamicTypeSize, .accessibility5)
}
