import AWSchema
import Foundation
import Testing
@testable import AWCore

private func config(_ json: String) throws -> WorkspaceConfig {
    try JSONDecoder().decode(WorkspaceConfig.self, from: Data(json.utf8))
}

@Test func workspaceConfigResolvesIdentifiers() throws {
    let resolved = try config(
        """
        {"name":"Demo","slug":"demo","bundlePrefix":"com.example","teamID":"ABCDE12345",
        "signingIdentity":"Apple Development: a@b.c (XYZ)"}
        """
    )
    #expect(resolved.appBundleID == "com.example.demo")
    #expect(resolved.extensionBundleID == "com.example.demo.widgets")
    #expect(resolved.resolvedAppGroup == "ABCDE12345.com.example.demo")
    #expect(resolved.resolvedURLScheme == "aw-demo")
    #expect(resolved.appName == "Demo")
    #expect(resolved.resolvedInstallDir == "/Applications")
}

@Test func overridesWinForMigration() throws {
    let resolved = try config(
        """
        {"name":"Agent Widgets","slug":"home","bundlePrefix":"com.acme","teamID":"Q1W2E3R4T5",
        "signingIdentity":"x","appGroup":"Q1W2E3R4T5.com.acme.LegacyWidgets",
        "overrides":{"appBundleID":"com.acme.LegacyWidgets",
        "extensionBundleID":"com.acme.LegacyWidgets.WidgetExtension"}}
        """
    )
    #expect(resolved.appBundleID == "com.acme.LegacyWidgets")
    #expect(resolved.extensionBundleID == "com.acme.LegacyWidgets.WidgetExtension")
    #expect(resolved.resolvedAppGroup == "Q1W2E3R4T5.com.acme.LegacyWidgets")
}

@Test func localOverlayMergesOverBase() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let base = directory.appendingPathComponent("aw.json")
    let local = directory.appendingPathComponent("aw.local.json")
    try Data(#"{"name":"Ex","slug":"ex","bundlePrefix":"com.example","teamID":"AAAAAAAAAA","signingIdentity":"-"}"#.utf8)
        .write(to: base)
    try Data(#"{"bundlePrefix":"com.acme","teamID":"Q1W2E3R4T5","signingIdentity":"Apple Development: me"}"#.utf8)
        .write(to: local)
    let merged = try WorkspaceConfig.load(base: base, local: local)
    #expect(merged.appBundleID == "com.acme.ex")
    #expect(merged.resolvedAppGroup == "Q1W2E3R4T5.com.acme.ex")
    #expect(merged.signingIdentity == "Apple Development: me")
}

@Test func missingLocalOverlayIsFine() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let base = directory.appendingPathComponent("aw.json")
    try Data(#"{"name":"Ex","slug":"ex","bundlePrefix":"com.example","teamID":"AAAAAAAAAA","signingIdentity":"-"}"#.utf8)
        .write(to: base)
    let loaded = try WorkspaceConfig.load(base: base, local: directory.appendingPathComponent("aw.local.json"))
    #expect(loaded.appBundleID == "com.example.ex")
}

@Test func configValidationFlagsBadSlugAndTeam() throws {
    let bad = try config(#"{"name":"X","slug":"Bad Slug","bundlePrefix":"com.example","teamID":"short","signingIdentity":""}"#)
    let codes = bad.validate().map(\.code)
    #expect(codes.contains(IssueCode.manifestInvalid))
    #expect(codes.contains(IssueCode.signingMissing))
}
