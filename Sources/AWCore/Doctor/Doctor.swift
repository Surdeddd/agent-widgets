import AWSchema
import Foundation

public struct DoctorCheck: Codable, Equatable, Sendable {
    public enum Status: String, Codable, Sendable {
        case pass
        case warn
        case fail
    }

    public var id: String
    public var title: String
    public var status: Status
    public var detail: String
    public var issue: Issue?

    public init(id: String, title: String, status: Status, detail: String, issue: Issue? = nil) {
        self.id = id
        self.title = title
        self.status = status
        self.detail = detail
        self.issue = issue
    }
}

public struct Doctor: Sendable {
    public let runner: any ProcessRunning

    public init(runner: any ProcessRunning) {
        self.runner = runner
    }

    public func run() async -> [DoctorCheck] {
        var checks = [macOS()]
        checks.append(await tool(
            id: "xcode",
            title: "Xcode",
            executable: "/usr/bin/xcodebuild",
            arguments: ["-version"],
            hint: L10n.pick(
                en: "Install Xcode from the App Store, then run `sudo xcode-select -s /Applications/Xcode.app`",
                ru: "Поставь Xcode из App Store, затем `sudo xcode-select -s /Applications/Xcode.app`"
            )
        ))
        checks.append(await tool(
            id: "xcodegen",
            title: "XcodeGen",
            executable: "xcodegen",
            arguments: ["--version"],
            hint: "brew install xcodegen"
        ))
        checks.append(await signing())
        return checks
    }

    func macOS() -> DoctorCheck {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        let text = "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        guard version.majorVersion >= 14 else {
            return DoctorCheck(
                id: "macos",
                title: "macOS",
                status: .fail,
                detail: text,
                issue: Issue(
                    code: IssueCode.toolMissing,
                    severity: .error,
                    message: L10n.pick(
                        en: "macOS \(text) is too old, widgets need macOS 14 or newer",
                        ru: "macOS \(text) слишком старая, виджетам нужна 14 или новее"
                    )
                )
            )
        }
        return DoctorCheck(id: "macos", title: "macOS", status: .pass, detail: text)
    }

    func tool(id: String, title: String, executable: String, arguments: [String], hint: String) async -> DoctorCheck {
        let result = try? await runner.run(executable, arguments, cwd: nil, environment: nil, timeout: 30)
        if let result, result.succeeded {
            let firstLine = result.stdout.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
            return DoctorCheck(id: id, title: title, status: .pass, detail: firstLine)
        }
        return DoctorCheck(
            id: id,
            title: title,
            status: .fail,
            detail: L10n.pick(en: "not found", ru: "не найден"),
            issue: Issue(
                code: IssueCode.toolMissing,
                severity: .error,
                message: L10n.pick(en: "\(title) is not available", ru: "\(title) недоступен"),
                hint: hint
            )
        )
    }

    func signing() async -> DoctorCheck {
        let title = L10n.pick(en: "Signing", ru: "Подпись")
        guard let identity = await SigningDetector.detect(runner: runner) else {
            return DoctorCheck(
                id: "signing",
                title: title,
                status: .fail,
                detail: L10n.pick(en: "no code signing identity", ru: "нет сертификата подписи"),
                issue: Issue(
                    code: IssueCode.signingMissing,
                    severity: .error,
                    message: L10n.pick(
                        en: "No Apple Development certificate in the keychain",
                        ru: "В связке ключей нет сертификата Apple Development"
                    ),
                    hint: L10n.pick(
                        en: "Xcode → Settings → Accounts → Manage Certificates → + Apple Development (a free Apple ID works)",
                        ru: "Xcode → Settings → Accounts → Manage Certificates → + Apple Development (подойдёт бесплатный Apple ID)"
                    )
                )
            )
        }
        guard let team = identity.teamID else {
            return DoctorCheck(
                id: "signing",
                title: title,
                status: .warn,
                detail: identity.name,
                issue: Issue(
                    code: IssueCode.signingMissing,
                    severity: .warning,
                    message: L10n.pick(
                        en: "Could not read the Team ID from \(identity.name)",
                        ru: "Не удалось прочитать Team ID из \(identity.name)"
                    ),
                    hint: L10n.pick(
                        en: "Set \"teamID\" in aw.local.json by hand (Xcode → Settings → Accounts shows it)",
                        ru: "Впиши \"teamID\" в aw.local.json вручную (он есть в Xcode → Settings → Accounts)"
                    )
                )
            )
        }
        return DoctorCheck(id: "signing", title: title, status: .pass, detail: "\(identity.name) · team \(team)")
    }
}

public enum DoctorFormatter {
    public static func human(_ checks: [DoctorCheck]) -> String {
        let width = (checks.map(\.title.count).max() ?? 0) + 2
        return checks.map { check in
            let mark: String
            switch check.status {
            case .pass: mark = "✓"
            case .warn: mark = "!"
            case .fail: mark = "✗"
            }
            return "\(mark) \(check.title.padding(toLength: width, withPad: " ", startingAt: 0))\(check.detail)"
        }
        .joined(separator: "\n")
    }
}
