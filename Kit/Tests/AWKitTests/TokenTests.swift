import AWSchema
import Testing
@testable import AWKit

@Test func typeScaleGrowsWithFamily() {
    for role in AWTextRole.allCases {
        let sizes = Family.allCases.map { AWType.size(role, $0) }
        #expect(sizes == sizes.sorted(), "\(role) should not shrink in bigger families")
    }
    for family in Family.allCases {
        #expect(AWType.size(.hero, family) > AWType.size(.display, family))
        #expect(AWType.size(.display, family) > AWType.size(.title, family))
        #expect(AWType.size(.display, family) >= AWType.size(.title, family) + 6, "display must read as a step above title")
    }
}

@Test func nothingShrinksBelowReadableSize() {
    for role in AWTextRole.allCases {
        for family in Family.allCases {
            #expect(AWType.size(role, family) * AWType.minimumScale(role) >= 8.5 || role == .hero)
        }
    }
}

@Test func trendsCarryMeaningBeyondColor() {
    let good = AWTrend.percent(0.034)
    #expect(good.text == "+3.4%")
    #expect(good.symbol == "arrow.up.right")
    #expect(good.status == .ok)
    #expect(AWTrend.percent(0.034, positiveIsGood: false).status == .critical)
    #expect(AWTrend.percent(0).direction == .flat)
}

@Test func everyStatusHasItsOwnSymbol() {
    let symbols = AWStatus.allCases.map(\.symbol)
    #expect(Set(symbols).count == symbols.count)
}
