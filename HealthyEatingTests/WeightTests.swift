import Foundation
import Testing
@testable import HealthyEating

struct WeighInParsingTests {
    @Test func acceptsEitherDecimalSeparator() {
        #expect(WeighInForm.kg(from: "80.4", unit: .kg) == 80.4)
        #expect(WeighInForm.kg(from: " 80,4 ", unit: .kg) == 80.4)
    }

    @Test func convertsPoundsToKilograms() {
        #expect(WeighInForm.kg(from: "177.2", unit: .lb) == 80.38)
    }

    @Test func refusesImplausibleWeights() {
        #expect(WeighInForm.kg(from: "", unit: .kg) == nil)
        #expect(WeighInForm.kg(from: "abc", unit: .kg) == nil)
        #expect(WeighInForm.kg(from: "19.9", unit: .kg) == nil)
        #expect(WeighInForm.kg(from: "400.1", unit: .kg) == nil)
        #expect(WeighInForm.kg(from: "40", unit: .lb) == nil)
    }

    @Test func explainsTheRangeInThePersonsUnit() {
        #expect(WeighInForm.problem("", unit: .kg) == nil)
        #expect(WeighInForm.problem("80", unit: .kg) == nil)
        #expect(WeighInForm.problem("8", unit: .kg) == "Enter a weight between 20 and 400 kg.")
        #expect(WeighInForm.problem("8", unit: .lb) == "Enter a weight between 44 and 882 lb.")
    }

    @Test func showsTheValueInThePersonsUnitForEditing() {
        let locale = Locale(identifier: "en_US")
        #expect(WeighInForm.text(80.38, unit: .kg, locale: locale) == "80.4")
        #expect(WeighInForm.text(80.38, unit: .lb, locale: locale) == "177.2")
        #expect(WeighInForm.text(80.38, unit: .kg, locale: Locale(identifier: "de_DE")) == "80,4")
    }
}

struct WeightFormatTests {
    private let locale = Locale(identifier: "en_US")

    @Test func valuesHaveOneDecimalAndTheUnit() {
        #expect(WeightFormat.value(80.38, unit: .kg, locale: locale) == "80.4 kg")
        #expect(WeightFormat.value(80.38, unit: .lb, locale: locale) == "177.2 lb")
    }

    @Test func weeklyChangeIsAPlainSignedNumber() {
        #expect(WeightFormat.weeklyChange(-0.3, days: 28, unit: .kg, locale: locale) == "−0.3 kg per week over the last 4 weeks")
        #expect(WeightFormat.weeklyChange(0.2, days: 7, unit: .kg, locale: locale) == "+0.2 kg per week over the last week")
    }

    @Test func aTinyChangeReadsAsAboutTheSame() {
        #expect(WeightFormat.weeklyChange(0.02, days: 21, unit: .kg, locale: locale) == "About the same over the last 3 weeks")
        #expect(WeightFormat.weeklyChange(-0.01, days: 14, unit: .lb, locale: locale) == "About the same over the last 2 weeks")
    }

    @Test func namesWhereAWeighInCameFrom() {
        #expect(WeightFormat.source(.assistant) == "From your assistant")
        #expect(WeightFormat.source(.app) == "Added in the app")
        #expect(WeightFormat.source(.appleHealth) == "From Apple Health")
    }
}

struct WeightAndEnergyTests {
    private func estimate(_ missing: EnergyEstimate.MissingData?, counted: Int = 9) -> EnergyEstimate {
        EnergyEstimate(countedDays: counted, weighIns: 22, weighInDays: 20, averageIntakeKcal: 2060,
                       maintenanceKcal: missing == nil ? 2350 : nil, confidence: missing == nil ? .medium : nil, missing: missing)
    }

    @Test func saysWhatTheEstimateStillNeeds() {
        #expect(WeightView.missingLine(estimate(.loggedDays))
            == "Not enough logged days yet: the estimate needs 14 in the last 4 weeks (now 9).")
        #expect(WeightView.missingLine(estimate(.weighIns))
            == "Not enough weigh-ins yet: the estimate needs weigh-ins on 6 days spread over 2 weeks.")
    }

    @Test func namesWhatTheEstimateIsBasedOn() {
        #expect(WeightView.basisLine(estimate(nil, counted: 28)) == "28 days of log, 22 weigh-ins")
    }

    @MainActor
    @Test func boldsTheAmountInTheMaintenanceLine() {
        let line = WeightView.maintainLine(kcal: 2350, unit: .kcal)
        let amount = NutritionFormat.energy(2350, in: .kcal)
        #expect(String(line.characters) == "Based on your log and weight, you maintain at about \(amount) per day.")
        let bold = line.runs.filter { $0.inlinePresentationIntent == .stronglyEmphasized }
        #expect(bold.map { String(line[$0.range].characters) } == [amount])
    }

    @Test func chartPlacesWeighInDaysOnTheirDayOfTheWindow() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Berlin"))
        let first = try #require(APIDate.day("2026-09-25", calendar: calendar))
        let last = try #require(APIDate.day("2026-10-22", calendar: calendar))
        let day = { (offset: Int) in calendar.date(byAdding: .day, value: offset, to: first) ?? first }
        let history = WeightHistory(firstDay: first, lastDay: last, entries: [], trend: [
            WeightTrendDay(date: day(0), weightKg: 79.6, trendKg: 79.5),
            WeightTrendDay(date: day(27), weightKg: 78.3, trendKg: 78.4),
        ])

        let chart = WeightView.chart(history, unit: .kg, calendar: calendar)

        #expect(chart.points.map(\.index) == [0, 27])
        #expect(chart.lastIndex == 27)
        #expect(chart.range == 78...80)
        #expect(chart.step == 1)
        #expect(Set(chart.labels.keys) == [0, 13, 27])
    }

    @Test func chartUsesThePersonsUnit() throws {
        let first = Calendar.current.startOfDay(for: .now)
        let history = WeightHistory(firstDay: first, lastDay: first, entries: [], trend: [
            WeightTrendDay(date: first, weightKg: 80, trendKg: 80),
        ])
        let chart = WeightView.chart(history, unit: .lb)
        let point = try #require(chart.points.first)
        #expect(abs(point.trend - 176.37) < 0.01)
        #expect(chart.step == 2)
    }
}
