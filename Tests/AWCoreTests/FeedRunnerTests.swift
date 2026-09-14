import AWSchema
import Foundation
import Testing
@testable import AWCore

private let feedNow = Date(timeIntervalSince1970: 1_800_000_000)

private struct FeedFixture {
    let root: URL
    let store: AppGroupStore

    init(command: String, timeout: Int = 10) throws {
        root = try ProbeWorkspace.make()
        store = AppGroupStore(root: root.appendingPathComponent("group", isDirectory: true))
        try setCommand(command, timeout: timeout)
    }

    func setCommand(_ command: String, timeout: Int = 10) throws {
        let manifest = WidgetManifest(
            id: "probe",
            name: LocalizedText(en: "Probe"),
            families: [.small],
            view: "ProbeView",
            feed: FeedSpec(command: command, every: Interval(seconds: 900), timeout: Interval(seconds: timeout)),
            settings: .object(["path": .string("/")])
        )
        try JSONEncoder().encode(manifest).write(to: root.appendingPathComponent("widgets/probe/widget.json"))
    }

    func run(at date: Date = feedNow, validate: (@Sendable (Data) async -> AWSchema.Issue?)? = nil) async throws -> FeedRun {
        let workspace = try Workspace.load(at: root)
        return await FeedRunner(workspace: workspace, store: store, runner: SystemProcessRunner(), language: .ru)
            .run(try workspace.widget("probe"), now: date, validate: validate)
    }

    var published: String? {
        store.read(AppGroupLayout.data("probe")).flatMap { String(bytes: $0, encoding: .utf8) }
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: root)
    }
}

@Test func feedPublishesCanonicalDataOnlyWhenItChanges() async throws {
    let fixture = try FeedFixture(command: #"echo '{"value": 3, "b": 1}'"#)
    defer { fixture.cleanup() }
    let first = try await fixture.run()
    #expect(first.ok && first.changed, "\(first.issues.map(\.message))")
    #expect(fixture.published == #"{"b":1,"value":3}"#)
    #expect(fixture.store.status(widget: "probe") == FeedStatus(ok: true, checkedAt: feedNow, fetchedAt: feedNow))
    let second = try await fixture.run()
    #expect(second.ok && !second.changed)
}

@Test func feedSeesItsEnvironment() async throws {
    let fixture = try FeedFixture(
        command: #"printf '{"id":"%s","lang":"%s","settings":%s,"state":"%s"}' "$AW_WIDGET_ID" "$AW_LANG" "$AW_SETTINGS" "$AW_STATE_PATH""#
    )
    defer { fixture.cleanup() }
    let run = try await fixture.run()
    #expect(run.ok, "\(run.issues.map(\.message))")
    let data = try #require(fixture.store.read(AppGroupLayout.data("probe")))
    let value = try JSONDecoder().decode(JSONValue.self, from: data)
    #expect(value["id"]?.stringValue == "probe")
    #expect(value["lang"]?.stringValue == "ru")
    #expect(value["settings"]?["path"]?.stringValue == "/")
    #expect(value["state"]?.stringValue?.hasSuffix("widgets/probe/state.json") == true)
}

@Test func failingFeedKeepsTheLastGoodData() async throws {
    let fixture = try FeedFixture(command: #"echo '{"value": 1}'"#)
    defer { fixture.cleanup() }
    _ = try await fixture.run(at: feedNow)
    try fixture.setCommand("echo boom >&2; exit 3")
    let later = feedNow.addingTimeInterval(900)
    let run = try await fixture.run(at: later)
    #expect(!run.ok)
    #expect(run.issues.first?.code == IssueCode.feedFailed)
    #expect(run.issues.first?.message.contains("boom") == true)
    #expect(fixture.published == #"{"value":1}"#)
    let status = try #require(fixture.store.status(widget: "probe"))
    #expect(!status.ok)
    #expect(status.fetchedAt == feedNow)
    #expect(status.checkedAt == later)
    #expect(status.exitCode == 3)
    #expect(status.stderrTail == ["boom"])
    let log = try String(contentsOf: fixture.root.appendingPathComponent(".aw/logs/probe.log"), encoding: .utf8)
    #expect(log.contains("exit 3"))
    #expect(log.contains("boom"))
}

@Test func aMissingProgramIsNamedWithTheFeedPath() async throws {
    let fixture = try FeedFixture(command: "aw-missing-binary-xyz --flag")
    defer { fixture.cleanup() }
    let run = try await fixture.run()
    let issue = try #require(run.issues.first)
    #expect(issue.code == IssueCode.feedCommandNotFound)
    #expect(issue.message.contains("`aw-missing-binary-xyz`"))
    #expect(issue.hint?.contains("PATH=/opt/homebrew/bin") == true)
    let status = try #require(fixture.store.status(widget: "probe"))
    #expect(status.exitCode == 127)
    #expect(status.stderrTail?.contains { $0.contains("aw-missing-binary-xyz") } == true)
}

@Test func aToolMissingInsideAScriptIsNamed() async throws {
    let fixture = try FeedFixture(command: "sh -c 'aw-missing-tool-xyz --version'")
    defer { fixture.cleanup() }
    let run = try await fixture.run()
    #expect(run.issues.first?.code == IssueCode.feedCommandNotFound)
    #expect(run.issues.first?.message.contains("`aw-missing-tool-xyz`") == true)
}

@Test func aScriptWithoutTheExecutableBitIsExplained() async throws {
    let fixture = try FeedFixture(command: "./feed.sh")
    defer { fixture.cleanup() }
    try Data("#!/bin/sh\necho '{}'\n".utf8).write(to: fixture.root.appendingPathComponent("widgets/probe/feed.sh"))
    let run = try await fixture.run()
    #expect(run.issues.first?.code == IssueCode.feedCommandNotFound)
    #expect(run.issues.first?.hint?.contains("chmod +x ./feed.sh") == true)
    #expect(fixture.store.status(widget: "probe")?.exitCode == 126)
}

@Test func garbageOutputIsRejected() async throws {
    let fixture = try FeedFixture(command: "echo not json")
    defer { fixture.cleanup() }
    let run = try await fixture.run()
    #expect(run.issues.first?.code == IssueCode.feedInvalidOutput)
    #expect(fixture.published == nil)
}

@Test func slowFeedIsStoppedAtItsTimeout() async throws {
    let fixture = try FeedFixture(command: "sleep 5", timeout: 1)
    defer { fixture.cleanup() }
    let run = try await fixture.run()
    #expect(run.issues.first?.code == IssueCode.feedTimeout)
    #expect(run.seconds < 4)
}

@Test func timelineOutputIsAccepted() async throws {
    let fixture = try FeedFixture(command: #"echo '{"timeline":[{"date":"2027-01-01T00:00:00Z","data":{"value":1}}]}'"#)
    defer { fixture.cleanup() }
    let run = try await fixture.run()
    #expect(run.ok, "\(run.issues.map(\.message))")
    #expect(fixture.published?.contains("timeline") == true)
}

@Test func failedValidationBlocksPublishing() async throws {
    let fixture = try FeedFixture(command: #"echo '{"value": "seven"}'"#)
    defer { fixture.cleanup() }
    let run = try await fixture.run { _ in
        AWSchema.Issue(code: IssueCode.decode, severity: .error, message: "value: expected a number")
    }
    #expect(run.issues.first?.code == IssueCode.decode)
    #expect(fixture.published == nil)
}

@Test func logsRotateAtTheLimit() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("aw-log-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let file = folder.appendingPathComponent("w.log")
    LogFile.append(String(repeating: "a", count: 40) + "\n", to: file, limit: 30)
    LogFile.append("b\n", to: file, limit: 30)
    #expect(LogFile.tail(file, lines: 5) == ["b"])
    #expect(FileManager.default.fileExists(atPath: file.appendingPathExtension("1").path))
    #expect(LogFile.tail(folder.appendingPathComponent("missing.log"), lines: 5) == nil)
}
