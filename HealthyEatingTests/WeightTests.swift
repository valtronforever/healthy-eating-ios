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
