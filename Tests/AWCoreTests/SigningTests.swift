import Foundation
import Testing
@testable import AWCore

private func fixture(_ name: String) throws -> String {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "txt", subdirectory: "Fixtures"))
    return try String(contentsOf: url, encoding: .utf8)
}

@Test func parsesFindIdentityOutput() throws {
    let identities = SigningDetector.parseIdentities(try fixture("find-identity"))
    #expect(identities.count == 1)
    #expect(identities[0].name == "Apple Development: dev@example.com (AAAAAAAAAA)")
    #expect(identities[0].hash == "0123456789ABCDEF0123456789ABCDEF01234567")
}

@Test func parsesTeamFromSubject() {
    let subject = "subject=UID=ABC, CN=Apple Development: a@b.c (AAAAAAAAAA), OU=Q1W2E3R4T5, O=Jane Appleseed, C=US"
    #expect(SigningDetector.parseTeamID(subject: subject) == "Q1W2E3R4T5")
    #expect(SigningDetector.parseTeamID(subject: "subject=CN=nothing") == nil)
}

@Test func prefersAppleDevelopmentIdentity() {
    let identities = [
        SigningIdentity(hash: "A", name: "Developer ID Application: Someone (AAAAAAAAAA)"),
        SigningIdentity(hash: "B", name: "Apple Development: someone@example.com (BBBBBBBBBB)")
    ]
    #expect(SigningDetector.preferred(identities)?.hash == "B")
    #expect(SigningDetector.preferred([]) == nil)
}

@Test func detectCombinesSecurityAndOpenSSL() async throws {
    let runner = FakeProcessRunner()
    runner.respond(to: "/usr/bin/security find-identity -v -p codesigning", with: .ok(try fixture("find-identity")))
    runner.respond(to: "/usr/bin/security find-certificate", with: .ok("-----BEGIN CERTIFICATE-----\nAAAA\n-----END CERTIFICATE-----\n"))
    let subject = "subject=UID=X, CN=Apple Development: m (AAAAAAAAAA), OU=Q1W2E3R4T5, O=M, C=US\n"
    runner.respond(to: "/usr/bin/openssl x509 -noout -subject", with: .ok(subject))
    let identity = await SigningDetector.detect(runner: runner)
    #expect(identity?.teamID == "Q1W2E3R4T5")
    #expect(identity?.name.hasPrefix("Apple Development:") == true)
}

@Test func detectReturnsNilWithoutIdentities() async {
    let runner = FakeProcessRunner()
    runner.respond(to: "/usr/bin/security find-identity", with: .ok("     0 valid identities found\n"))
    #expect(await SigningDetector.detect(runner: runner) == nil)
}

@Test func systemRunnerCapturesOutput() async throws {
    let result = try await SystemProcessRunner().run("echo", ["hello"], cwd: nil, environment: nil, timeout: 10)
    #expect(result.succeeded)
    #expect(result.stdout == "hello\n")
}

@Test func systemRunnerPassesEnvironmentAndCwd() async throws {
    let directory = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
    let result = try await SystemProcessRunner().run(
        "/bin/sh",
        ["-c", "printf '%s|%s' \"$AW_PROBE\" \"$(pwd -P)\""],
        cwd: directory,
        environment: ["AW_PROBE": "42"],
        timeout: 10
    )
    let parts = result.stdout.split(separator: "|", maxSplits: 1).map(String.init)
    #expect(parts.first == "42")
    #expect(URL(fileURLWithPath: parts.last ?? "").resolvingSymlinksInPath().path == directory.path)
}

@Test func systemRunnerTimesOut() async throws {
    let result = try await SystemProcessRunner().run("/bin/sleep", ["5"], cwd: nil, environment: nil, timeout: 0.5)
    #expect(result.timedOut)
    #expect(!result.succeeded)
    #expect(result.duration < 4)
}
