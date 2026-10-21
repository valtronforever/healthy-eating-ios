import SwiftUI

/// Fiber, sugar and sodium for a day: one muted line under the day's summary, shown only when a
/// meal has them. A value that only some meals have says so ("2 of 3 meals"), so a partial
/// total never reads as the whole day.
struct OptionalNutrientsLine: View {
    let totals: [OptionalNutrient: OptionalTotal]
    let mealCount: Int

    var body: some View {
        if let text = Self.text(totals, mealCount: mealCount) {
            Text(verbatim: text)
                .font(.footnote)
                .foregroundStyle(.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// "Fiber 14 g · Sugar 26 g (2 of 3 meals) · Sodium 820 mg (1 of 3 meals)"; nil without values.
    nonisolated static func text(_ totals: [OptionalNutrient: OptionalTotal], mealCount: Int, locale: Locale = .current) -> String? {
        let parts = OptionalNutrient.allCases.compactMap { nutrient -> String? in
            guard let total = totals[nutrient] else { return nil }
            let value = "\(nutrient.name) \(NutritionFormat.value(total.amount, nutrient.unit, locale: locale))"
            guard total.mealCount < mealCount else { return value }
            return String(localized: "\(value) (\(total.mealCount) of \(mealCount) meals)")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

/// Fiber, sugar and sodium averages in Trends, each with the days it covers.
struct OptionalAveragesCard: View {
    let averages: [OptionalNutrient: OptionalAverage]
    let countedDays: Int

    var body: some View {
        VStack(spacing: 0) {
            ForEach(OptionalNutrient.allCases.filter { averages[$0] != nil }) { nutrient in
                if let average = averages[nutrient] {
                    LabeledContent {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(verbatim: NutritionFormat.value(average.average, nutrient.unit))
                                .metricFont(.small)
                                .foregroundStyle(.ink)
                            Text(verbatim: Self.daysLine(average, countedDays: countedDays))
                                .font(.footnote)
                                .foregroundStyle(.inkMuted)
                        }
                    } label: {
                        Text(verbatim: nutrient.name).foregroundStyle(.ink)
                    }
                    .padding(.vertical, Spacing.s2)
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .cardStyle(padding: Spacing.s4)
    }

    /// "average of 18 days", or "on 9 of 18 counted days" when only some days have a value.
    nonisolated static func daysLine(_ average: OptionalAverage, countedDays: Int) -> String {
        if average.days >= countedDays {
            return average.days == 1 ? String(localized: "average of 1 day") : String(localized: "average of \(average.days) days")
        }
        return String(localized: "on \(average.days) of \(countedDays) counted days")
    }
}

#Preview("Light") {
    OptionalNutrientsGallery().previewCard()
}

#Preview("Dark") {
    OptionalNutrientsGallery().previewCard().preferredColorScheme(.dark)
}

#Preview("AX5") {
    OptionalNutrientsGallery().previewCard().environment(\.dynamicTypeSize, .accessibility5)
}

struct OptionalNutrientsGallery: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s4) {
            OptionalNutrientsLine(
                totals: [.fiber: .init(amount: 14, mealCount: 3), .sugar: .init(amount: 26, mealCount: 2), .sodium: .init(amount: 820, mealCount: 1)],
                mealCount: 3)
            OptionalAveragesCard(
                averages: [.fiber: .init(average: 21, days: 18), .sodium: .init(average: 2100, days: 9)], countedDays: 18)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
