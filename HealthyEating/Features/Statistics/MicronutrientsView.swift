import SwiftUI

/// Vitamins and minerals of a day or a Trends period (backend #25), opened from Today, a past
/// day or Trends. The server computes them from USDA reference data for the food items the
/// assistant listed; a value that covers only part of the day or period says so.
struct MicronutrientsView: View {
    /// "Today", "Tue, Oct 21" or "Last 7 days".
    let subtitle: String
    let values: [Micronutrient: MicronutrientValue]
    let footer: String

    var body: some View {
        List {
            Section {
                Text(verbatim: subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.inkMuted)
                    .plainListRow()
            }
            MicronutrientSections(values: values)
            Section {
                EmptyView()
            } footer: {
                Text(verbatim: footer).sectionTextStyle()
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.bg)
        .navigationTitle("Vitamins and minerals")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// A day's values; "2 of 3 meals" when not every meal has one.
    nonisolated static func dayValues(_ day: DayTotals) -> [Micronutrient: MicronutrientValue] {
        day.micronutrients.mapValues { total in
            MicronutrientValue(
                amount: total.amount,
                note: total.mealCount < day.mealCount ? String(localized: "\(total.mealCount) of \(day.mealCount) meals") : nil)
        }
    }

    /// A period's averages; "on 4 of 7 counted days" when not every counted day has one.
    nonisolated static func periodValues(_ period: TrendPeriod) -> [Micronutrient: MicronutrientValue] {
        period.micronutrientAverages.mapValues { average in
            MicronutrientValue(amount: average.average, note: OptionalAveragesCard.daysLine(average, countedDays: period.countedDays))
        }
    }

    nonisolated static var dayFooter: String {
        String(localized: "From USDA FoodData Central, for the food items your assistant listed with each meal. Calories and macronutrients are not changed by them.")
    }

    nonisolated static var periodFooter: String {
        String(localized: "Averages of the counted days on which every meal has food items, from USDA FoodData Central.")
    }
}

/// The row that opens `MicronutrientsView`; shown only when there are values.
struct MicronutrientsLink: View {
    let subtitle: String
    let values: [Micronutrient: MicronutrientValue]
    let footer: String

    var body: some View {
        NavigationLink {
            MicronutrientsView(subtitle: subtitle, values: values, footer: footer)
        } label: {
            HStack(spacing: Spacing.s3) {
                SymbolTile(systemName: "leaf", small: true)
                LabeledContent("Vitamins and minerals") {
                    Text(verbatim: Self.countLine(values.count)).foregroundStyle(.inkMuted)
                }
                .foregroundStyle(.ink)
            }
        }
        .accessibilityIdentifier("micronutrients")
    }

    nonisolated static func countLine(_ count: Int) -> String {
        count == 1 ? String(localized: "1 value") : String(localized: "\(count) values")
    }
}

#Preview("Light") {
    NavigationStack {
        MicronutrientsView(subtitle: "Today", values: MicronutrientGallery.values, footer: MicronutrientsView.dayFooter)
    }
}

#Preview("Dark") {
    NavigationStack {
        MicronutrientsView(subtitle: "Today", values: MicronutrientGallery.values, footer: MicronutrientsView.dayFooter)
    }
    .preferredColorScheme(.dark)
}

#Preview("AX5") {
    NavigationStack {
        MicronutrientsView(subtitle: "Today", values: MicronutrientGallery.values, footer: MicronutrientsView.dayFooter)
    }
    .environment(\.dynamicTypeSize, .accessibility5)
}
