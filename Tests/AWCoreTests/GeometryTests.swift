import AWSchema
import CoreGraphics
import Foundation
import Testing
@testable import AWCore

private func chronod(_ family: String, _ size: String) -> String {
    "2026-09-14 11:18:19.799 Df chronod[693:1399a22] [com.apple.chrono:timeline.store] "
        + "[com.apple.Batteries::com.apple.Batteries.BatteriesAvocadoWidgetExtension:BatteriesAvocadoWidget:\(family)::\(size):(null)~(null)] "
        + "on local reload: succeeded with 1 entries"
}

private let desk = [
    chronod("systemSmall", "164.00/164.00/27.88"),
    chronod("systemMedium", "344.00/164.00/27.88"),
    chronod("systemLarge", "344.00/344.00/27.88"),
    chronod("systemSmall", "164.00/164.00/27.88"),
    chronod("systemSmall", "170.00/170.00/24.00")
].joined(separator: "\n")

private let measuredAt = Date(timeIntervalSince1970: 1_800_000_000)

@Test func chronodLogGivesTheDesktopSizes() throws {
    let geometry = try #require(GeometryProbe.parseChronod(desk, now: measuredAt))
    #expect(geometry.small == CGSize(width: 164, height: 164))
    #expect(geometry.medium == CGSize(width: 344, height: 164))
    #expect(geometry.large == CGSize(width: 344, height: 344))
    #expect(geometry.cornerRadius == 27.88)
    #expect(geometry.source == "chronod")
    #expect(geometry.measuredAt == measuredAt)
}

@Test func extraLargeIsTwoLargesAndTheGapWhenTheLogHasNone() throws {
    let geometry = try #require(GeometryProbe.parseChronod(desk))
    #expect(geometry.extraLarge == CGSize(width: 704, height: 344))
}

@Test func extraLargeFromTheLogWins() throws {
    let geometry = try #require(GeometryProbe.parseChronod(desk + "\n" + chronod("systemExtraLarge", "710.00/344.00/27.88")))
    #expect(geometry.extraLarge == CGSize(width: 710, height: 344))
}

@Test func aLogWithoutEveryFamilyMeasuresNothing() {
    #expect(GeometryProbe.parseChronod(chronod("systemSmall", "164.00/164.00/27.88")) == nil)
    #expect(GeometryProbe.parseChronod("") == nil)
}

@Test func measureWidensTheLogWindowUntilChronodAnswers() async {
    let runner = FakeProcessRunner()
    runner.respond(to: "/usr/bin/log show --last 2h", with: .ok(""))
    runner.respond(to: "/usr/bin/log show --last 1d", with: .ok(desk))
    let geometry = await GeometryProbe.measure(runner: runner)
    #expect(geometry?.small == CGSize(width: 164, height: 164))
    #expect(runner.calls.count == 2)
    #expect(runner.calls.allSatisfy { $0.contains(#"process == "chronod" AND composedMessage CONTAINS ":system""#) })
}

@Test func storeRoundTripsAndFallsBackToBuiltInSizes() throws {
    let home = FileManager.default.temporaryDirectory.appendingPathComponent("aw-geometry-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: home) }
    #expect(GeometryStore.load(home: home) == nil)
    #expect(GeometryStore.current(home: home) == .fallback)
    let measured = try #require(GeometryProbe.parseChronod(desk, now: measuredAt))
    try GeometryStore.save(measured, home: home)
    #expect(GeometryStore.load(home: home) == measured)
    #expect(GeometryStore.current(home: home) == measured)
}

@Test func previewHandsTheMeasuredGeometryToTheRenderer() throws {
    let root = try ProbeWorkspace.make()
    defer { try? FileManager.default.removeItem(at: root) }
    let workspace = try Workspace.load(at: root)
    let widget = try workspace.widget("probe")
    let pipeline = PreviewPipeline(
        workspace: workspace,
        cache: KitCache(engine: Engine(root: ProbeWorkspace.repoRoot), runner: FakeProcessRunner()),
        runner: FakeProcessRunner()
    )
    let measured = try #require(GeometryProbe.parseChronod(desk, now: measuredAt))
    let output = root.appendingPathComponent("out", isDirectory: true)
    let arguments = pipeline.renderArguments(widget, PreviewRequest(geometry: measured), output: output)
    let index = try #require(arguments.firstIndex(of: "--geometry"))
    #expect(try JSONDecoder().decode(DeskGeometry.self, from: Data(arguments[index + 1].utf8)) == measured)
    #expect(!pipeline.renderArguments(widget, PreviewRequest(), output: output).contains("--geometry"))
}

@Test func locatorNamesFamiliesByTheMeasuredGeometry() {
    var geometry = DeskGeometry.fallback
    geometry.small = CGSize(width: 250, height: 250)
    let info: [[String: Any]] = [[
        kCGWindowNumber as String: 5,
        kCGWindowOwnerPID as String: 800,
        kCGWindowLayer as String: -2_147_483_601,
        kCGWindowName as String: "Dev",
        kCGWindowBounds as String: ["X": 0, "Y": 0, "Width": 266, "Height": 266]
    ]]
    #expect(WindowLocator.parse(info, owners: [800], geometry: geometry).first?.family == .small)
    #expect(WindowLocator.parse(info, owners: [800]).first?.family == nil)
}
