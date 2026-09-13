import Foundation

enum AppBundle {
    static func make(at url: URL, bundleID: String, marker: String = "") throws {
        let contents = url.appendingPathComponent("Contents", isDirectory: true)
        try FileManager.default.createDirectory(
            at: contents.appendingPathComponent("PlugIns/Widgets.appex", isDirectory: true),
            withIntermediateDirectories: true
        )
        let plist = try PropertyListSerialization.data(fromPropertyList: ["CFBundleIdentifier": bundleID], format: .xml, options: 0)
        try plist.write(to: contents.appendingPathComponent("Info.plist"))
        try Data(marker.utf8).write(to: contents.appendingPathComponent("marker"))
    }

    static func marker(of app: URL) -> String? {
        (try? Data(contentsOf: app.appendingPathComponent("Contents/marker"))).flatMap { String(bytes: $0, encoding: .utf8) }
    }
}
