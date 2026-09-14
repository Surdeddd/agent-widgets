import AWSchema
import Foundation
import Testing
@testable import AWCore

private let target = ShotTarget(
    label: "aw.dev",
    names: ["Probe · Dev"],
    descriptor: "::com.example.probe.widgets:aw.dev"
)

private let devMedium = WidgetWindow(id: 70, name: "Probe · Dev", width: 344, height: 170, family: .medium)
private let otherWidget = WidgetWindow(id: 3, name: "Weather", width: 344, height: 170, family: .medium)

private final class WindowScript: @unchecked Sendable {
    private let lock = NSLock()
    private var frames: [[WidgetWindow]]

    init(_ frames: [[WidgetWindow]]) {
        self.frames = frames
    }

    func next() -> [WidgetWindow] {
        lock.withLock { frames.count > 1 ? frames.removeFirst() : frames.first ?? [] }
    }
}

private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    @discardableResult
    func bump() -> Int {
        lock.withLock {
            value += 1
            return value
        }
    }

    var count: Int { lock.withLock { value } }
}

@Test func waiterReturnsTheDevWindowAfterTwoSleeps() async {
    let script = WindowScript([[], [], [devMedium]])
    let sleeps = Counter()
    let ticks = Counter()
    let origin = Date(timeIntervalSince1970: 0)
    let found = await SlotWaiter(families: [], timeout: 600).wait(
        target: target,
        locate: { script.next() },
        sleep: { _ in _ = sleeps.bump() },
        now: { origin.addingTimeInterval(TimeInterval(ticks.bump() - 1) * 2) }
    )
    #expect(found == [devMedium])
    #expect(sleeps.count == 2)
}

@Test func waiterTimesOutWhenARequestedFamilyIsMissing() async {
    let ticks = Counter()
    let origin = Date(timeIntervalSince1970: 0)
    let found = await SlotWaiter(families: [.medium, .large], timeout: 4, interval: 2).wait(
        target: target,
        locate: { [devMedium] },
        sleep: { _ in },
        now: { origin.addingTimeInterval(TimeInterval(ticks.bump() - 1) * 2) }
    )
    #expect(found == nil)
}

@Test func waiterIgnoresWindowsOfOtherWidgets() async {
    let ticks = Counter()
    let origin = Date(timeIntervalSince1970: 0)
    let found = await SlotWaiter(families: [], timeout: 4, interval: 2).wait(
        target: target,
        locate: { [otherWidget] },
        sleep: { _ in },
        now: { origin.addingTimeInterval(TimeInterval(ticks.bump() - 1) * 2) }
    )
    #expect(found == nil)
}
