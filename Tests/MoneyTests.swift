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

    @Test func convertsAtGivenRate() {
        let result = Money.convertToBase(Decimal(2970), currency: "ARS", rates: ["ARS": Decimal(1485)])
        #expect(result == Decimal(2))
    }

    @Test func baseCurrencyIsIdentity() {
        #expect(Money.convertToBase(Decimal(42), currency: "USD", rates: [:]) == Decimal(42))
    }

    @Test func missingOrInvalidRateReturnsNil() {
        #expect(Money.convertToBase(Decimal(10), currency: "EUR", rates: ["ARS": Decimal(1485)]) == nil)
        #expect(Money.convertToBase(Decimal(10), currency: "ARS", rates: ["ARS": Decimal.zero]) == nil)
    }
}
