import AWSchema
import Foundation
import Testing
@testable import AWCore

private func manifest(_ json: String) throws -> WidgetManifest {
    try JSONDecoder().decode(WidgetManifest.self, from: Data(json.utf8))
}

@Test func manifestDefaults() throws {
    let widget = try manifest(#"{"id":"weather","name":"Weather","families":["small","medium"],"view":"WeatherView"}"#)
    #expect(widget.resolvedKind == "aw.weather")
    #expect(widget.resolvedRefresh.seconds == 1800)
    #expect(widget.feed == nil)
}

@Test func manifestFeedDefaults() throws {
    let widget = try manifest(
        #"{"id":"w","name":"W","families":["small"],"view":"WView","feed":{"command":"python3 feed.py","every":"15m"}}"#
    )
    #expect(widget.feed?.every.seconds == 900)
    #expect(widget.feed?.resolvedTimeout.seconds == 60)
}

@Test func validatorAcceptsGoodManifest() throws {
    let widget = try manifest(#"{"id":"good-one","name":"Good","families":["small"],"view":"GoodView"}"#)
    #expect(ManifestValidator.validate([widget]).isEmpty)
}

@Test func validatorCatchesBadId() throws {
    let widget = try manifest(#"{"id":"Weather!","name":"W","families":["small"],"view":"WeatherView"}"#)
    let issues = ManifestValidator.validate([widget])
    #expect(issues.contains { $0.code == IssueCode.manifestInvalid && $0.severity == .error })
}

@Test func validatorCatchesEmptyFamiliesAndBadView() throws {
    let widget = try manifest(#"{"id":"w","name":"W","families":[],"view":"not a type"}"#)
    #expect(ManifestValidator.validate([widget]).filter { $0.severity == .error }.count == 2)
}

@Test func validatorWarnsOnFastFeedAndRejectsSubMinute() throws {
    let fast = try manifest(
        #"{"id":"a","name":"A","families":["small"],"view":"AView","feed":{"command":"./feed","every":"5m"}}"#
    )
    let tooFast = try manifest(
        #"{"id":"b","name":"B","families":["small"],"view":"BView","feed":{"command":"./feed","every":"30s"}}"#
    )
    let issues = ManifestValidator.validate([fast, tooFast])
    #expect(issues.contains { $0.code == IssueCode.budgetRisk && $0.severity == .warning })
    #expect(issues.contains { $0.code == IssueCode.manifestInvalid && $0.message.contains("b") })
}

@Test func validatorRejectsDuplicateKinds() throws {
    let first = try manifest(#"{"id":"a","kind":"same","name":"A","families":["small"],"view":"AView"}"#)
    let second = try manifest(#"{"id":"b","kind":"same","name":"B","families":["small"],"view":"BView"}"#)
    #expect(ManifestValidator.validate([first, second]).contains { $0.code == IssueCode.duplicateKind })
}

@Test func validatorRejectsDuplicateFamilies() throws {
    let widget = try manifest(#"{"id":"a","name":"A","families":["small","small"],"view":"AView"}"#)
    #expect(ManifestValidator.validate([widget]).contains { $0.code == IssueCode.manifestInvalid })
}
