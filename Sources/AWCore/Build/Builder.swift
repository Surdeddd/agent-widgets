import AWSchema
import Foundation

public struct BuildOutcome: Codable, Sendable {
    public var app: String?
    public var issues: [Issue]
    public var seconds: Double
    public var log: String

    public var hasErrors: Bool {
        app == nil || issues.contains { $0.severity == .error }
    }
}

public struct Builder: Sendable {
    public let workspace: Workspace
    public let engine: Engine
    public let runner: any ProcessRunning

    public init(workspace: Workspace, engine: Engine, runner: any ProcessRunning) {
        self.workspace = workspace
        self.engine = engine
        self.runner = runner
    }

    public var projectDir: URL {
        workspace.buildDir
    }

    public var derivedData: URL {
        workspace.buildDir.appendingPathComponent("DerivedData", isDirectory: true)
    }

    public var logFile: URL {
        workspace.logsDir.appendingPathComponent("build.log")
    }

    public func productPath(configuration: String = "Release") -> URL {
        derivedData.appendingPathComponent("Build/Products/\(configuration)/\(workspace.config.appName).app", isDirectory: true)
    }

    public static func buildNumber(now: Date = Date()) -> String {
        String(Int(now.timeIntervalSince1970))
    }

    @discardableResult
    public func generate(buildNumber: String = Builder.buildNumber()) throws -> [String] {
        let widgets = try workspace.widgets()
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: projectDir.appendingPathComponent("App"), withIntermediateDirectories: true)
        try fileManager.createDirectory(at: projectDir.appendingPathComponent("Extension"), withIntermediateDirectories: true)
        try write(RegistryGenerator.generate(widgets), to: "Extension/Registry.swift")
        let host = try String(contentsOf: engine.templates.appendingPathComponent("app/HostApp.swift.tmpl"), encoding: .utf8)
            .replacingOccurrences(of: "__APP_GROUP_LITERAL__", with: RegistryGenerator.literal(workspace.config.resolvedAppGroup))
            .replacingOccurrences(of: "__APP_NAME_LITERAL__", with: RegistryGenerator.literal(workspace.config.appName))
        try write(host, to: "App/HostApp.swift")
        let project = ProjectGenerator(
            config: workspace.config,
            widgets: widgets,
            buildDir: projectDir,
            kitPackage: engine.kitPackage,
            version: engine.version,
            buildNumber: buildNumber
        )
        try write(project.generate(), to: "project.yml")
        return ["Extension/Registry.swift", "App/HostApp.swift", "project.yml"].map { ".aw/build/\($0)" }
    }

    public func build(sign: Bool = true, configuration: String = "Release") async throws -> BuildOutcome {
        let started = Date()
        var issues = workspace.validate().filter { $0.severity == .error && (sign || $0.code != IssueCode.signingMissing) }
        guard issues.isEmpty else {
            return BuildOutcome(app: nil, issues: issues, seconds: 0, log: logFile.path)
        }
        try generate()
        try FileManager.default.createDirectory(at: workspace.logsDir, withIntermediateDirectories: true)
        let xcodegen = try await runner.run(
            "xcodegen",
            ["generate", "--spec", "project.yml", "--project", projectDir.path, "--quiet"],
            cwd: projectDir,
            environment: nil,
            timeout: 180
        )
        guard xcodegen.succeeded else {
            issues.append(AWError.toolFailed(tool: "xcodegen", status: xcodegen.status, output: xcodegen.combinedOutput).issue)
            return BuildOutcome(app: nil, issues: issues, seconds: Date().timeIntervalSince(started), log: logFile.path)
        }
        var arguments = [
            "-project", projectDir.appendingPathComponent("\(ProjectGenerator.projectName).xcodeproj").path,
            "-scheme", ProjectGenerator.appTarget,
            "-configuration", configuration,
            "-derivedDataPath", derivedData.path,
            "build"
        ]
        if !sign {
            arguments.append("CODE_SIGNING_ALLOWED=NO")
        }
        let result = try await runner.run("/usr/bin/xcodebuild", arguments, cwd: projectDir, environment: nil, timeout: 1800)
        try? result.combinedOutput.write(to: logFile, atomically: true, encoding: .utf8)
        let app = productPath(configuration: configuration)
        guard result.succeeded, FileManager.default.fileExists(atPath: app.path) else {
            issues += failureIssues(result.combinedOutput, status: result.status)
            return BuildOutcome(app: nil, issues: issues, seconds: Date().timeIntervalSince(started), log: logFile.path)
        }
        return BuildOutcome(app: app.path, issues: issues, seconds: Date().timeIntervalSince(started), log: logFile.path)
    }

    func failureIssues(_ output: String, status: Int32) -> [Issue] {
        let parsed = SwiftcDiagnostics.parse(output, root: workspace.root).map { issue -> Issue in
            guard issue.file?.hasPrefix(".aw/build/") == true else { return issue }
            var adjusted = issue
            adjusted.hint = L10n.pick(
                en: "This is generated code: check that \"view\" in widget.json names a struct conforming to AWView",
                ru: "Это сгенерированный код: проверь, что \"view\" в widget.json — структура, реализующая AWView"
            )
            return adjusted
        }
        if !parsed.isEmpty {
            return parsed
        }
        let lines = output.split(whereSeparator: \.isNewline).map(String.init).filter { $0.contains("error:") }
        return [Issue(
            code: IssueCode.buildError,
            severity: .error,
            message: lines.suffix(3).joined(separator: "\n").isEmpty ? "xcodebuild exited with \(status)" : lines.suffix(3).joined(separator: "\n"),
            hint: L10n.pick(en: "Full log: \(logFile.path)", ru: "Полный лог: \(logFile.path)"),
            file: nil
        )]
    }

    private func write(_ text: String, to relative: String) throws {
        try text.write(to: projectDir.appendingPathComponent(relative), atomically: true, encoding: .utf8)
    }
}
