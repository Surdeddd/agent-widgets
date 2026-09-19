import Foundation
import Testing

private let now = Date(timeIntervalSince1970: 1_800_000_000)
private let hour: TimeInterval = 3600

private func point(_ hoursAgo: Double, _ value: Double) -> AiLimitsPace.Sample {
    AiLimitsPace.Sample(at: now.addingTimeInterval(-hoursAgo * hour), value: value)
}

@Test func theElapsedShareComesFromTheResetAndTheWindowLength() {
    #expect(AiLimitsPace.elapsed(resetsAt: now.addingTimeInterval(3 * hour), windowHours: 5, now: now) == 0.4)
    #expect(AiLimitsPace.elapsed(resetsAt: now, windowHours: 5, now: now) == 1)
    #expect(AiLimitsPace.elapsed(resetsAt: now.addingTimeInterval(6 * hour), windowHours: 5, now: now) == nil)
    #expect(AiLimitsPace.elapsed(resetsAt: now.addingTimeInterval(-hour), windowHours: 5, now: now) == nil)
    #expect(AiLimitsPace.elapsed(resetsAt: nil, windowHours: 5, now: now) == nil)
    #expect(AiLimitsPace.elapsed(resetsAt: now.addingTimeInterval(hour), windowHours: nil, now: now) == nil)
    #expect(AiLimitsPace.elapsed(resetsAt: now.addingTimeInterval(hour), windowHours: 0, now: now) == nil)
}

@Test func theForecastProjectsTheCurrentPace() {
    let resets = now.addingTimeInterval(3 * hour)
    #expect(AiLimitsPace.runsOut(percent: 50, resetsAt: resets, windowHours: 5, now: now) == now.addingTimeInterval(2 * hour))
    #expect(AiLimitsPace.runsOut(percent: 80, resetsAt: resets, windowHours: 5, now: now) == now.addingTimeInterval(0.5 * hour))
}

@Test func theForecastMovesLaterWhileNothingIsSpent() {
    let resets = now.addingTimeInterval(3 * hour)
    let early = AiLimitsPace.runsOut(percent: 60, resetsAt: resets, windowHours: 5, now: now)
    let later = AiLimitsPace.runsOut(percent: 60, resetsAt: resets, windowHours: 5, now: now.addingTimeInterval(hour))
    #expect(early == now.addingTimeInterval(2 * hour * 40 / 60))
    #expect(later == nil)
}

@Test func theForecastIsSilentWithoutASignal() {
    let resets = now.addingTimeInterval(hour)
    #expect(AiLimitsPace.runsOut(percent: 50, resetsAt: resets, windowHours: 5, now: now) == nil)
    let early = now.addingTimeInterval(4.9 * hour)
    #expect(AiLimitsPace.runsOut(percent: 9, resetsAt: early, windowHours: 5, now: now) == nil)
    #expect(AiLimitsPace.runsOut(percent: 10, resetsAt: early, windowHours: 5, now: now) != nil)
    #expect(AiLimitsPace.runsOut(percent: 100, resetsAt: resets, windowHours: 5, now: now) == nil)
    #expect(AiLimitsPace.runsOut(percent: 50, resetsAt: nil, windowHours: 5, now: now) == nil)
    #expect(AiLimitsPace.runsOut(percent: 50, resetsAt: resets, windowHours: nil, now: now) == nil)
}

@Test func theSeriesCarriesTheLastValueOverQuietHours() {
    let series = AiLimitsPace.series([point(4, 10), point(3, 30)], current: nil, now: now, steps: 5)
    #expect(series == [10, 30, 30, 30, 30])
}

@Test func theSeriesEndsWithTheCurrentValue() {
    let series = AiLimitsPace.series([point(4, 10), point(2, 30)], current: 55, now: now, steps: 5)
    #expect(series == [10, 10, 30, 30, 55])
}

@Test func theSeriesIgnoresOrderOldPointsAndTheFuture() {
    let points = [point(2, 30), point(4, 10), point(9 * 24, 99), point(-1, 77)]
    #expect(AiLimitsPace.series(points, current: nil, now: now, steps: 3) == [10, 30, 30])
}

@Test func aShortHistoryGetsFewerSteps() {
    #expect(AiLimitsPace.series([point(1, 10)], current: 20, now: now, steps: 84).count == 3)
    #expect(AiLimitsPace.series([point(100, 10)], current: 20, now: now, steps: 84).count == 84)
    #expect(AiLimitsPace.series([], current: 20, now: now) == [20])
    #expect(AiLimitsPace.series([], current: nil, now: now).isEmpty)
}

@Test func theSpanIsTheAgeOfTheOldestKeptPoint() {
    #expect(AiLimitsPace.span([point(2, 30), point(4, 10), point(9 * 24, 99)], now: now) == 4 * hour)
    #expect(AiLimitsPace.span([], now: now) == 0)
}
