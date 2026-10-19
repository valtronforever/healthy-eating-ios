import SwiftUI

/// D1 Trends: average calories per day over 7, 30 or 90 days, macro averages against their
/// ranges, comparisons worded as lower or higher, and the days-counted line.
/// Uses sample data until the backend serves statistics.
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

    @Environment(AppModel.self) private var model
    @State private var period: Period = .month

    var body: some View {
        let trend = SampleData.trend(days: period.rawValue)
        NavigationStack {
            List {
                Section {
                    Picker("Period", selection: $period) {
                        ForEach(Period.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .plainListRow()

                    if !model.calmMode {
                        VStack(alignment: .leading, spacing: Spacing.s2) {
                            Text("Average per day")
                                .font(.subheadline)
                                .foregroundStyle(.inkMuted)
                            HStack(alignment: .firstTextBaseline, spacing: Spacing.s2) {
                                Text(NutritionFormat.number(trend.averageKcal))
                                    .metricFont(.regular)
                                    .foregroundStyle(.ink)
                                Text(NutrientUnit.kcal.symbol)
                                    .font(.subheadline)
                                    .foregroundStyle(.inkMuted)
                            }
                            .accessibilityElement(children: .combine)
                            KcalBarChart(days: trend.days, target: SampleData.kcalTarget, average: trend.averageKcal,
                                         title: String(localized: "Calories per day, last \(period.rawValue) days"))
                        }
                        .cardStyle()
                        .plainListRow()
                    }

                    VStack(spacing: 0) {
                        ForEach(trend.macroAverages) { progress in
                            MacroAverageLine(progress: progress)
                        }
                    }
                    .cardStyle(padding: Spacing.s4)
                    .plainListRow()
                }
                .listSectionSpacing(Spacing.s4)

                Section {
                    ForEach(trend.comparisons.filter { !model.calmMode || $0.label != String(localized: "Calories") }, id: \.label) { item in
                        LabeledContent {
                            Text(verbatim: item.value).foregroundStyle(.inkMuted)
                        } label: {
                            Text(verbatim: item.label).foregroundStyle(.ink)
                        }
                    }
                } header: {
                    Text("Compared with the previous \(period.rawValue) days").sectionTextStyle()
                } footer: {
                    let left = period.rawValue - trend.completeDays
                    Text("Averages use \(trend.completeDays) of \(period.rawValue) days (\(left) partial or not logged days left out).")
                        .sectionTextStyle()
                }
                .listRowBackground(Color.surface)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.bg)
            .navigationTitle("Trends")
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
                Text(NutritionFormat.range(progress.min, progress.max))
                    .font(.footnote)
                    .foregroundStyle(.inkMuted)
            }
        }
        .padding(.vertical, Spacing.s2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(progress.macro.name)
        .accessibilityValue(NutritionFormat.spokenRange(value: progress.value, min: progress.min, max: progress.max, unit: .grams))
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
