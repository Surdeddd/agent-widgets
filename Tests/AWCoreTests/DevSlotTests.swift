import AWSchema
import Foundation
import Testing
@testable import AWCore

private let slotConfig = WorkspaceConfig(name: "Probe", slug: "probe", bundlePrefix: "com.example", teamID: "ABCDE12345", signingIdentity: "x")

private func scratch() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("aw-group-\(UUID().uuidString)", isDirectory: true)
}

@Test func storeWritesOnlyWhenTheContentChanges() throws {
    let root = scratch()
    defer { try? FileManager.default.removeItem(at: root) }
    let store = AppGroupStore(root: root)
    #expect(try store.write(Data("a".utf8), to: "widgets/x/data.json") == true)
    #expect(try store.write(Data("a".utf8), to: "widgets/x/data.json") == false)
    #expect(try store.write(Data("b".utf8), to: "widgets/x/data.json") == true)
    #expect(store.read("widgets/x/data.json") == Data("b".utf8))
}

@Test func storeUsesTheGroupContainerUnlessOverridden() {
    let home = URL(fileURLWithPath: "/Users/someone", isDirectory: true)
    let standard = AppGroupStore(config: slotConfig, environment: [:], home: home)
    #expect(standard.root.path == "/Users/someone/Library/Group Containers/ABCDE12345.com.example.probe")
    let overridden = AppGroupStore(config: slotConfig, environment: ["AW_DATA_DIR": "/Volumes/scratch/aw-data"], home: home)
    #expect(overridden.root.path == "/Volumes/scratch/aw-data")
}

@Test func devSwitchCopiesTheSampleAndPointsTheSlot() throws {
    let root = try ProbeWorkspace.make()
    defer { try? FileManager.default.removeItem(at: root) }
    let store = AppGroupStore(root: root.appendingPathComponent("group", isDirectory: true))
    let widget = try Workspace.load(at: root).widget("probe")
    let target = try DevSwitch.apply(widget, scenario: "default", store: store)
    #expect(target == DevTarget(widget: "probe", scenario: "default"))
    #expect(store.read(AppGroupLayout.devData) == Data(#"{"value": 7}"#.utf8))
    #expect(store.devTarget() == target)
}

@Test func devSwitchLiveModeLeavesTheSampleAlone() throws {
    let root = try ProbeWorkspace.make()
    defer { try? FileManager.default.removeItem(at: root) }
    let store = AppGroupStore(root: root.appendingPathComponent("group", isDirectory: true))
    let widget = try Workspace.load(at: root).widget("probe")
    let target = try DevSwitch.apply(widget, scenario: nil, store: store)
    #expect(target.scenario == nil)
    #expect(store.read(AppGroupLayout.devData) == nil)
    #expect(store.devTarget() == target)
}

@Test func devSwitchRejectsAnUnknownSample() throws {
    let root = try ProbeWorkspace.make()
    defer { try? FileManager.default.removeItem(at: root) }
    let store = AppGroupStore(root: root.appendingPathComponent("group", isDirectory: true))
    let widget = try Workspace.load(at: root).widget("probe")
    #expect(throws: AWError.scenarioNotFound(widget: "probe", scenario: "nope", available: ["default"])) {
        try DevSwitch.apply(widget, scenario: "nope", store: store)
    }
    #expect(store.devTarget() == nil)
}

@Test func reloaderOpensTheSchemeInTheBackground() async {
    let runner = FakeProcessRunner()
    runner.respond(to: "/usr/bin/open", with: .ok(""))
    let reloader = Reloader(config: slotConfig, runner: runner)
    #expect(reloader.url(kind: nil) == "aw-probe://reload")
    #expect(reloader.url(kind: "my kind&x") == "aw-probe://reload?kind=my%20kind%26x")
    #expect(await reloader.reload(kind: "aw.dev"))
    #expect(runner.calls.last == ["/usr/bin/open", "-g", "aw-probe://reload?kind=aw.dev"])
}

@Test func reloaderReportsAnUnreachableApp() async {
    let runner = FakeProcessRunner()
    runner.respond(to: "/usr/bin/open", with: .failure("no application to open the URL"))
    #expect(await Reloader(config: slotConfig, runner: runner).reload(kind: "aw.dev") == false)
}
