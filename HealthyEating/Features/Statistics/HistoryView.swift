import SwiftUI

/// Loads one month of day totals and completeness for History.
@MainActor
@Observable
final class HistoryModel {
    private(set) var month: Date
    private(set) var state: Loadable<DayRange> = .loading
    private let calendar: Calendar

    init(calendar: Calendar = .current, now: Date = .now) {
        self.calendar = calendar
        month = calendar.dateInterval(of: .month, for: now)?.start ?? now
    }

    var isCurrentMonth: Bool { calendar.isDate(month, equalTo: .now, toGranularity: .month) }

    func load(_ data: any NutritionDataSource) async -> APIError? {
        guard let interval = calendar.dateInterval(of: .month, for: month),
              let lastOfMonth = calendar.date(byAdding: .day, value: -1, to: interval.end)
        else { return nil }
        let last = min(lastOfMonth, calendar.startOfDay(for: .now))
        if state.value == nil { state = .loading }
        do throws(APIError) {
            state = .loaded(try await data.days(from: interval.start, to: last))
            return nil
        } catch {
            state = .failed(error)
            return error
        }
    }

    func showMonth(offset: Int) {
        guard let next = calendar.date(byAdding: .month, value: offset, to: month) else { return }
        month = next
        state = .loading
    }
}

/// C1 History: the month as day shapes (complete, partial, not logged) with a legend, and the
/// selected day's summary with a link to the full day. No streaks.
struct HistoryView: View {
    @Environment(AppModel.self) private var app
    @State private var model = HistoryModel()
    @State private var selected = Calendar.current.startOfDay(for: .now)

    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.s5) {
                    OfflineBanner()
                    switch model.state {
                    case .loading:
                        LoadingCards()
                    case .failed(let error):
                        ServerErrorMessage(error: error, host: app.server?.host) { Task { await reload() } }
                            .padding(.top, Spacing.s8)
                    case .loaded(let range):
                        monthCard(range)
                        if let day = range.days.first(where: { calendar.isDate($0.date, inSameDayAs: selected) }) {
                            DayCard(day: day, calm: app.calmMode)
                        }
                    }
                }
                .padding(.horizontal, Spacing.s4)
                .padding(.bottom, Spacing.s6)
            }
            .refreshable { await reload() }
            .background(Color.bg)
            .navigationTitle("History")
            .navigationDestination(for: DayTotals.self) { day in
                DayView(date: day.date) { Task { await reload() } }
            }
        }
        .task(id: "\(model.month.timeIntervalSince1970)-\(app.foregrounds)") { await reload() }
    }

    private func reload() async {
        guard let data = app.data else { return }
        if let error = await model.load(data) { app.handle(error) }
    }

    private func monthCard(_ range: DayRange) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            HStack {
                Text(model.month, format: .dateTime.month(.wide).year())
                    .font(.title3Semibold)
                    .foregroundStyle(.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button { change(month: -1) } label: { Image(systemName: "chevron.left") }
                    .accessibilityLabel(Text("Previous month"))
                    .frame(minWidth: Spacing.tapTarget, minHeight: Spacing.tapTarget)
                Button { change(month: 1) } label: { Image(systemName: "chevron.right") }
                    .accessibilityLabel(Text("Next month"))
                    .frame(minWidth: Spacing.tapTarget, minHeight: Spacing.tapTarget)
                    .disabled(model.isCurrentMonth)
            }
            .foregroundStyle(.accent)
            .padding(.horizontal, Spacing.s2)

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
                    case .day(let date):
                        let state = state(of: date, in: range)
                        Button {
                            selected = date
                        } label: {
                            CalendarDay(
                                day: calendar.component(.day, from: date), state: state,
                                selected: calendar.isDate(date, inSameDayAs: selected), isToday: calendar.isDateInToday(date))
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

    private func change(month offset: Int) {
        model.showMonth(offset: offset)
        if model.isCurrentMonth {
            selected = calendar.startOfDay(for: .now)
        } else if let last = calendar.dateInterval(of: .month, for: model.month).flatMap({ calendar.date(byAdding: .day, value: -1, to: $0.end) }) {
            selected = last
        }
    }

    private func state(of date: Date, in range: DayRange) -> DayState {
        if date > calendar.startOfDay(for: .now) { return .future }
        return range.days.first { calendar.isDate($0.date, inSameDayAs: date) }?.state ?? .none
    }

    /// One grid cell. Each case has its own identity so blanks never collide with day numbers.
    private enum Cell: Hashable, Identifiable {
        case weekday(Int, String)
        case blank(Int)
        case day(Date)

        var id: Self { self }
    }

    private var cells: [Cell] {
        guard let interval = calendar.dateInterval(of: .month, for: model.month),
              let count = calendar.range(of: .day, in: .month, for: model.month)?.count
        else { return [] }
        let weekday = calendar.component(.weekday, from: interval.start)
        let blanks = (weekday - calendar.firstWeekday + 7) % 7
        let days = (0..<count).compactMap { calendar.date(byAdding: .day, value: $0, to: interval.start) }
        return weekdaySymbols.enumerated().map { Cell.weekday($0.offset, $0.element) }
            + (0..<blanks).map(Cell.blank)
            + days.map(Cell.day)
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols.map { $0.uppercased() }
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }
}

/// The selected day's summary under the calendar, with a link to the whole day.
struct DayCard: View {
    let day: DayTotals
    var calm = false
    var energyUnit: EnergyUnit = .kcal

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            FlowLayout(horizontalSpacing: Spacing.s3) {
                Text(day.date, format: .dateTime.weekday(.wide).month(.wide).day())
                    .font(.headline)
                    .foregroundStyle(.ink)
                HStack(spacing: Spacing.s1 + 2) {
                    CalendarDayDot(state: day.state).frame(width: 10, height: 10)
                    DayStateTitle(state: day.state)
                        .font(.caption1Medium)
                        .foregroundStyle(.inkMuted)
                }
            }
            if day.mealCount == 0 {
                Text("No meals logged on this day.")
                    .font(.subheadline)
                    .foregroundStyle(.inkMuted)
            } else {
                if !calm {
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.s2) {
                        Text(NutritionFormat.number(energyUnit.amount(fromKcal: day.caloriesKcal)))
                            .metricFont(.regular)
                            .foregroundStyle(.ink)
                        Text("\(energyUnit.nutrientUnit.symbol) · \(day.mealCount) meals")
                            .font(.subheadline)
                            .foregroundStyle(.inkMuted)
                    }
                }
                Text(NutritionFormat.macroLine(protein: day.proteinG, fat: day.fatG, carbs: day.carbohydratesG))
                    .font(.subheadline)
                    .foregroundStyle(.inkMuted)
            }
            ViewThatFits(in: .horizontal) {
                HStack {
                    estimatedLine
                    Spacer()
                    openLink
                }
                VStack(alignment: .leading, spacing: Spacing.s2) {
                    estimatedLine
                    openLink
                }
            }
        }
        .cardStyle()
    }

    @ViewBuilder
    private var estimatedLine: some View {
        if let share = day.estimatedCaloriesShare, day.mealCount > 0 {
            Text("\(share.formatted(.percent.precision(.fractionLength(0)))) of calories estimated")
                .font(.footnote)
                .foregroundStyle(.inkMuted)
        }
    }

    private var openLink: some View {
        NavigationLink(value: day) {
            HStack(spacing: Spacing.s1) {
                Text("Open day")
                Image(systemName: "chevron.right").imageScale(.small)
            }
            .font(.body.weight(.semibold))
            .foregroundStyle(.accent)
        }
        .frame(minHeight: Spacing.tapTarget)
    }
}

/// The words for a day's completeness; the shape next to them carries the same meaning.
struct DayStateTitle: View {
    let state: DayState

    var body: some View {
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
