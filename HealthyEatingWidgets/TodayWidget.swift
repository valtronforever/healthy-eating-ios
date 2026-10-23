import SwiftUI
import WidgetKit

/// F1 Home Screen and Lock Screen widgets (ios#35): today's totals from the snapshot the app
/// writes (`TodaySnapshot`). Calm mode shows protein instead of calories. After midnight, or
/// before the app wrote anything, they ask to open the app instead of showing old numbers.
@main
struct HealthyEatingWidgets: WidgetBundle {
    var body: some Widget {
        TodayWidget()
    }
}

struct TodayEntry: TimelineEntry {
    let date: Date
    let snapshot: TodaySnapshot?
}

struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEntry {
        TodayEntry(date: .now, snapshot: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        completion(TodayEntry(date: .now, snapshot: context.isPreview ? .sample : TodaySnapshot.load()))
    }

    /// The snapshot now, and again at midnight (when it stops being today's). The app reloads the
    /// timeline whenever it writes a new snapshot, so nothing polls.
    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        let snapshot = TodaySnapshot.load()
        let midnight = Calendar.current.nextDate(after: .now, matching: DateComponents(hour: 0), matchingPolicy: .nextTime) ?? .now
        let entries = [TodayEntry(date: .now, snapshot: snapshot), TodayEntry(date: midnight, snapshot: snapshot)]
        completion(Timeline(entries: entries, policy: .never))
    }
}

struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: TodaySnapshot.widgetKind, provider: TodayProvider()) { entry in
            TodayWidgetView(entry: entry)
                .containerBackground(Color.surface, for: .widget)
        }
        .configurationDisplayName("Today")
        .description("Today's totals against your ranges.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

struct TodayWidgetView: View {
    let entry: TodayEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let snapshot = entry.snapshot, snapshot.isCurrent(now: entry.date) {
            switch family {
            case .accessoryCircular: CircularView(snapshot: snapshot)
            case .accessoryRectangular: RectangularView(snapshot: snapshot)
            case .systemMedium: MediumView(snapshot: snapshot)
            default: SmallView(snapshot: snapshot)
            }
        } else {
            OpenAppView(family: family, signedIn: entry.snapshot != nil)
        }
    }
}

// MARK: Home Screen

private struct Hero: View {
    let snapshot: TodaySnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Today").font(.subheadline.weight(.semibold)).foregroundStyle(.accent)
            if snapshot.calmMode {
                Text(TodaySnapshot.grams(snapshot.proteinG))
                    .font(.system(.largeTitle, design: .rounded).weight(.semibold)).monospacedDigit()
                    .foregroundStyle(.ink).minimumScaleFactor(0.6).lineLimit(1)
                Text("Protein").font(.subheadline).foregroundStyle(.inkMuted)
            } else {
                Text(snapshot.energy())
                    .font(.system(.largeTitle, design: .rounded).weight(.semibold)).monospacedDigit()
                    .foregroundStyle(.ink).minimumScaleFactor(0.6).lineLimit(1)
                Text(snapshot.energyCaption()).font(.subheadline).foregroundStyle(.inkMuted).lineLimit(1)
            }
        }
    }
}

/// A macro against its range: the same track and band as the app's range band, no colors for
/// being over or under.
private struct MacroBar: View {
    let name: LocalizedStringKey
    let value: Double
    let range: TodaySnapshot.Range?
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s1) {
            HStack {
                Text(name).font(.subheadline).foregroundStyle(.ink)
                Spacer(minLength: Spacing.s1)
                Text(TodaySnapshot.grams(value)).font(.subheadline.weight(.semibold)).monospacedDigit().foregroundStyle(.ink)
            }
            GeometryReader { proxy in
                let scale = TodaySnapshot.scale(value, range)
                let width = proxy.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.surfaceSunken)
                    if let range, let low = range.min ?? range.max.map({ _ in 0 }) {
                        let high = range.max ?? scale
                        Rectangle().fill(Color.band)
                            .frame(width: max(width * (high - low) / scale, 2))
                            .offset(x: width * low / scale)
                    }
                    Capsule().fill(color).frame(width: max(width * value / scale, 3), height: 4)
                }
            }
            .frame(height: 6)
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct SmallView: View {
    let snapshot: TodaySnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Hero(snapshot: snapshot)
            Spacer(minLength: Spacing.s2)
            if snapshot.calmMode {
                MacroBar(name: "Fat", value: snapshot.fatG, range: snapshot.fat, color: .fat)
            } else {
                MacroBar(name: "Protein", value: snapshot.proteinG, range: snapshot.protein, color: .protein)
            }
        }
    }
}

private struct MediumView: View {
    let snapshot: TodaySnapshot

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.s4) {
            VStack(alignment: .leading, spacing: 0) {
                Hero(snapshot: snapshot)
                Spacer(minLength: Spacing.s2)
                SavedLine(snapshot: snapshot)
            }
            VStack(alignment: .leading, spacing: Spacing.s2) {
                if !snapshot.calmMode {
                    MacroBar(name: "Protein", value: snapshot.proteinG, range: snapshot.protein, color: .protein)
                }
                MacroBar(name: "Fat", value: snapshot.fatG, range: snapshot.fat, color: .fat)
                MacroBar(name: "Carbs", value: snapshot.carbohydratesG, range: snapshot.carbohydrates, color: .carbs)
            }
        }
    }
}

/// "Saved 20 min ago via Claude", updating by itself; "No meals yet today" before the first.
private struct SavedLine: View {
    let snapshot: TodaySnapshot

    var body: some View {
        Group {
            if snapshot.mealCount == 0 {
                Text("No meals yet today")
            } else if let saved = snapshot.lastMealSavedAt {
                if let assistant = snapshot.lastAssistant {
                    Text("Saved \(Text(saved, style: .relative)) ago via \(assistant)")
                } else {
                    Text("Saved \(Text(saved, style: .relative)) ago")
                }
            }
        }
        .font(.footnote)
        .foregroundStyle(.inkMuted)
        .lineLimit(2)
    }
}

// MARK: Lock Screen

private struct CircularView: View {
    let snapshot: TodaySnapshot

    var body: some View {
        let calm = snapshot.calmMode
        let value = calm ? snapshot.proteinG : snapshot.caloriesKcal
        let range = calm ? snapshot.protein : snapshot.calories
        Gauge(value: value, in: 0...TodaySnapshot.scale(value, range)) {
            Text(calm ? "P" : snapshot.energyUnit.symbol)
        } currentValueLabel: {
            Text(calm ? TodaySnapshot.number(snapshot.proteinG) : snapshot.energy())
                .minimumScaleFactor(0.5)
        }
        .gaugeStyle(.accessoryCircular)
        .widgetAccentable()
    }
}

private struct RectangularView: View {
    let snapshot: TodaySnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(snapshot.lockScreenHeadline()).font(.headline).widgetAccentable().lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(snapshot.lockScreenDetail()).lineLimit(1)
            SavedLine(snapshot: snapshot).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: Nothing current

private struct OpenAppView: View {
    let family: WidgetFamily
    let signedIn: Bool

    var body: some View {
        switch family {
        case .accessoryCircular:
            Image(systemName: "fork.knife").font(.title2).widgetAccentable()
        default:
            VStack(alignment: .leading, spacing: Spacing.s1) {
                if family != .accessoryRectangular {
                    Text("Today").font(.subheadline.weight(.semibold)).foregroundStyle(.accent)
                }
                Text(signedIn ? "Open Healthy Eating to update" : "Open Healthy Eating to sign in")
                    .font(family == .accessoryRectangular ? .body : .headline)
                    .foregroundStyle(family == .accessoryRectangular ? Color.primary : Color.ink)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: family == .accessoryRectangular ? .leading : .topLeading)
        }
    }
}

extension TodaySnapshot {
    /// The F1 board's numbers, for the widget gallery and previews.
    static var sample: TodaySnapshot {
        TodaySnapshot(
            day: Calendar.current.startOfDay(for: .now), savedAt: .now,
            caloriesKcal: 1200, proteinG: 77, fatG: 32, carbohydratesG: 144,
            calories: .init(min: 1900, max: 2200), protein: .init(min: 110, max: 140),
            fat: .init(min: 55, max: 80), carbohydrates: .init(min: 200, max: 260),
            energyUnit: .kcal, calmMode: false, mealCount: 3,
            lastMealSavedAt: .now.addingTimeInterval(-20 * 60), lastAssistant: "Claude")
    }
}

#Preview("Small", as: .systemSmall) {
    TodayWidget()
} timeline: {
    TodayEntry(date: .now, snapshot: .sample)
}

#Preview("Medium", as: .systemMedium) {
    TodayWidget()
} timeline: {
    TodayEntry(date: .now, snapshot: .sample)
}

#Preview("Lock Screen", as: .accessoryRectangular) {
    TodayWidget()
} timeline: {
    TodayEntry(date: .now, snapshot: .sample)
}

#Preview("Circular", as: .accessoryCircular) {
    TodayWidget()
} timeline: {
    TodayEntry(date: .now, snapshot: .sample)
}
