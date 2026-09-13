import AWSchema
import Foundation
import Testing
@testable import AWCore

@Test func jsonOutputIsValidAndReportsFailure() throws {
    let issue = Issue(code: "X", severity: .error, message: "boom", hint: "fix it")
    let text = Printer(json: true).render(CommandResult<NoPayload>(issues: [issue])) { _ in "" }
    let object = try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any]
    #expect(object?["ok"] as? Bool == false)
    let issues = object?["issues"] as? [[String: Any]]
    #expect(issues?.first?["hint"] as? String == "fix it")
}

@Test func jsonOutputCarriesPayload() throws {
    let text = Printer(json: true).render(CommandResult(artifacts: ["a.png"], data: ["k": "v"])) { _ in "" }
    let object = try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any]
    #expect(object?["ok"] as? Bool == true)
    #expect((object?["data"] as? [String: String])?["k"] == "v")
    #expect(object?["artifacts"] as? [String] == ["a.png"])
}

@Test func humanOutputShowsMarksAndHints() {
    let issue = Issue(code: "X", severity: .warning, message: "careful", hint: "do this", file: "w.json", line: 2)
    let text = Printer(json: false).render(CommandResult(issues: [issue], data: "payload")) { $0 ?? "" }
    #expect(text.contains("payload"))
    #expect(text.contains("! X  careful (w.json:2)"))
    #expect(text.contains("→ do this"))
}

@Test func warningsDoNotFailResult() {
    let warning = Issue(code: "W", severity: .warning, message: "m")
    #expect(CommandResult<NoPayload>(issues: [warning]).ok)
    #expect(!CommandResult<NoPayload>(issues: [Issue(code: "E", severity: .error, message: "m")]).ok)
}

@Test func issueMessagesFollowLanguage() {
    let english = L10n.$language.withValue(.en) { AWError.widgetNotFound("clock").issue.message }
    let russian = L10n.$language.withValue(.ru) { AWError.widgetNotFound("clock").issue.message }
    #expect(english.contains("clock"))
    #expect(russian.contains("clock"))
    #expect(english != russian)
}
