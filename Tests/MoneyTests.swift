import Foundation
import Testing
@testable import Wealth

struct MoneyTests {
    @Test func wholeAmountsDropDecimals() {
        #expect(Money.format(Decimal(1284), currency: "USD") == "US$ 1.284")
        #expect(Money.format(Decimal(20), currency: "USD") == "US$ 20")
    }

    @Test func fractionalAmountsUseCommaDecimals() {
        #expect(Money.format(Decimal(string: "2.99")!, currency: "USD") == "US$ 2,99")
        #expect(Money.format(Decimal(string: "26.94")!, currency: "USD") == "US$ 26,94")
    }

    @Test func arsGroupsThousandsWithDots() {
        #expect(Money.format(Decimal(40000), currency: "ARS") == "AR$ 40.000")
        #expect(Money.format(Decimal(1295000), currency: "ARS") == "AR$ 1.295.000")
    }

    @Test func unknownCurrencyFallsBackToCode() {
        #expect(Money.format(Decimal(5), currency: "EUR") == "EUR 5")
    }

    @Test func roundedFormatDropsCents() {
        #expect(Money.formatRounded(Decimal(string: "16.77")!, currency: "USD") == "US$ 17")
        #expect(Money.formatRounded(Decimal(string: "16.2")!, currency: "USD") == "US$ 16")
    }

    @Test func convertsAtGivenRate() {
        #expect(Money.convert(Decimal(2970), from: "ARS", to: "USD", rates: ["ARS": Decimal(1485)]) == Decimal(2))
    }

    @Test func convertsFromBaseIntoAnotherCurrency() {
        #expect(Money.convert(Decimal(2), from: "USD", to: "ARS", rates: ["ARS": Decimal(1485)]) == Decimal(2970))
    }

    @Test func convertsBetweenTwoNonBaseCurrencies() {
        let rates = ["ARS": Decimal(1485), "EUR": Decimal(string: "0.9")!]
        let result = Money.convert(Decimal(1485), from: "ARS", to: "EUR", rates: rates)
        #expect(result == Decimal(string: "0.9")!)
    }

    @Test func sameCurrencyIsIdentity() {
        #expect(Money.convert(Decimal(42), from: "USD", to: "USD", rates: [:]) == Decimal(42))
        #expect(Money.convert(Decimal(42), from: "ARS", to: "ARS", rates: [:]) == Decimal(42))
    }

    @Test func missingOrInvalidRateReturnsNil() {
        #expect(Money.convert(Decimal(10), from: "EUR", to: "USD", rates: ["ARS": Decimal(1485)]) == nil)
        #expect(Money.convert(Decimal(10), from: "ARS", to: "USD", rates: ["ARS": Decimal.zero]) == nil)
        #expect(Money.convert(Decimal(10), from: "USD", to: "EUR", rates: [:]) == nil)
    }
}
