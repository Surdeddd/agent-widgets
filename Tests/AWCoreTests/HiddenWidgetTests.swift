import AWSchema
import CoreGraphics
import Foundation
import Testing
@testable import AWCore

private final class Frames: @unchecked Sendable {
    private let lock = NSLock()
    private var frames: [[WidgetWindow]]
    private var count = 0

    init(_ frames: [[WidgetWindow]]) {
        self.frames = frames
    }

    var calls: Int {
        lock.withLock { count }
    }

    func next() -> [WidgetWindow] {
        lock.withLock {
            count += 1
            return frames.count > 1 ? frames.removeFirst() : frames.first ?? []
        }
    }
}

private func windowInfo(_ id: Int, onscreen: Bool?) -> [String: Any] {
    var window: [String: Any] = [
        kCGWindowOwnerPID as String: 800,
        kCGWindowLayer as String: -2_147_483_601,
        kCGWindowNumber as String: id,
        kCGWindowName as String: "Probe · Dev",
        kCGWindowBounds as String: ["X": 0, "Y": 0, "Width": 360, "Height": 180]
    ]
    if let onscreen {
        window[kCGWindowIsOnscreen as String] = onscreen
    }
    return window
}

@Test func windowParsingReadsWhetherTheWidgetIsOnScreen() {
    let windows = WindowLocator.parse([windowInfo(1, onscreen: true), windowInfo(2, onscreen: nil), windowInfo(3, onscreen: false)], owners: [800])
    #expect(windows.map(\.hidden) == [false, true, true])
}

@Test func slotWaiterWaitsUntilTheSlotIsVisible() async {
    let target = ShotTarget(label: "aw.dev", names: ["Probe · Dev"], descriptor: "::com.example.probe.widgets:aw.dev")
    let hidden = WidgetWindow(id: 70, name: "Probe · Dev", width: 344, height: 170, family: .medium, visible: false)
    let shown = WidgetWindow(id: 70, name: "Probe · Dev", width: 344, height: 170, family: .medium, visible: true)
    let frames = Frames([[hidden], [hidden], [shown]])
    let windows = await SlotWaiter(families: [.medium], timeout: 5, interval: 0).wait(target: target, locate: { frames.next() }, sleep: { _ in })
    #expect(windows?.first?.visible == true)
    #expect(frames.calls == 3)
}

@Test func aHiddenDevSlotIsReportedWithoutWaitingForARedraw() async throws {
    let root = try ProbeWorkspace.make()
    defer { try? FileManager.default.removeItem(at: root) }
    let workspace = try Workspace.load(at: root)
    let runner = FakeProcessRunner()
    runner.respond(to: "/usr/bin/open", with: .ok(""))
    let hidden = WidgetWindow(id: 7, name: workspace.config.devSlotName, width: 360, height: 180, family: .medium, visible: false)
    let started = Date()
    let outcome = try await DevSlot.show(
        try workspace.widget("probe"),
        scenario: "default",
        workspace: workspace,
        runner: runner,
        timeout: 30,
        store: AppGroupStore(root: root.appendingPathComponent("group", isDirectory: true)),
        screenRecording: true,
        locate: { [hidden] }
    )
    #expect(outcome.issues.map(\.code) == [IssueCode.widgetHidden])
    #expect(outcome.shots.isEmpty)
    #expect(Date().timeIntervalSince(started) < 5)
}

@Test func captureSkipsHiddenWindowsAndSizesTheWidgetLacks() {
    let small = WidgetWindow(id: 1, name: "x", width: 164, height: 164, family: .small, visible: true)
    let large = WidgetWindow(id: 2, name: "x", width: 344, height: 344, family: .large, visible: true)
    let hiddenMedium = WidgetWindow(id: 3, name: "x", width: 344, height: 164, family: .medium, visible: false)
    #expect(WindowLocator.capturable([small, large, hiddenMedium], families: [.small, .medium]).map(\.id) == [1])
    #expect(WindowLocator.capturable([large], families: [.small]).map(\.id) == [2])
    #expect(WindowLocator.capturable([hiddenMedium], families: [.medium]).isEmpty)
}

@Test func doctorSaysWhenThePlacedSlotIsNotVisible() throws {
    let root = try ProbeWorkspace.make()
    defer { try? FileManager.default.removeItem(at: root) }
    let workspace = try Workspace.load(at: root)
    let hidden = WidgetWindow(id: 9, name: workspace.config.devSlotName, width: 344, height: 170, family: .medium, visible: false)
    let shown = WidgetWindow(id: 9, name: workspace.config.devSlotName, width: 344, height: 170, family: .medium, visible: true)
    let doctor = Doctor(runner: FakeProcessRunner())
    let check = doctor.devSlotCheck(workspace.config, screenRecording: true, windows: [hidden])
    #expect(check.status == .warn)
    #expect(check.issue?.code == IssueCode.widgetHidden)
    #expect(doctor.devSlotCheck(workspace.config, screenRecording: true, windows: [shown]).status == .pass)
}

@Test func hiddenIssueNamesTheSizesAndTheFix() {
    let issue = L10n.$language.withValue(.en) { ShotIssues.hidden("Probe · Dev", families: [.medium, .large]) }
    #expect(issue.code == IssueCode.widgetHidden)
    #expect(issue.message.contains("(medium, large)"))
    #expect(issue.hint?.contains("aw slot") == true)
    #expect(issue.message.contains("no longer on the desktop"))
}
