import Accessibility
import Charts
import SwiftUI

/// Calories per day as bars over the target band, for 7, 30 or 90 days.
/// Complete days are solid `ink` bars, partial days a dashed `chart-faded` outline (left out of the
/// average), not-logged days a dot on the baseline. Bars above the band look exactly like bars below it.
/// Pair it with the days-counted line. See design/system/components/KcalBarChart.
struct KcalBarChart: View {
    let days: [KcalDay]
    let target: ClosedRange<Double>
    /// Average from complete days only, computed by the backend.
    var average: Double?
    var scaleMax: Double = 3000
    var title: String = String(localized: "Calories per day")

    @ScaledMetric(relativeTo: .body) private var chartHeight: CGFloat = 180

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            chart
                .frame(height: min(chartHeight, 280))
                // Axis labels stay legible without colliding; values are in the legend,
                // the text beside the chart and the accessibility chart descriptor.
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            legend
        }
    }

    private var barHalfWidth: Double { 0.31 }

    private var chart: some View {
        Chart {
            RectangleMark(
                xStart: .value("Start", -0.5), xEnd: .value("End", Double(days.count) - 0.5),
                yStart: .value("Target low", target.lowerBound), yEnd: .value("Target high", target.upperBound))
                .foregroundStyle(Color.band)
            RuleMark(y: .value("Target low", target.lowerBound))
                .foregroundStyle(Color.accent)
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            RuleMark(y: .value("Target high", target.upperBound))
                .foregroundStyle(Color.accent)
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            RuleMark(y: .value("Baseline", 0))
                .foregroundStyle(Color.lineStrong)
                .lineStyle(StrokeStyle(lineWidth: 1))

            ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                switch day.state {
                case .complete:
                    RectangleMark(
                        xStart: .value("Start", Double(index) - barHalfWidth),
                        xEnd: .value("End", Double(index) + barHalfWidth),
                        yStart: .value("Zero", 0), yEnd: .value("Calories", day.kcal))
                        .foregroundStyle(Color.ink)
                        .cornerRadius(Radius.xs, style: .continuous)
                case .partial:
                    // Transparent mark keeps the scale; the dashed outline is drawn in the overlay.
                    RectangleMark(
                        xStart: .value("Start", Double(index) - barHalfWidth),
                        xEnd: .value("End", Double(index) + barHalfWidth),
                        yStart: .value("Zero", 0), yEnd: .value("Calories", day.kcal))
                        .foregroundStyle(Color.clear)
                case .none, .future:
                    PointMark(x: .value("Day", Double(index)), y: .value("Calories", 0))
                        .symbolSize(14)
                        .foregroundStyle(Color.lineStrong)
                        .offset(y: -5)
                }
            }

            if let average {
                RuleMark(y: .value("Average", average))
                    .foregroundStyle(Color.ink)
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
            }
        }
        .chartXScale(domain: -0.5...(Double(days.count) - 0.5))
        .chartYScale(domain: 0...scaleMax)
        .chartXAxis {
            AxisMarks(values: labeledIndices) { value in
                AxisValueLabel(centered: false) {
                    if let index = value.as(Double.self).map({ Int($0.rounded()) }), days.indices.contains(index) {
                        Text(axisLabel(for: index))
                            .font(.caption2)
                            .foregroundStyle(.inkMuted)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: Array(stride(from: 0, through: scaleMax, by: 1000))) { value in
                AxisValueLabel {
                    if let kcal = value.as(Double.self) {
                        Text(NutritionFormat.number(kcal))
                            .font(.caption2)
                            .foregroundStyle(.inkMuted)
                    }
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                if let plotAnchor = proxy.plotFrame {
                    let plot = geometry[plotAnchor]
                    ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                        if let rect = partialBarFrame(index: index, day: day, proxy: proxy, plot: plot) {
                            UnevenRoundedRectangle(topLeadingRadius: Radius.xs, topTrailingRadius: Radius.xs, style: .continuous)
                                .stroke(Color.chartFaded, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
                                .frame(width: rect.width, height: rect.height)
                                .position(x: rect.midX, y: rect.midY)
                        }
                    }
                }
            }
            .allowsHitTesting(false)
        }
        .accessibilityChartDescriptor(KcalChartDescriptor(title: title, days: days, target: target, average: average, scaleMax: scaleMax))
    }

    /// Where the dashed outline of a partial day's bar goes, in the overlay's coordinates.
    /// Kept out of the view builder so older compilers type-check the chart in time.
    private func partialBarFrame(index: Int, day: KcalDay, proxy: ChartProxy, plot: CGRect) -> CGRect? {
        guard day.state == .partial,
              let left: CGFloat = proxy.position(forX: Double(index) - barHalfWidth),
              let right: CGFloat = proxy.position(forX: Double(index) + barHalfWidth),
              let top: CGFloat = proxy.position(forY: day.kcal),
              let bottom: CGFloat = proxy.position(forY: 0.0)
        else { return nil }
        let width: CGFloat = max(right - left - 1.5, 1)
        let height: CGFloat = max(bottom - top - 0.75, 0)
        let centerX: CGFloat = plot.minX + (left + right) / 2
        let centerY: CGFloat = plot.minY + (top + bottom) / 2
        return CGRect(x: centerX - width / 2, y: centerY - height / 2, width: width, height: height)
    }

    private var labeledIndices: [Double] {
        let step = days.count <= 14 ? 1 : 7
        return days.indices.filter { $0 % step == 0 }.map(Double.init)
    }

    private func axisLabel(for index: Int) -> String {
        let date = days[index].date
        return days.count <= 7
            ? date.formatted(.dateTime.weekday(.abbreviated))
            : date.formatted(.dateTime.month(.abbreviated).day())
    }

    private var legend: some View {
        FlowLayout(horizontalSpacing: Spacing.s3) {
            LegendItem(title: Text("Complete day")) {
                RoundedRectangle(cornerRadius: 2, style: .continuous).fill(Color.ink)
            }
            LegendItem(title: Text("Partial, left out")) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .stroke(Color.chartFaded, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
            }
            LegendItem(title: Text("Target \(NutritionFormat.range(target.lowerBound, target.upperBound))")) {
                Rectangle().fill(Color.band)
                    .overlay(alignment: .top) { Rectangle().fill(Color.accent).frame(height: 1.5) }
                    .overlay(alignment: .bottom) { Rectangle().fill(Color.accent).frame(height: 1.5) }
            }
            if let average {
                LegendItem(title: Text("Average \(NutritionFormat.number(average))")) {
                    Rectangle().fill(Color.ink).frame(height: 2)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// A legend key and its words. Values never depend on the key's color alone.
struct LegendItem<Key: View>: View {
    let title: Text
    @ViewBuilder var key: Key
    @ScaledMetric(relativeTo: .caption) private var keySize: CGFloat = 12

    var body: some View {
        HStack(spacing: Spacing.s1 + 2) {
            key
                .frame(width: keySize, height: keySize)
                .accessibilityHidden(true)
            title
                .font(.caption1Medium)
                .foregroundStyle(.inkMuted)
        }
    }
}

/// Audio graph and VoiceOver description of the calorie chart.
nonisolated struct KcalChartDescriptor: AXChartDescriptorRepresentable {
    let title: String
    let days: [KcalDay]
    let target: ClosedRange<Double>
    let average: Double?
    let scaleMax: Double

    func makeChartDescriptor() -> AXChartDescriptor {
        let names = days.map { $0.date.formatted(.dateTime.month(.wide).day()) }
        let xAxis = AXCategoricalDataAxisDescriptor(title: String(localized: "Day"), categoryOrder: names)
        let yAxis = AXNumericDataAxisDescriptor(
            title: String(localized: "Calories"), range: 0...scaleMax, gridlinePositions: [target.lowerBound, target.upperBound]
        ) { NutrientUnit.kcal.spokenValue(NutritionFormat.number($0)) }
        let points = zip(days, names).map { day, name in
            AXDataPoint(x: name, y: day.kcal, label: Self.stateLabel(day.state))
        }
        var summary = String(localized: "Target \(NutritionFormat.range(target.lowerBound, target.upperBound, .kcal)).")
        if let average {
            summary += " " + String(localized: "Average \(NutritionFormat.value(average, .kcal)) from complete days.")
        }
        return AXChartDescriptor(
            title: title, summary: summary, xAxis: xAxis, yAxis: yAxis, additionalAxes: [],
            series: [AXDataSeriesDescriptor(name: String(localized: "Calories"), isContinuous: false, dataPoints: points)])
    }

    private static func stateLabel(_ state: DayState) -> String {
        switch state {
        case .complete: String(localized: "complete")
        case .partial: String(localized: "partial, left out of the average")
        case .none, .future: String(localized: "not logged")
        }
    }
}

#Preview("Light") {
    KcalBarChartGallery().previewCard()
}

#Preview("Dark") {
    KcalBarChartGallery().previewCard().preferredColorScheme(.dark)
}

#Preview("AX5") {
    ScrollView { KcalBarChartGallery().previewCard() }
        .environment(\.dynamicTypeSize, .accessibility5)
}

struct KcalBarChartGallery: View {
    var body: some View {
        VStack(spacing: Spacing.s5) {
            KcalBarChart(days: SampleData.kcalDays(count: 30), target: SampleData.kcalTarget, average: 2040)
                .cardStyle()
            KcalBarChart(days: SampleData.kcalDays(count: 7), target: SampleData.kcalTarget, average: 2060)
                .cardStyle()
        }
    }
}
