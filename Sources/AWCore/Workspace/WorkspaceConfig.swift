import AWSchema
import Foundation

public struct WorkspaceConfig: Codable, Equatable, Sendable {
    public struct Overrides: Codable, Equatable, Sendable {
        public var appBundleID: String?
        public var extensionBundleID: String?
        public var appName: String?

        public init(appBundleID: String? = nil, extensionBundleID: String? = nil, appName: String? = nil) {
            self.appBundleID = appBundleID
            self.extensionBundleID = extensionBundleID
            self.appName = appName
        }
    }

    public var name: String
    public var slug: String
    public var bundlePrefix: String
    public var teamID: String
    public var signingIdentity: String
    public var appGroup: String?
    public var urlScheme: String?
    public var locale: Language?
    public var installDir: String?
    public var overrides: Overrides?

    public init(
        name: String,
        slug: String,
        bundlePrefix: String,
        teamID: String,
        signingIdentity: String,
        appGroup: String? = nil,
        urlScheme: String? = nil,
        locale: Language? = nil,
        installDir: String? = nil,
        overrides: Overrides? = nil
    ) {
        self.name = name
        self.slug = slug
        self.bundlePrefix = bundlePrefix
        self.teamID = teamID
        self.signingIdentity = signingIdentity
        self.appGroup = appGroup
        self.urlScheme = urlScheme
        self.locale = locale
        self.installDir = installDir
        self.overrides = overrides
    }

    public var appBundleID: String {
        overrides?.appBundleID ?? "\(bundlePrefix).\(slug)"
    }

    public var extensionBundleID: String {
        overrides?.extensionBundleID ?? "\(appBundleID).widgets"
    }

    public var resolvedAppGroup: String {
        appGroup ?? "\(teamID).\(bundlePrefix).\(slug)"
    }

    public var resolvedURLScheme: String {
        urlScheme ?? "aw-\(slug)"
    }

    public var appName: String {
        overrides?.appName ?? name
    }

    public var resolvedInstallDir: String {
        installDir ?? "/Applications"
    }

    public static func load(base: URL, local: URL?) throws -> WorkspaceConfig {
        var merged = try readJSON(base)
        if let local, FileManager.default.fileExists(atPath: local.path) {
            merged = merged.merged(with: try readJSON(local))
        }
        do {
            return try JSONDecoder().decode(WorkspaceConfig.self, from: merged.canonicalData())
        } catch {
            throw AWError.invalidJSON(file: base.lastPathComponent, reason: DecodingErrorFormatter.describe(error))
        }
    }

    public func validate() -> [Issue] {
        var issues: [Issue] = []
        if slug.range(of: "^[a-z][a-z0-9-]{1,39}$", options: .regularExpression) == nil {
            issues.append(Issue(
                code: IssueCode.manifestInvalid,
                severity: .error,
                message: "Workspace slug \"\(slug)\" is invalid",
                hint: "Use lowercase letters, digits and dashes, for example \"my-widgets\"",
                file: "aw.json"
            ))
        }
        if bundlePrefix.range(of: "^[A-Za-z][A-Za-z0-9-]*(\\.[A-Za-z0-9-]+)+$", options: .regularExpression) == nil {
            issues.append(Issue(
                code: IssueCode.manifestInvalid,
                severity: .error,
                message: "Bundle prefix \"\(bundlePrefix)\" is invalid",
                hint: "Use reverse-DNS, for example \"com.yourname\"",
                file: "aw.json"
            ))
        }
        if teamID.range(of: "^[A-Z0-9]{10}$", options: .regularExpression) == nil || signingIdentity.isEmpty {
            issues.append(Issue(
                code: IssueCode.signingMissing,
                severity: .error,
                message: "No usable signing identity or Team ID in aw.json / aw.local.json",
                hint: "Xcode → Settings → Accounts → Manage Certificates → + Apple Development, then run `aw init --refresh-signing`",
                file: "aw.local.json"
            ))
        } else if !resolvedAppGroup.hasPrefix("\(teamID).") {
            issues.append(Issue(
                code: IssueCode.manifestInvalid,
                severity: .error,
                message: "App Group \"\(resolvedAppGroup)\" does not start with the Team ID \(teamID)",
                hint: "On macOS the App Group must be \"<TeamID>.<anything>\", otherwise the widget reads nothing",
                file: "aw.json"
            ))
        }
        return issues
    }

    private static func readJSON(_ url: URL) throws -> JSONValue {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw AWError.invalidJSON(file: url.lastPathComponent, reason: "cannot read file")
        }
        do {
            return try JSONDecoder().decode(JSONValue.self, from: data)
        } catch {
            throw AWError.invalidJSON(file: url.lastPathComponent, reason: DecodingErrorFormatter.describe(error))
        }
    }
}
