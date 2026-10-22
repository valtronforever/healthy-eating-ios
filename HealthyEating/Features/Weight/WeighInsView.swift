import SwiftUI

/// Every weigh-in of the last 90 days, newest first: tap to correct, swipe to delete, + to add
/// one (ios#41). Plain values; no arrows or colors for up or down.
struct WeighInsView: View {
    let unit: WeightUnit
    var onChange: () -> Void = {}

    @Environment(AppModel.self) private var app
    @State private var state: Loadable<[WeighIn]> = .loading
    @State private var editing: WeighIn?
    @State private var adding = false

    var body: some View {
        List {
            switch state {
            case .loading:
                LoadingCards().plainListRow()
            case .failed(let error):
                ServerErrorMessage(error: error, host: app.server?.host) { Task { await reload() } }
                    .padding(.top, Spacing.s6)
                    .plainListRow()
            case .loaded(let entries) where entries.isEmpty:
                Text("No weigh-ins yet. Tell your assistant your weight, or add one here.")
                    .foregroundStyle(.inkMuted)
                    .plainListRow()
            case .loaded(let entries):
                Section {
                    ForEach(entries) { entry in
                        Button { editing = entry } label: { row(entry) }
                            .swipeActions {
                                Button("Delete", role: .destructive) { Task { await delete(entry) } }
                            }
                    }
                }
                .listRowBackground(Color.surface)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.bg)
        .navigationTitle("Weigh-ins")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { adding = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add weigh-in")
                    .accessibilityIdentifier("addWeighIn")
            }
        }
        .sheet(isPresented: $adding) {
            WeighInForm(unit: unit) { changed() }
        }
        .sheet(item: $editing) { entry in
            WeighInForm(entry: entry, unit: unit) { changed() }
        }
        .refreshable { await reload() }
        .task { await reload() }
    }

    private func row(_ entry: WeighIn) -> some View {
        LabeledContent {
            Text(verbatim: WeightFormat.value(entry.weightKg, unit: unit))
                .fontDesign(.rounded)
                .monospacedDigit()
                .foregroundStyle(.ink)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.measuredAt.formatted(date: .abbreviated, time: .shortened)).foregroundStyle(.ink)
                Text(verbatim: WeightFormat.source(entry.source)).font(.subheadline).foregroundStyle(.inkMuted)
            }
        }
    }

    private func changed() {
        onChange()
        Task { await reload() }
    }

    private func reload() async {
        guard let data = app.data else { return }
        let today = Calendar.current.startOfDay(for: .now)
        let first = Calendar.current.date(byAdding: .day, value: -89, to: today) ?? today
        do throws(APIError) {
            state = .loaded(try await data.weights(from: first, to: today).entries.reversed())
        } catch {
            if state.value == nil { state = .failed(error) }
            app.handle(error)
        }
    }

    private func delete(_ entry: WeighIn) async {
        guard let data = app.data else { return }
        do throws(APIError) {
            try await data.deleteWeight(entry.id)
        } catch .notFound {
        } catch {
            app.handle(error)
        }
        changed()
    }
}

/// Weight display: the person's unit with one decimal, and where a weigh-in came from.
nonisolated enum WeightFormat {
    static func value(_ kg: Double, unit: WeightUnit, locale: Locale = .current) -> String {
        "\(unit.amount(fromKg: kg).formatted(.number.precision(.fractionLength(1)).locale(locale))) \(unit.symbol)"
    }

    /// "−0.3 kg per week over the last 4 weeks"; a change under 0.05 per week reads as stable.
    static func weeklyChange(_ kgPerWeek: Double, days: Int, unit: WeightUnit, locale: Locale = .current) -> String {
        let weeks = max(1, Int((Double(days) / 7).rounded()))
        let amount = unit.amount(fromKg: kgPerWeek)
        guard abs(amount) >= 0.05 else {
            return weeks == 1 ? String(localized: "About the same over the last week")
                : String(localized: "About the same over the last \(weeks) weeks")
        }
        let number = amount.formatted(.number.precision(.fractionLength(1)).sign(strategy: .always()).locale(locale))
            .replacingOccurrences(of: "-", with: "−")
        return weeks == 1 ? String(localized: "\(number) \(unit.symbol) per week over the last week")
            : String(localized: "\(number) \(unit.symbol) per week over the last \(weeks) weeks")
    }

    static func source(_ source: WeightSource) -> String {
        switch source {
        case .app: String(localized: "Added in the app")
        case .assistant: String(localized: "From your assistant")
        case .appleHealth: String(localized: "From Apple Health")
        }
    }
}

#Preview("Light") {
    NavigationStack { WeighInsView(unit: .kg) }
        .environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.skipOnboarding]))
}

#Preview("Dark") {
    NavigationStack { WeighInsView(unit: .kg) }
        .environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.skipOnboarding]))
        .preferredColorScheme(.dark)
}

#Preview("AX5") {
    NavigationStack { WeighInsView(unit: .lb) }
        .environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.skipOnboarding]))
        .environment(\.dynamicTypeSize, .accessibility5)
}
