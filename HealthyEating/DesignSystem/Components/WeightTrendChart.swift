import Accessibility
import Charts
import SwiftUI

/// The optional weight view: a smoothed `accent` trend line over faded raw weigh-ins.
/// The axis never starts at zero, there is no goal line, no arrows and no colors for up or down.
/// Only shown when weight tracking is on. See design/system/components/WeightTrendChart.
struct WeightTrendChart: View {
    let points: [WeightPoint]
    let yRange: ClosedRange<Double>
    var yStep: Double = 1
    /// Axis labels by point index, for example `[0: "Sep 21", 13: "Oct 4", 27: "Oct 18"]`.
    var xLabels: [Int: String] = [:]
    var title: String = String(localized: "Smoothed weight trend")
    /// The last day index of the x axis when days without weigh-ins have no point.
    var lastIndex: Int?
    var unit: WeightUnit = .kg
    /// Axes and legend; off for the decorative chart of the weight intro.
    var showsAxes = true

    private var xMax: Int { lastIndex ?? max(points.count - 1, 1) }

    @ScaledMetric(relativeTo: .body) private var chartHeight: CGFloat = 170

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            chart
                .frame(height: min(chartHeight, 280))
                // Axis labels stay legible without colliding; values are in the legend,
                // the text beside the chart and the accessibility chart descriptor.
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            if showsAxes {
                FlowLayout(horizontalSpacing: Spacing.s3) {
                    LegendItem(title: Text("Trend")) {
                        Capsule().fill(Color.accent).frame(height: 3)
                    }
                    LegendItem(title: Text("Weigh-ins")) {
                        Circle().fill(Color.chartFaded).padding(3)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var chart: some View {
        Chart {
            ForEach(points) { point in
                if let raw = point.raw {
                    PointMark(x: .value("Day", point.index), y: .value("Weigh-in", raw))
                        .symbolSize(28)
                        .foregroundStyle(Color.chartFaded)
                }
            }
            ForEach(points) { point in
                LineMark(x: .value("Day", point.index), y: .value("Trend", point.trend), series: .value("Series", "trend"))
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(Color.accent)
            }
            if let last = points.last {
                PointMark(x: .value("Day", last.index), y: .value("Trend", last.trend))
                    .symbolSize(64)
                    .foregroundStyle(Color.accent)
            }
        }
        .chartYScale(domain: yRange)
        .chartXScale(domain: 0...xMax)
        .chartYAxis {
            AxisMarks(position: .leading, values: Array(stride(from: yRange.lowerBound.rounded(.up), through: yRange.upperBound, by: yStep))) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1))
                    .foregroundStyle(Color.line)
                AxisValueLabel {
                    if let kg = value.as(Double.self) {
                        Text(kg, format: .number.precision(.fractionLength(0)))
                            .font(.caption2)
                            .foregroundStyle(.inkMuted)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: xLabels.keys.sorted()) { value in
                AxisValueLabel(anchor: labelAnchor(for: value.as(Int.self))) {
                    if let index = value.as(Int.self), let text = xLabels[index] {
                        Text(text)
                            .font(.caption2)
                            .foregroundStyle(.inkMuted)
                    }
                }
            }
        }
        .chartYAxis(showsAxes ? .automatic : .hidden)
        .chartXAxis(showsAxes ? .automatic : .hidden)
        .accessibilityChartDescriptor(WeightChartDescriptor(title: title, points: points, yRange: yRange, lastIndex: xMax, unit: unit))
    }
}

extension WeightTrendChart {
    /// Edge labels hang inward so the first and last dates are not clipped.
    fileprivate func labelAnchor(for index: Int?) -> UnitPoint {
        switch index {
        case 0: .topLeading
        case xMax: .topTrailing
        default: .top
        }
    }
}

nonisolated struct WeightChartDescriptor: AXChartDescriptorRepresentable {
    let title: String
    let points: [WeightPoint]
    let yRange: ClosedRange<Double>
    let lastIndex: Int
    let unit: WeightUnit

    func makeChartDescriptor() -> AXChartDescriptor {
        let format: @Sendable (Double) -> String = { $0.formatted(.number.precision(.fractionLength(1))) }
        let xAxis = AXNumericDataAxisDescriptor(
            title: String(localized: "Day"), range: 0...Double(lastIndex), gridlinePositions: []
        ) { String(localized: "Day \(Int($0) + 1)") }
        let yAxis = AXNumericDataAxisDescriptor(
            title: String(localized: "Weight"), range: yRange, gridlinePositions: []
        ) { value in
            unit == .kg ? String(localized: "\(format(value)) kilograms") : String(localized: "\(format(value)) pounds")
        }
        let trend = AXDataSeriesDescriptor(
            name: String(localized: "Trend"), isContinuous: true,
            dataPoints: points.map { AXDataPoint(x: Double($0.index), y: $0.trend) })
        let raw = AXDataSeriesDescriptor(
            name: String(localized: "Weigh-ins"), isContinuous: false,
            dataPoints: points.compactMap { point in point.raw.map { AXDataPoint(x: Double(point.index), y: $0) } })
        return AXChartDescriptor(title: title, summary: nil, xAxis: xAxis, yAxis: yAxis, additionalAxes: [], series: [trend, raw])
    }
}

#Preview("Light") {
    WeightTrendChartGallery().previewCard()
}

#Preview("Dark") {
    WeightTrendChartGallery().previewCard().preferredColorScheme(.dark)
}

#Preview("AX5") {
    ScrollView { WeightTrendChartGallery().previewCard() }
        .environment(\.dynamicTypeSize, .accessibility5)
}

struct WeightTrendChartGallery: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s1) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.s2) {
                Text(78.4, format: .number.precision(.fractionLength(1)))
                    .metricFont(.regular)
                    .foregroundStyle(.ink)
                Text("kg trend")
                    .font(.subheadline)
                    .foregroundStyle(.inkMuted)
            }
            Text("−0.3 kg per week over the last 4 weeks")
                .font(.subheadline)
                .foregroundStyle(.inkMuted)
                .padding(.bottom, Spacing.s2)
            WeightTrendChart(points: SampleData.weightPoints, yRange: 77.5...80,
                             xLabels: [0: "Sep 21", 13: "Oct 4", 27: "Oct 18"])
        }
        .cardStyle()
    }
}
