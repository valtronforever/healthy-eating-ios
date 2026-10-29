import Accessibility
import Charts
import SwiftUI

/// Loads one vitamin's or mineral's insights for a period.
@MainActor
@Observable
final class NutrientInsightsModel {
    private(set) var state: Loadable<NutrientInsights> = .loading

    func load(_ nutrient: Micronutrient, period: InsightsPeriod, _ data: any NutritionDataSource, today: Date = .now) async -> APIError? {
        let days = period.days(today: today)
        do {
            state = .loaded(try await data.nutrientInsights(nutrient, from: days.first, to: days.last))
            return nil
        } catch {
            state = .failed(error)
            return error
        }
    }
}

/// One vitamin or mineral over 4 weeks, 12 weeks or a year (ios#46, backend #36), opened from
/// the Vitamins and minerals list: the average and the period before, weekly averages over the
/// range as a neutral band, the days below, within and above the range (all alike), where the
/// amounts came from, and how many meals have values. Facts only, never advice or judgment;
/// Calm mode changes nothing here, since nothing here is calories.
struct NutrientInsightsView: View {
    let nutrient: Micronutrient

    @Environment(AppModel.self) private var app
    @State private var model = NutrientInsightsModel()
    @State private var period: InsightsPeriod = .fourWeeks

    var body: some View {
        List {
            Picker("Period", selection: $period) {
                ForEach(InsightsPeriod.allCases) { Text(verbatim: $0.name).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("insightsPeriod")
            .plainListRow()
            switch model.state {
            case .loading:
                LoadingCards().plainListRow()
            case .failed(let error):
                ServerErrorMessage(error: error, host: app.server?.host) { Task { await reload() } }
                    .padding(.top, Spacing.s6)
                    .plainListRow()
            case .loaded(let insights):
                content(insights)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.bg)
        .navigationTitle(Text(verbatim: nutrient.name))
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("nutrientInsights")
        .refreshable { await reload() }
        .task(id: period) { await reload() }
    }

    private func reload() async {
        guard let data = app.data else { return }
        if let error = await model.load(nutrient, period: period, data) { app.handle(error) }
    }

    @ViewBuilder
    private func content(_ insights: NutrientInsights) -> some View {
        let current = insights.current
        averageSection(insights)
        if current.hasValues {
            if !current.weeks.isEmpty {
                Section {
                    WeeklyNutrientChart(nutrient: nutrient, weeks: current.weeks, range: insights.range)
                        .padding(.vertical, Spacing.s2)
                } header: {
                    Text("Week by week").sectionTextStyle()
                }
                .listRowBackground(Color.surface)
            }
            if let rangeDays = current.rangeDays, let range = insights.range, rangeDays.total > 0 {
                rangeSection(rangeDays, range)
            }
            sourcesSection("Foods", current.foodSources, footer: Text("From USDA FoodData Central for each food's weight. Shares are of all the \(nutrient.name) your items had in these weeks."))
            sourcesSection("Supplements and labels", current.labelSources, footer: Text("Items with values from their label, as your assistant saved them."))
            weeksSection(current.weeks)
        }
        Section {
            EmptyView()
        } footer: {
            Text(verbatim: Self.coverageLine(current)).sectionTextStyle()
        }
    }

    private func averageSection(_ insights: NutrientInsights) -> some View {
        Section {
            VStack(alignment: .leading, spacing: Spacing.s2) {
                if let average = insights.current.average {
                    Text(verbatim: Self.perDay(average.average, nutrient.unit))
                        .metricFont(.regular)
                        .foregroundStyle(.ink)
                    Text(verbatim: OptionalAveragesCard.daysLine(average, countedDays: insights.current.countedDays))
                        .font(.subheadline)
                        .foregroundStyle(.inkMuted)
                } else {
                    Text("No values in these weeks")
                        .font(.headline)
                        .foregroundStyle(.ink)
                    Text("Values come from the food items your assistant lists with each meal.")
                        .font(.subheadline)
                        .foregroundStyle(.inkMuted)
                }
                Text(verbatim: Self.previousLine(insights.previous, period: period, nutrient.unit))
                    .font(.subheadline)
                    .foregroundStyle(.inkMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("insightsAverage")
        }
        .listRowBackground(Color.surface)
    }

    private func rangeSection(_ days: NutrientInsights.RangeDays, _ range: MicronutrientRange) -> some View {
        Section {
            ForEach(Self.rangeRows(days, range), id: \.label) { row in
                LabeledContent {
                    Text(verbatim: row.value).foregroundStyle(.inkMuted)
                } label: {
                    Text(verbatim: row.label).foregroundStyle(.ink)
                }
            }
        } header: {
            Text(verbatim: NutritionFormat.range(range, nutrient.unit)).sectionTextStyle()
        } footer: {
            Text("Days on which every meal has values.").sectionTextStyle()
        }
        .listRowBackground(Color.surface)
    }

    @ViewBuilder
    private func sourcesSection(_ title: LocalizedStringKey, _ sources: [NutrientInsights.Source], footer: Text) -> some View {
        if !sources.isEmpty {
            Section {
                ForEach(sources) { source in
                    LabeledContent {
                        Text(verbatim: Self.share(source.share)).metricFont(.small).foregroundStyle(.ink)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: source.name).foregroundStyle(.ink)
                            Text(verbatim: Self.sourceLine(source, nutrient.unit))
                                .font(.footnote)
                                .foregroundStyle(.inkMuted)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            } header: {
                Text(title).sectionTextStyle()
            } footer: {
                footer.sectionTextStyle()
            }
            .listRowBackground(Color.surface)
        }
    }

    private func weeksSection(_ weeks: [NutrientInsights.Week]) -> some View {
        Section {
            ForEach(weeks.reversed()) { week in
                LabeledContent {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(verbatim: week.average.map { Self.perDay($0, nutrient.unit) } ?? String(localized: "No values"))
                            .foregroundStyle(week.average == nil ? .inkMuted : .ink)
                        Text(verbatim: Self.weekDaysLine(week))
                            .font(.footnote)
                            .foregroundStyle(.inkMuted)
                    }
                } label: {
                    Text(verbatim: WeeklyReviewView.weekTitle(first: week.firstDay, last: week.lastDay)).foregroundStyle(.ink)
                }
                .accessibilityElement(children: .combine)
            }
        } header: {
            Text("Weeks").sectionTextStyle()
        }
        .listRowBackground(Color.surface)
    }

    // MARK: Wording (unit tested)

    /// "11.6 mg a day".
    nonisolated static func perDay(_ amount: Double, _ unit: NutrientUnit, locale: Locale = .current) -> String {
        String(localized: "\(NutritionFormat.micronutrient(amount, unit, locale: locale)) a day")
    }

    /// "Previous 4 weeks: 9.8 mg a day" or "Previous 4 weeks: no values". A plain fact: the
    /// change is neither progress nor a setback.
    nonisolated static func previousLine(_ previous: NutrientInsights.Period, period: InsightsPeriod, _ unit: NutrientUnit, locale: Locale = .current) -> String {
        let name: String = switch period {
        case .fourWeeks: String(localized: "Previous 4 weeks")
        case .twelveWeeks: String(localized: "Previous 12 weeks")
        case .year: String(localized: "Previous year")
        }
        guard let average = previous.average else { return String(localized: "\(name): no values") }
        return String(localized: "\(name): \(perDay(average.average, unit, locale: locale))")
    }

    nonisolated struct RangeRow: Equatable, Sendable {
        var label: String
        var value: String
    }

    /// Within, and below or above where the range has that bound, all in the same words.
    nonisolated static func rangeRows(_ days: NutrientInsights.RangeDays, _ range: MicronutrientRange) -> [RangeRow] {
        let total = days.total
        let value = { (count: Int) in String(localized: "\(count) of \(total) days") }
        var rows: [RangeRow] = []
        if range.min != nil { rows.append(RangeRow(label: String(localized: "Below the range"), value: value(days.below))) }
        rows.append(RangeRow(label: String(localized: "Within the range"), value: value(days.within)))
        if range.max != nil { rows.append(RangeRow(label: String(localized: "Above the range"), value: value(days.above))) }
        return rows
    }

    /// "34%".
    nonisolated static func share(_ share: Double, locale: Locale = .current) -> String {
        share.formatted(.percent.precision(.fractionLength(0)).locale(locale))
    }

    /// "4.4 mg in 5 meals".
    nonisolated static func sourceLine(_ source: NutrientInsights.Source, _ unit: NutrientUnit, locale: Locale = .current) -> String {
        let amount = NutritionFormat.micronutrient(source.amount, unit, locale: locale)
        return source.meals == 1 ? String(localized: "\(amount) in 1 meal") : String(localized: "\(amount) in \(source.meals) meals")
    }

    /// The days of a week that could count: up to today.
    nonisolated static func possibleDays(_ week: NutrientInsights.Week, today: Date = .now, calendar: Calendar = .current) -> Int {
        let last = min(week.lastDay, calendar.startOfDay(for: today))
        return max(0, (calendar.dateComponents([.day], from: week.firstDay, to: last).day ?? 0) + 1)
    }

    /// "3 of 7 days".
    nonisolated static func weekDaysLine(_ week: NutrientInsights.Week, today: Date = .now, calendar: Calendar = .current) -> String {
        String(localized: "\(week.days) of \(possibleDays(week, today: today, calendar: calendar)) days")
    }

    /// A week whose average uses fewer than half of its days is drawn lighter.
    nonisolated static func isSparse(_ week: NutrientInsights.Week, today: Date = .now, calendar: Calendar = .current) -> Bool {
        week.days * 2 < possibleDays(week, today: today, calendar: calendar)
    }

    /// "Values for 34 of 52 meals. Meals without food items have no vitamin or mineral values."
    nonisolated static func coverageLine(_ period: NutrientInsights.Period) -> String {
        guard period.mealCount > 0 else { return String(localized: "No meals in these weeks.") }
        return String(localized: "Values for \(period.mealsWithValues) of \(period.mealCount) meals.") + " "
            + String(localized: "Meals without food items have no vitamin or mineral values.")
    }
}

/// Weekly averages as bars over the range band. A week whose average uses fewer than half its
/// days is a lighter bar; a week without values is a dot on the baseline. Bars above the band
/// look exactly like bars below it.
struct WeeklyNutrientChart: View {
    let nutrient: Micronutrient
    let weeks: [NutrientInsights.Week]
    let range: MicronutrientRange?

    @ScaledMetric(relativeTo: .body) private var chartHeight: CGFloat = 170

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            chart
                .frame(height: min(chartHeight, 260))
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            legend
        }
    }

    /// Room above the largest bar, and above the range's start; a high upper bound (vitamin C's
    /// 2000 mg) runs off the top instead of flattening the bars.
    nonisolated static func scaleMax(_ weeks: [NutrientInsights.Week], range: MicronutrientRange?) -> Double {
        let largest = max(weeks.compactMap(\.average).max() ?? 0, range?.min ?? 0)
        return largest > 0 ? largest * 1.25 : 1
    }

    private var scaleMax: Double { Self.scaleMax(weeks, range: range) }
    private var barHalfWidth: Double { weeks.count > 20 ? 0.36 : 0.3 }

    private var chart: some View {
        Chart {
            if let range, range.min != nil || range.max != nil {
                RectangleMark(
                    xStart: .value("Start", -0.5), xEnd: .value("End", Double(weeks.count) - 0.5),
                    yStart: .value("Range low", range.min ?? 0), yEnd: .value("Range high", Swift.min(range.max ?? scaleMax, scaleMax)))
                    .foregroundStyle(Color.band)
                if let low = range.min {
                    RuleMark(y: .value("Range low", low))
                        .foregroundStyle(Color.accent)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                }
                if let high = range.max, high <= scaleMax {
                    RuleMark(y: .value("Range high", high))
                        .foregroundStyle(Color.accent)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                }
            }
            RuleMark(y: .value("Baseline", 0))
                .foregroundStyle(Color.lineStrong)
                .lineStyle(StrokeStyle(lineWidth: 1))
            ForEach(Array(weeks.enumerated()), id: \.element.id) { index, week in
                if let average = week.average {
                    RectangleMark(
                        xStart: .value("Start", Double(index) - barHalfWidth),
                        xEnd: .value("End", Double(index) + barHalfWidth),
                        yStart: .value("Zero", 0), yEnd: .value("Average", average))
                        .foregroundStyle(NutrientInsightsView.isSparse(week) ? Color.chartFaded : Color.ink)
                        .cornerRadius(Radius.xs, style: .continuous)
                } else {
                    PointMark(x: .value("Week", Double(index)), y: .value("Average", 0))
                        .symbolSize(14)
                        .foregroundStyle(Color.lineStrong)
                        .offset(y: -5)
                }
            }
        }
        .chartXScale(domain: -0.5...(Double(weeks.count) - 0.5))
        .chartYScale(domain: 0...scaleMax)
        .chartXAxis {
            AxisMarks(values: labeledIndices) { value in
                AxisValueLabel(centered: false) {
                    if let index = value.as(Double.self).map({ Int($0.rounded()) }), weeks.indices.contains(index) {
                        Text(weeks[index].firstDay.formatted(.dateTime.month(.abbreviated).day()))
                            .font(.caption2)
                            .foregroundStyle(.inkMuted)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                AxisValueLabel {
                    if let amount = value.as(Double.self) {
                        Text(NutritionFormat.micronutrient(amount, nutrient.unit).replacingOccurrences(of: " \(nutrient.unit.symbol)", with: ""))
                            .font(.caption2)
                            .foregroundStyle(.inkMuted)
                    }
                }
            }
        }
        .accessibilityChartDescriptor(NutrientChartDescriptor(nutrient: nutrient, weeks: weeks, range: range, scaleMax: scaleMax))
    }

    private var labeledIndices: [Double] {
        let step = weeks.count <= 6 ? 1 : weeks.count <= 14 ? 3 : 13
        return weeks.indices.filter { $0 % step == 0 }.map(Double.init)
    }

    private var legend: some View {
        FlowLayout(horizontalSpacing: Spacing.s3) {
            LegendItem(title: Text("Week average")) {
                RoundedRectangle(cornerRadius: 2, style: .continuous).fill(Color.ink)
            }
            LegendItem(title: Text("Fewer than half the days")) {
                RoundedRectangle(cornerRadius: 2, style: .continuous).fill(Color.chartFaded)
            }
            if let range, range.min != nil || range.max != nil {
                LegendItem(title: Text(verbatim: NutritionFormat.range(range, nutrient.unit))) {
                    Rectangle().fill(Color.band)
                        .overlay(alignment: .top) { Rectangle().fill(Color.accent).frame(height: 1.5) }
                        .overlay(alignment: .bottom) { Rectangle().fill(Color.accent).frame(height: 1.5) }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Audio graph and VoiceOver description of the weekly chart.
nonisolated struct NutrientChartDescriptor: AXChartDescriptorRepresentable {
    let nutrient: Micronutrient
    let weeks: [NutrientInsights.Week]
    let range: MicronutrientRange?
    let scaleMax: Double

    func makeChartDescriptor() -> AXChartDescriptor {
        let names = weeks.map { String(localized: "Week of \($0.firstDay.formatted(.dateTime.month(.wide).day()))") }
        let xAxis = AXCategoricalDataAxisDescriptor(title: String(localized: "Week"), categoryOrder: names)
        let yAxis = AXNumericDataAxisDescriptor(
            title: nutrient.name, range: 0...scaleMax, gridlinePositions: [range?.min, range?.max].compactMap { $0 }
        ) { nutrient.unit.spokenValue(NutritionFormat.micronutrient($0, nutrient.unit).replacingOccurrences(of: " \(nutrient.unit.symbol)", with: "")) }
        let points = zip(weeks, names).map { week, name in
            AXDataPoint(x: name, y: week.average ?? 0, label: week.average == nil ? String(localized: "no values") : NutrientInsightsView.weekDaysLine(week))
        }
        let summary = range.map { NutritionFormat.range($0, nutrient.unit) + "." } ?? ""
        return AXChartDescriptor(
            title: String(localized: "\(nutrient.name) per day, week by week"), summary: summary, xAxis: xAxis, yAxis: yAxis,
            additionalAxes: [],
            series: [AXDataSeriesDescriptor(name: nutrient.name, isContinuous: false, dataPoints: points)])
    }
}

#Preview("Light") {
    NavigationStack { NutrientInsightsView(nutrient: .iron) }
        .environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.skipOnboarding]))
}

#Preview("Dark") {
    NavigationStack { NutrientInsightsView(nutrient: .vitaminC) }
        .environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.skipOnboarding]))
        .preferredColorScheme(.dark)
}

#Preview("AX5") {
    NavigationStack { NutrientInsightsView(nutrient: .iron) }
        .environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.skipOnboarding]))
        .environment(\.dynamicTypeSize, .accessibility5)
}
