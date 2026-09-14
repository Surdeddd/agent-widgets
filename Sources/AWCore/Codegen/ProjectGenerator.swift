import AWSchema
import Foundation

public struct ProjectGenerator {
    public let config: WorkspaceConfig
    public let widgets: [WidgetSource]
    public let buildDir: URL
    public let kitPackage: URL
    public let version: String
    public let buildNumber: String

    public init(config: WorkspaceConfig, widgets: [WidgetSource], buildDir: URL, kitPackage: URL, version: String, buildNumber: String) {
        self.config = config
        self.widgets = widgets
        self.buildDir = buildDir
        self.kitPackage = kitPackage
        self.version = version
        self.buildNumber = buildNumber
    }

    public static let projectName = "AgentWidgetsApp"
    public static let appTarget = "App"
    public static let extensionTarget = "Widgets"

    public func generate() -> String {
        (header() + appTarget() + extensionTarget()).joined(separator: "\n") + "\n"
    }

    private func header() -> [String] {
        [
            "name: \(Self.projectName)",
            "options:",
            "  bundleIdPrefix: \(quoted(config.bundlePrefix))",
            "  deploymentTarget:",
            "    macOS: \"14.0\"",
            "packages:",
            "  Kit:",
            "    path: \(quoted(kitPackage.path))",
            "settings:",
            "  base:",
            "    SWIFT_VERSION: \"5.0\"",
            "    DEVELOPMENT_TEAM: \(quoted(config.teamID))",
            "    CODE_SIGN_STYLE: Manual",
            "    CODE_SIGN_IDENTITY: \(quoted(config.signingIdentity))",
            "    PROVISIONING_PROFILE_SPECIFIER: \"\"",
            "    ENABLE_HARDENED_RUNTIME: YES",
            "    MARKETING_VERSION: \(quoted(version))",
            "    CURRENT_PROJECT_VERSION: \(quoted(buildNumber))",
            "targets:"
        ]
    }

    private func appTarget() -> [String] {
        let group = quoted(config.resolvedAppGroup)
        return [
            "  \(Self.appTarget):",
            "    type: application",
            "    platform: macOS",
            "    sources: [App]",
            "    info:",
            "      path: App/Info.plist",
            "      properties:",
            "        CFBundleDisplayName: \(quoted(config.appName))",
            "        CFBundleName: \(quoted(config.appName))",
            "        LSUIElement: true",
            "        CFBundleURLTypes:",
            "          - CFBundleURLName: \(quoted(config.appBundleID))",
            "            CFBundleURLSchemes: [\(quoted(config.resolvedURLScheme))]",
            "        AWAppGroup: \(group)",
            "    entitlements:",
            "      path: App/App.entitlements",
            "      properties:",
            "        com.apple.security.app-sandbox: false",
            "        com.apple.security.application-groups: [\(group)]",
            "    settings:",
            "      base:",
            "        PRODUCT_BUNDLE_IDENTIFIER: \(quoted(config.appBundleID))",
            "        PRODUCT_NAME: \(quoted(config.appName))",
            "    dependencies:",
            "      - target: \(Self.extensionTarget)",
            "        embed: true",
            "        copy:",
            "          destination: plugins",
            "      - package: Kit",
            "        product: AWKit"
        ]
    }

    private func extensionTarget() -> [String] {
        let group = quoted(config.resolvedAppGroup)
        var lines = [
            "  \(Self.extensionTarget):",
            "    type: app-extension",
            "    platform: macOS",
            "    sources:",
            "      - path: Extension"
        ]
        for widget in widgets.sorted(by: { $0.id < $1.id }) {
            lines += [
                "      - path: \(quoted(relativePath(to: widget.directory)))",
                "        includes: [\"*.swift\", \"**/*.swift\"]",
                "        group: \(quoted("Widgets/\(widget.id)"))"
            ]
        }
        lines += [
            "    info:",
            "      path: Extension/Info.plist",
            "      properties:",
            "        CFBundleDisplayName: \(quoted(config.appName))",
            "        NSExtension:",
            "          NSExtensionPointIdentifier: com.apple.widgetkit-extension",
            "        AWAppGroup: \(group)",
            "    entitlements:",
            "      path: Extension/Extension.entitlements",
            "      properties:",
            "        com.apple.security.app-sandbox: true",
            "        com.apple.security.application-groups: [\(group)]",
            "    settings:",
            "      base:",
            "        PRODUCT_BUNDLE_IDENTIFIER: \(quoted(config.extensionBundleID))",
            "        SKIP_INSTALL: YES",
            "    dependencies:",
            "      - package: Kit",
            "        product: AWKit"
        ]
        return lines
    }

    func relativePath(to directory: URL) -> String {
        let from = buildDir.standardizedFileURL.pathComponents
        let to = directory.standardizedFileURL.pathComponents
        let shared = zip(from, to).prefix { $0 == $1 }.count
        let ups = Array(repeating: "..", count: from.count - shared)
        return (ups + to.dropFirst(shared)).joined(separator: "/")
    }

    static func quoted(_ text: String) -> String {
        var result = "\""
        for scalar in text.unicodeScalars {
            switch scalar {
            case "\\": result += "\\\\"
            case "\"": result += "\\\""
            case "\n": result += "\\n"
            case "\r": result += "\\r"
            case "\t": result += "\\t"
            default:
                if scalar.value < 0x20 {
                    result += String(format: "\\x%02X", scalar.value)
                } else {
                    result.unicodeScalars.append(scalar)
                }
            }
        }
        return result + "\""
    }

    private func quoted(_ text: String) -> String {
        Self.quoted(text)
    }
}
