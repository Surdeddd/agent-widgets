import Testing
@testable import AWKit

@Test func barsWithRepeatedLabelsKeepTheirOwnSlots() {
    let week = ["M", "T", "W", "T", "F", "S", "S"].enumerated().map { AWBarItem($0.element, Double($0.offset)) }
    let slots = AWBarChart.slots(for: week)
    #expect(Set(slots).count == week.count)
    #expect(slots.map { AWBarChart.label(for: $0, in: week) } == ["M", "T", "W", "T", "F", "S", "S"])
    #expect(AWBarChart.label(for: "9", in: week).isEmpty)
    #expect(AWBarChart.label(for: nil, in: week).isEmpty)
}
