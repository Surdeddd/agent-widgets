import Foundation
@testable import AWCore

enum ProbeWorkspace {
    static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    static let integration = ProcessInfo.processInfo.environment["AW_SKIP_INTEGRATION"] == nil

    static let view = """
    import AWKit
    import SwiftUI

    struct ProbeData: Codable, Sendable {
        let value: Int
    }

    struct ProbeView: AWView {
        let entry: AWEntry<ProbeData>

        init(entry: AWEntry<ProbeData>) {
            self.entry = entry
        }

        var body: some View {
            AWPhaseView(entry) { data in
                AWMetric("\\(data.value)", label: "Probe")
            }
        }
    }
    """

    static func make(name: String = "Probe \"Widgets\"", view: String = ProbeWorkspace.view) throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("aw-probe-\(UUID().uuidString)", isDirectory: true)
        let config = """
        {"name":\(RegistryGenerator.literal(name)),"slug":"probe","bundlePrefix":"com.example","teamID":"ABCDE12345","signingIdentity":"x"}
        """
        try write(config, to: root.appendingPathComponent("aw.json"))
        try write(
            #"{"id":"probe","name":{"en":"Probe / Test","ru":"Проба"},"families":["small","medium"],"view":"ProbeView"}"#,
            to: root.appendingPathComponent("widgets/probe/widget.json")
        )
        try write(view, to: root.appendingPathComponent("widgets/probe/ProbeView.swift"))
        try write(#"{"value": 7}"#, to: root.appendingPathComponent("widgets/probe/samples/default.json"))
        return root
    }

    private static func write(_ text: String, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: url)
    }
}
