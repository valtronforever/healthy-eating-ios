import SwiftUI

/// C1 History: the month as day shapes with a legend, and the selected day's summary.
/// No streaks. Uses sample data until the backend serves statistics.
struct HistoryView: View {
    @Environment(AppModel.self) private var model
    @State private var selectedDay = Calendar.current.component(.day, from: .now) - 1

    private let calendar = Calendar.current
    private let now = Date.now

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.s5) {
                    monthCard
                    if let state = states[selectedDay], state != .future {
                        dayCard(day: selectedDay, state: state)
                    }
                }
                .padding(.horizontal, Spacing.s4)
                .padding(.bottom, Spacing.s6)
            }
            .background(Color.bg)
            .navigationTitle("History")
        }
    }

    private var states: [Int: DayState] { SampleData.monthStates(now: now) }
    private var todayDay: Int { calendar.component(.day, from: now) }

    private var monthCard: some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            Text(now, format: .dateTime.month(.wide).year())
                .font(.title3Semibold)
                .foregroundStyle(.ink)
                .padding(.horizontal, Spacing.s2)
                .accessibilityAddTraits(.isHeader)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: Spacing.s1) {
                ForEach(cells) { cell in
                    switch cell {
                    case .weekday(_, let symbol):
                        Text(verbatim: symbol)
                            .font(.caption2)
                            .foregroundStyle(.inkMuted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .accessibilityHidden(true)
                    case .blank:
                        Color.clear.frame(height: 1)
                    case .day(let day):
                        let state = states[day] ?? .none
                        Button {
                            selectedDay = day
                        } label: {
                            CalendarDay(day: day, state: state, selected: day == selectedDay, isToday: day == todayDay)
                        }
                        .buttonStyle(.plain)
                        .disabled(state == .future)
                    }
                }
            }
            // Seven columns must fit the width, like the system Calendar's month grid.
            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
            CalendarLegend()
                .padding(.horizontal, Spacing.s2)
        }
        .cardStyle(padding: Spacing.s3)
    }

    /// One grid cell. Each case has its own identity so blanks never collide with day numbers.
    private enum Cell: Hashable, Identifiable {
        case weekday(Int, String)
        case blank(Int)
        case day(Int)

        var id: Self { self }
    }

    private var cells: [Cell] {
        weekdaySymbols.enumerated().map { Cell.weekday($0.offset, $0.element) }
            + (0..<leadingBlanks).map(Cell.blank)
            + states.keys.sorted().map(Cell.day)
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols.map { $0.uppercased() }
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    private var leadingBlanks: Int {
        guard let start = calendar.dateInterval(of: .month, for: now)?.start else { return 0 }
        let weekday = calendar.component(.weekday, from: start)
        return (weekday - calendar.firstWeekday + 7) % 7
    }

    private func dayCard(day: Int, state: DayState) -> some View {
        let summary = SampleData.daySummary(day: day)
        var components = calendar.dateComponents([.year, .month], from: now)
        components.day = day
        let date = calendar.date(from: components) ?? now
        return VStack(alignment: .leading, spacing: Spacing.s2) {
            FlowLayout(horizontalSpacing: Spacing.s3) {
                Text(date, format: .dateTime.weekday(.wide).month(.wide).day())
                    .font(.headline)
                    .foregroundStyle(.ink)
                HStack(spacing: Spacing.s1 + 2) {
                    CalendarDayDot(state: state).frame(width: 10, height: 10)
                    stateTitle(state)
                        .font(.caption1Medium)
                        .foregroundStyle(.inkMuted)
                }
            }
            if !model.calmMode {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.s2) {
                    Text(NutritionFormat.number(summary.kcal))
                        .metricFont(.regular)
                        .foregroundStyle(.ink)
                    Text("kcal · \(summary.mealCount) meals")
                        .font(.subheadline)
                        .foregroundStyle(.inkMuted)
                }
            }
            Text(NutritionFormat.macroLine(protein: summary.proteinG, fat: summary.fatG, carbs: summary.carbohydratesG))
                .font(.subheadline)
                .foregroundStyle(.inkMuted)
            Text("\(summary.estimatedCount) of \(summary.mealCount) meals estimated")
                .font(.footnote)
                .foregroundStyle(.inkMuted)
        }
        .cardStyle()
        .accessibilityElement(children: .combine)
    }

    private func stateTitle(_ state: DayState) -> Text {
        switch state {
        case .complete: Text("Complete")
        case .partial: Text("Partial")
        case .none, .future: Text("Not logged")
        }
    }
}

#Preview("Light") {
    HistoryView().environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.skipOnboarding]))
}

#Preview("Dark") {
    HistoryView().environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.skipOnboarding]))
        .preferredColorScheme(.dark)
}

#Preview("AX5") {
    HistoryView().environment(AppModel(defaults: .preview, arguments: [AppModel.LaunchArgument.skipOnboarding]))
        .environment(\.dynamicTypeSize, .accessibility5)
}
