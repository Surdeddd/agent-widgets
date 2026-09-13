import AWSchema
import CoreGraphics
import Foundation
import Testing
@testable import AWCore

private let desktopLayer = -2_147_483_601

private func windowInfo(_ number: Int, pid: Int, layer: Int = desktopLayer, name: String?, size: CGSize) -> [String: Any] {
    var info: [String: Any] = [
        kCGWindowNumber as String: number,
        kCGWindowOwnerPID as String: pid,
        kCGWindowLayer as String: layer,
        kCGWindowBounds as String: ["X": 10, "Y": 20, "Width": size.width, "Height": size.height]
    ]
    if let name {
        info[kCGWindowName as String] = name
    }
    return info
}

@Test func locatorKeepsDesktopWidgetWindowsOfNotificationCenter() {
    let info = [
        windowInfo(70, pid: 800, name: "Agent Widgets Examples · Dev", size: CGSize(width: 344, height: 170)),
        windowInfo(67, pid: 800, name: "Английский", size: CGSize(width: 360, height: 360)),
        windowInfo(71, pid: 800, layer: 25, name: "Banner", size: CGSize(width: 344, height: 80)),
        windowInfo(12, pid: 501, name: "Other", size: CGSize(width: 360, height: 360))
    ]
    let windows = WindowLocator.parse(info, owners: [800])
    #expect(windows.map(\.id) == [67, 70])
    #expect(windows.map(\.family) == [.large, .medium])
    #expect(windows.map(\.name) == ["Английский", "Agent Widgets Examples · Dev"])
}

@Test func locatorMatchesEveryLocalizationAndTheKindDescriptor() {
    let windows = [
        WidgetWindow(id: 1, name: "Weather", width: 170, height: 170, family: .small),
        WidgetWindow(id: 2, name: "Погода", width: 360, height: 360, family: .large),
        WidgetWindow(id: 3, name: "com.example.probe::com.example.probe.widgets:aw.weather", width: 170, height: 170, family: .small),
        WidgetWindow(id: 4, name: "Clock", width: 170, height: 170, family: .small),
        WidgetWindow(id: 5, name: "com.example.other::com.example.other.widgets:aw.weather", width: 170, height: 170, family: .small)
    ]
    let found = WindowLocator.find(windows, names: ["Weather", "Погода"], descriptor: "::com.example.probe.widgets:aw.weather")
    #expect(found.map(\.id) == [1, 2, 3])
}

@Test func windowsWithoutNamesMeanNoScreenRecording() {
    let windows = WindowLocator.parse([windowInfo(67, pid: 800, name: nil, size: CGSize(width: 360, height: 360))], owners: [800])
    #expect(WindowLocator.namesHidden(windows))
    #expect(!WindowLocator.namesHidden([]))
}

private final class FrameScript: @unchecked Sendable {
    private let lock = NSLock()
    private var frames: [Data?]

    init(_ frames: [Data?]) {
        self.frames = frames
    }

    func next() -> Data? {
        lock.withLock { frames.count > 1 ? frames.removeFirst() : frames.first ?? nil }
    }
}

private let frameA = Data("a".utf8)
private let frameB = Data("b".utf8)
private let frameC = Data("c".utf8)

@Test func settleWaitsForAChangeThatHoldsStill() async {
    let script = FrameScript([frameA, frameA, frameB, frameC, frameC])
    let frame = await Capture.settle(baseline: frameA, timeout: 5, interval: 0) { script.next() }
    #expect(frame == frameC)
}

@Test func settleGivesUpWhenNothingChanges() async {
    let script = FrameScript([frameA])
    let frame = await Capture.settle(baseline: frameA, timeout: 0.05, interval: 0.01) { script.next() }
    #expect(frame == nil)
}

@Test func settleNeedsTwoGoodFramesInARow() async {
    let script = FrameScript([frameB, nil, frameB, frameA, frameB, frameB])
    let frame = await Capture.settle(baseline: frameA, timeout: 5, interval: 0) { script.next() }
    #expect(frame == frameB)
    #expect(script.next() == frameB)
}

@Test func shotTargetsCoverWidgetsAndTheDevSlot() throws {
    let root = try ProbeWorkspace.make()
    defer { try? FileManager.default.removeItem(at: root) }
    let workspace = try Workspace.load(at: root)
    let all = try ShotTarget.resolve(workspace, kind: nil, dev: false)
    #expect(all.map(\.label) == ["aw.probe", "aw.dev"])
    #expect(all[0].names == ["Probe / Test", "Проба"])
    #expect(all[0].descriptor == "::com.example.probe.widgets:aw.probe")
    #expect(all[1].names == ["Probe \"Widgets\" · Dev"])
    #expect(try ShotTarget.resolve(workspace, kind: "probe", dev: false).map(\.label) == ["aw.probe"])
    #expect(try ShotTarget.resolve(workspace, kind: "aw.dev", dev: false).map(\.label) == ["aw.dev"])
    #expect(throws: AWError.widgetNotFound("nope")) {
        try ShotTarget.resolve(workspace, kind: "nope", dev: false)
    }
}

@Test func devSlotIsNamedAfterTheApp() throws {
    let root = try ProbeWorkspace.make()
    defer { try? FileManager.default.removeItem(at: root) }
    let builder = Builder(workspace: try Workspace.load(at: root), engine: Engine(root: ProbeWorkspace.repoRoot), runner: FakeProcessRunner())
    let files = try builder.generate()
    let registry = try String(contentsOf: root.appendingPathComponent(files[0]), encoding: .utf8)
    #expect(registry.contains(#".configurationDisplayName("Probe \"Widgets\" · Dev")"#))
}

@Test func shooterNamesFilesByKindFamilyAndWindow() {
    let shooter = Shooter(directory: URL(fileURLWithPath: "/ws/.aw/shots", isDirectory: true), capture: Capture(runner: FakeProcessRunner()))
    let window = WidgetWindow(id: 70, name: "x", width: 344, height: 170, family: .medium)
    let url = shooter.file(for: "aw.dev", window: window, now: Date(timeIntervalSince1970: 1_800_000_000))
    #expect(url.lastPathComponent.hasPrefix("aw.dev-medium-70-"))
    #expect(url.pathExtension == "png")
}
