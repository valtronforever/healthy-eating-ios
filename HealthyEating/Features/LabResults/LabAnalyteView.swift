import Accessibility
import Charts
import SwiftUI

/// One analyte over time (ios#47): the latest value, the values over time with the lab's printed
/// range as a neutral band, and, where the analyte relates to a vitamin or mineral, its weekly
/// intake from logged meals in a separate chart below. Shown next to each other, never as a cause.
/// Every value, inside or outside the range, looks the same.
struct LabAnalyteView: View {
    let model: LabResultsModel
    let historyID: String

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var intake = NutrientInsightsModel()

    private var history: LabAnalyteHistory? { model.history(historyID) }

    var body: some View {
        List {
            if let history {
                latestSection(history)
                let series = LabChartSeries(history)
                if series.points.count > 1 {
                    chartSection(history, series)
                }
                if let nutrient = history.relatedNutrient {
                    intakeSection(nutrient, period: Self.intakePeriod(earliest: series.points.first?.date ?? history.latest.takenOn))
                }
                valuesSection(history)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.bg)
        .navigationTitle(Text(verbatim: history?.title ?? ""))
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("labAnalyte")
        .task(id: history?.relatedNutrient) { await loadIntake() }
        .onChange(of: history == nil) { _, gone in
            if gone { dismiss() }
        }
    }

    private func loadIntake() async {
        guard let data = app.data, let history, let nutrient = history.relatedNutrient else { return }
        let earliest = LabChartSeries(history).points.first?.date ?? history.latest.takenOn
        if let error = await intake.load(nutrient, period: Self.intakePeriod(earliest: earliest), data) { app.handle(error) }
    }

    private func latestSection(_ history: LabAnalyteHistory) -> some View {
        let latest = history.latest
        return Section {
            VStack(alignment: .leading, spacing: Spacing.s2) {
                Text(verbatim: LabFormat.value(latest.result))
                    .metricFont(.regular)
                    .foregroundStyle(.ink)
                Text(verbatim: LabFormat.day(latest.takenOn))
                    .font(.subheadline)
                    .foregroundStyle(.inkMuted)
                if let range = LabFormat.range(latest.result) {
                    Text(verbatim: range)
                        .font(.subheadline)
                        .foregroundStyle(.inkMuted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("labLatest")
        } header: {
            Text("Latest value").sectionTextStyle()
        }
        .listRowBackground(Color.surface)
    }

    private func chartSection(_ history: LabAnalyteHistory, _ series: LabChartSeries) -> some View {
        Section {
            LabValuesChart(title: history.title, series: series)
                .padding(.vertical, Spacing.s2)
                .accessibilityIdentifier("labChart")
        } header: {
            Text("Over time").sectionTextStyle()
        } footer: {
            if let note = Self.chartNote(series) {
                Text(verbatim: note).sectionTextStyle()
            }
        }
        .listRowBackground(Color.surface)
    }

    private func intakeSection(_ nutrient: Micronutrient, period: InsightsPeriod) -> some View {
        Section {
            switch intake.state {
            case .loading:
                ProgressView().frame(maxWidth: .infinity)
            case .failed:
                Text("The intake could not be loaded.").foregroundStyle(.inkMuted)
            case .loaded(let insights):
                if insights.current.weeks.contains(where: { $0.average != nil }) {
                    WeeklyNutrientChart(nutrient: nutrient, weeks: insights.current.weeks, range: insights.range)
                        .padding(.vertical, Spacing.s2)
                } else {
                    Text("No values from logged meals in these weeks.").foregroundStyle(.inkMuted)
                }
            }
            NavigationLink {
                NutrientInsightsView(nutrient: nutrient)
            } label: {
                Text("More about \(nutrient.name)").foregroundStyle(.ink)
            }
        } header: {
            Text("\(nutrient.name) intake from logged meals").sectionTextStyle()
        } footer: {
            Text(verbatim: Self.intakeNote(period)).sectionTextStyle()
        }
        .listRowBackground(Color.surface)
        .accessibilityIdentifier("labIntake")
    }

    private func valuesSection(_ history: LabAnalyteHistory) -> some View {
        Section {
            ForEach(history.entries) { entry in
                NavigationLink {
                    LabReportView(model: model, reportID: entry.reportID)
                } label: {
                    LabValueRow(
                        title: LabFormat.day(entry.takenOn), subtitle: LabFormat.range(entry.result),
                        value: LabFormat.value(entry.result))
                }
            }
        } header: {
            Text("All values").sectionTextStyle()
        } footer: {
            Text("Values, units and ranges as printed on your reports.").sectionTextStyle()
        }
        .listRowBackground(Color.surface)
    }

    // MARK: Wording (unit tested)

    /// 12 weeks when every charted value is that recent, else the last year.
    nonisolated static func intakePeriod(earliest: Date, today: Date = .now, calendar: Calendar = .current) -> InsightsPeriod {
        earliest >= InsightsPeriod.twelveWeeks.days(today: today, calendar: calendar).first ? .twelveWeeks : .year
    }

    nonisolated static func intakeNote(_ period: InsightsPeriod) -> String {
        switch period {
        case .year: String(localized: "Average per day, week by week, over the last year.")
        default: String(localized: "Average per day, week by week, over the last \(period.weeks) weeks.")
        }
    }

    /// Says when the chart shows converted values or leaves values out; nil otherwise.
    nonisolated static func chartNote(_ series: LabChartSeries) -> String? {
        var notes: [String] = []
        if series.converted, let unit = series.unit {
            notes.append(String(localized: "Shown in \(unit), converted from the units on your reports."))
        }
        if series.leftOut == 1 {
            notes.append(String(localized: "1 value in another unit is not in the chart."))
        } else if series.leftOut > 1 {
            notes.append(String(localized: "\(series.leftOut) values in other units are not in the chart."))
        }
        return notes.isEmpty ? nil : notes.joined(separator: " ")
    }
}

/// Lab values over time as points on a line, over the lab's range as a neutral band: one band
/// across the chart when every report printed the same range, else a band behind each value.
/// A value outside the range looks exactly like one inside it.
struct LabValuesChart: View {
    let title: String
    let series: LabChartSeries

    @ScaledMetric(relativeTo: .body) private var chartHeight: CGFloat = 170

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            chart
                .frame(height: min(chartHeight, 260))
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            legend
        }
    }

    /// Room above the largest value or bound.
    nonisolated static func scaleMax(_ series: LabChartSeries) -> Double {
        let largest = series.points.flatMap { [$0.value, $0.low ?? 0, $0.high ?? 0] }.max() ?? 0
        return largest > 0 ? largest * 1.15 : 1
    }

    /// The first and last day with some room on both sides (at least 10 days).
    nonisolated static func xDomain(_ series: LabChartSeries) -> ClosedRange<Date> {
        guard let first = series.points.first?.date, let last = series.points.last?.date else {
            return Date.now...Date.now.addingTimeInterval(86_400)
        }
        let pad = max(last.timeIntervalSince(first) * 0.08, 10 * 86_400)
        return first.addingTimeInterval(-pad)...last.addingTimeInterval(pad)
    }

    private var scaleMax: Double { Self.scaleMax(series) }
    private var xDomain: ClosedRange<Date> { Self.xDomain(series) }

    private var chart: some View {
        Chart {
            if let shared = series.sharedRange {
                RectangleMark(
                    xStart: .value("Start", xDomain.lowerBound), xEnd: .value("End", xDomain.upperBound),
                    yStart: .value("Range low", shared.low ?? 0), yEnd: .value("Range high", min(shared.high ?? scaleMax, scaleMax)))
                    .foregroundStyle(Color.band)
                ForEach([shared.low, shared.high].compactMap { $0 }, id: \.self) { bound in
                    RuleMark(y: .value("Range", bound))
                        .foregroundStyle(Color.accent)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                }
            } else {
                ForEach(series.points.filter { $0.low != nil || $0.high != nil }) { point in
                    RuleMark(
                        x: .value("Day", point.date),
                        yStart: .value("Range low", point.low ?? 0), yEnd: .value("Range high", min(point.high ?? scaleMax, scaleMax)))
                        .foregroundStyle(Color.band)
                        .lineStyle(StrokeStyle(lineWidth: 14))
                }
            }
            RuleMark(y: .value("Baseline", 0))
                .foregroundStyle(Color.lineStrong)
                .lineStyle(StrokeStyle(lineWidth: 1))
            ForEach(series.points) { point in
                LineMark(x: .value("Day", point.date), y: .value("Value", point.value))
                    .foregroundStyle(Color.inkMuted)
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                PointMark(x: .value("Day", point.date), y: .value("Value", point.value))
                    .foregroundStyle(Color.ink)
                    .symbolSize(44)
            }
        }
        .chartXScale(domain: xDomain)
        .chartYScale(domain: 0...scaleMax)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date.formatted(.dateTime.month(.abbreviated).year()))
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
                        Text(LabFormat.number(amount))
                            .font(.caption2)
                            .foregroundStyle(.inkMuted)
                    }
                }
            }
        }
        .accessibilityChartDescriptor(LabChartDescriptor(title: title, series: series, scaleMax: scaleMax))
    }

    private var legend: some View {
        FlowLayout(horizontalSpacing: Spacing.s3) {
            LegendItem(title: Text(verbatim: series.unit.map { String(localized: "Your values in \($0)") } ?? String(localized: "Your values"))) {
                Circle().fill(Color.ink)
            }
            if series.hasRange {
                LegendItem(title: Text("Lab range")) {
                    Rectangle().fill(Color.band)
                        .overlay(alignment: .top) { Rectangle().fill(Color.accent).frame(height: 1.5) }
                        .overlay(alignment: .bottom) { Rectangle().fill(Color.accent).frame(height: 1.5) }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Audio graph and VoiceOver description of the lab values chart.
nonisolated struct LabChartDescriptor: AXChartDescriptorRepresentable {
    let title: String
    let series: LabChartSeries
    let scaleMax: Double

    func makeChartDescriptor() -> AXChartDescriptor {
        let names = series.points.map { LabFormat.day($0.date) }
        let xAxis = AXCategoricalDataAxisDescriptor(title: String(localized: "Sample day"), categoryOrder: names)
        let yAxis = AXNumericDataAxisDescriptor(title: title, range: 0...scaleMax, gridlinePositions: []) {
            LabFormat.value($0, unit: series.unit)
        }
        let points = zip(series.points, names).map { point, name in
            AXDataPoint(
                x: name, y: point.value,
                label: [LabFormat.value(point.value, comparator: point.comparator, unit: series.unit),
                        LabFormat.range(low: point.low, high: point.high, unit: series.unit)].compactMap { $0 }.joined(separator: ", "))
        }
        return AXChartDescriptor(
            title: String(localized: "\(title) over time"), summary: nil, xAxis: xAxis, yAxis: yAxis, additionalAxes: [],
            series: [AXDataSeriesDescriptor(name: title, isContinuous: false, dataPoints: points)])
    }
}

#Preview("Light") {
    NavigationStack { LabAnalytePreview(model: LabResultsModel(), id: "analyte.vitamin_d_25oh") }
        .environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.skipOnboarding]))
}

#Preview("Dark") {
    NavigationStack { LabAnalytePreview(model: LabResultsModel(), id: "analyte.ferritin") }
        .environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.skipOnboarding]))
        .preferredColorScheme(.dark)
}

#Preview("AX5") {
    NavigationStack { LabAnalytePreview(model: LabResultsModel(), id: "analyte.vitamin_d_25oh") }
        .environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.skipOnboarding]))
        .environment(\.dynamicTypeSize, .accessibility5)
}

/// Loads the sample reports and shows one analyte.
private struct LabAnalytePreview: View {
    let model: LabResultsModel
    let id: String
    @Environment(AppModel.self) private var app

    var body: some View {
        Group {
            if model.state.value != nil {
                LabAnalyteView(model: model, historyID: id)
            } else {
                ProgressView()
            }
        }
        .task {
            if let data = app.data { _ = await model.load(data) }
        }
    }
}
