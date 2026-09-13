import AWSchema
import Foundation
import Testing
@testable import AWCore

private func identityListing() throws -> String {
    let url = try #require(Bundle.module.url(forResource: "find-identity", withExtension: "txt", subdirectory: "Fixtures"))
    return try String(contentsOf: url, encoding: .utf8)
}

@Test func doctorReportsToolsAndSigning() async throws {
    let runner = FakeProcessRunner()
    runner.respond(to: "/usr/bin/xcodebuild -version", with: .ok("Xcode 26.6\nBuild version 17F113\n"))
    runner.respond(to: "/usr/bin/security find-identity", with: .ok(try identityListing()))
    let checks = await Doctor(runner: runner).run()
    let byID = Dictionary(uniqueKeysWithValues: checks.map { ($0.id, $0) })
    #expect(byID["macos"]?.status == .pass)
    #expect(byID["xcode"]?.status == .pass)
    #expect(byID["xcode"]?.detail == "Xcode 26.6")
    #expect(byID["xcodegen"]?.status == .fail)
    #expect(byID["xcodegen"]?.issue?.hint == "brew install xcodegen")
    #expect(byID["signing"]?.status == .warn)
}

@Test func doctorFailsSigningWithoutIdentities() async {
    let runner = FakeProcessRunner()
    runner.respond(to: "/usr/bin/security find-identity", with: .ok("     0 valid identities found\n"))
    let signing = await Doctor(runner: runner).signing()
    #expect(signing.status == .fail)
    #expect(signing.issue?.code == IssueCode.signingMissing)
}

@Test func doctorHumanFormatAlignsTitles() {
    let text = DoctorFormatter.human([
        DoctorCheck(id: "a", title: "macOS", status: .pass, detail: "26.5"),
        DoctorCheck(id: "b", title: "XcodeGen", status: .fail, detail: "not found")
    ])
    #expect(text == "✓ macOS     26.5\n✗ XcodeGen  not found")
}
