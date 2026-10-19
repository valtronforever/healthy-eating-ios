import SwiftUI

/// A day cell in the History month: the date and one dot whose shape says complete (filled),
/// partial (half) or not logged (empty ring). No streaks, no highlighting of runs.
/// See design/system/components/CalendarDay.
struct CalendarDay: View {
    let day: Int
    let state: DayState
    var selected = false
    var isToday = false

    @ScaledMetric(relativeTo: .callout) private var dotSize: CGFloat = 10

    var body: some View {
        VStack(spacing: 5) {
            Text(day, format: .number)
                .font(.callout.weight(isToday ? .bold : .regular))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundStyle(numberColor)
            CalendarDayDot(state: state)
                .frame(width: dotSize, height: dotSize)
        }
        .frame(minWidth: Spacing.tapTarget, minHeight: 52)
        .frame(maxWidth: .infinity)
        .background(selected ? Color.accentSoft : Color.clear,
                    in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(selected ? .isSelected : [])
        // Seven columns must fit the width, like the system Calendar's month grid.
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }

    private var numberColor: Color {
        if isToday { return .accent }
        return state == .future ? .inkMuted : .ink
    }

    private var accessibilityText: String {
        var parts = [day.formatted()]
        switch state {
        case .complete: parts.append(String(localized: "complete"))
        case .partial: parts.append(String(localized: "partial"))
        case .none: parts.append(String(localized: "not logged"))
        case .future: break
        }
        if isToday { parts.append(String(localized: "today")) }
        return parts.joined(separator: ", ")
    }
}

/// The state dot on its own, also used in the calendar legend.
struct CalendarDayDot: View {
    let state: DayState

    var body: some View {
        switch state {
        case .complete:
            Circle().fill(Color.accent)
        case .partial:
            Circle()
                .strokeBorder(Color.accent, lineWidth: 1.5)
                .background {
                    Circle().fill(Color.accent).mask(alignment: .leading) {
                        GeometryReader { proxy in
                            Rectangle().frame(width: proxy.size.width / 2)
                        }
                    }
                }
        case .none:
            Circle().strokeBorder(Color.lineStrong, lineWidth: 1.5)
        case .future:
            Color.clear
        }
    }
}

/// The legend that spells out the three dot shapes.
struct CalendarLegend: View {
    @ScaledMetric(relativeTo: .caption) private var dotSize: CGFloat = 10

    var body: some View {
        FlowLayout(horizontalSpacing: Spacing.s4) {
            item(.complete, Text("Complete"))
            item(.partial, Text("Partial"))
            item(.none, Text("Not logged"))
        }
        .font(.caption1Medium)
        .foregroundStyle(.inkMuted)
    }

    private func item(_ state: DayState, _ title: Text) -> some View {
        HStack(spacing: Spacing.s1 + 2) {
            CalendarDayDot(state: state)
                .frame(width: dotSize, height: dotSize)
                .accessibilityHidden(true)
            title
        }
    }
}

#Preview("Light") {
    CalendarDayGallery().previewCard()
}

#Preview("Dark") {
    CalendarDayGallery().previewCard().preferredColorScheme(.dark)
}

#Preview("AX5") {
    CalendarDayGallery().previewCard().environment(\.dynamicTypeSize, .accessibility5)
}

struct CalendarDayGallery: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            HStack(spacing: Spacing.s1) {
                CalendarDay(day: 15, state: .complete)
                CalendarDay(day: 16, state: .partial)
                CalendarDay(day: 17, state: .none, selected: true)
                CalendarDay(day: 18, state: .partial, isToday: true)
                CalendarDay(day: 19, state: .future)
            }
            CalendarLegend()
        }
        .cardStyle(padding: Spacing.s3)
    }
}
