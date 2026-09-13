import AWSchema
import Foundation

public struct PreviewRequest: Sendable {
    public var families: [Family]?
    public var scenarios: [String]?
    public var full: Bool
    public var language: Language

    public init(families: [Family]? = nil, scenarios: [String]? = nil, full: Bool = false, language: Language = L10n.language) {
        self.families = families
        self.scenarios = scenarios
        self.full = full
        self.language = language
    }
}

public struct PreviewOutcome: Codable, Sendable {
    public var widget: String
    public var report: PreviewReport?
    public var issues: [Issue]
    public var compiled: Bool
    public var compileSeconds: Double
    public var renderSeconds: Double

    public var allIssues: [Issue] {
        issues + (report?.allIssues ?? [])
    }

    public var hasErrors: Bool {
        allIssues.contains { $0.severity == .error }
    }
}

public struct PreviewPipeline: Sendable {
    public let workspace: Workspace
    public let cache: KitCache
    public let runner: any ProcessRunning

    public init(workspace: Workspace, cache: KitCache, runner: any ProcessRunning) {
        self.workspace = workspace
        self.cache = cache
        self.runner = runner
    }

    public func run(_ widget: WidgetSource, _ request: PreviewRequest) async throws -> PreviewOutcome {
        var outcome = PreviewOutcome(
            widget: widget.id,
            report: nil,
            issues: ManifestValidator.validate(widget.manifest),
            compiled: false,
            compileSeconds: 0,
            renderSeconds: 0
        )
        guard !outcome.hasErrors else {
            return outcome
        }
        let started = Date()
        guard let binary = try await compile(widget, into: &outcome) else {
            outcome.compileSeconds = Date().timeIntervalSince(started)
            return outcome
        }
        outcome.compileSeconds = Date().timeIntervalSince(started)
        let output = workspace.previewsDir(for: widget.id)
        try? FileManager.default.removeItem(at: output)
        let renderStarted = Date()
        let result = try await runner.run(binary.path, renderArguments(widget, request, output: output), cwd: workspace.root, environment: nil, timeout: 300)
        outcome.renderSeconds = Date().timeIntervalSince(renderStarted)
        guard let data = try? Data(contentsOf: output.appendingPathComponent("report.json")),
              let report = try? AWJSON.decoder().decode(PreviewReport.self, from: data)
        else {
            outcome.issues.append(Issue(
                code: IssueCode.previewCrashed,
                severity: .error,
                message: L10n.pick(
                    en: "The preview renderer exited with \(result.status) without a report",
                    ru: "Рендерер превью завершился с кодом \(result.status) без отчёта"
                ),
                hint: String(result.combinedOutput.suffix(800))
            ))
            return outcome
        }
        outcome.report = report
        return outcome
    }

    private func compile(_ widget: WidgetSource, into outcome: inout PreviewOutcome) async throws -> URL? {
        let kit = try await cache.ensure()
        let directory = workspace.cacheDir.appendingPathComponent("preview/\(widget.id)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let binary = directory.appendingPathComponent("preview")
        let stamp = directory.appendingPathComponent("fingerprint")
        let key = Fingerprint.of(files: widget.swiftFiles, root: widget.directory, extra: [kit.lastPathComponent, widget.manifest.view])
        if (try? String(contentsOf: stamp, encoding: .utf8)) == key, FileManager.default.fileExists(atPath: binary.path) {
            return binary
        }
        let main = directory.appendingPathComponent("main.swift")
        try PreviewMainGenerator.generate(view: widget.manifest.view).write(to: main, atomically: true, encoding: .utf8)
        let arguments = [
            "swiftc", "-swift-version", "5", "-target", Toolchain.targetTriple, "-Onone",
            "-I", kit.path, "-L", kit.path, "-lAWPreview", "-lAWKit", "-lAWSchema",
            "-o", binary.path
        ] + widget.swiftFiles.map(\.path) + [main.path]
        let result = try await runner.run("/usr/bin/xcrun", arguments, cwd: widget.directory, environment: nil, timeout: 300)
        outcome.compiled = true
        guard result.succeeded else {
            try? FileManager.default.removeItem(at: stamp)
            let parsed = SwiftcDiagnostics.parse(result.combinedOutput, root: workspace.root)
            let fallback = AWError.toolFailed(tool: "swiftc", status: result.status, output: String(result.combinedOutput.suffix(1500))).issue
            outcome.issues += parsed.isEmpty ? [fallback] : parsed
            return nil
        }
        try key.write(to: stamp, atomically: true, encoding: .utf8)
        return binary
    }

    private func renderArguments(_ widget: WidgetSource, _ request: PreviewRequest, output: URL) -> [String] {
        let families = request.families ?? widget.manifest.families
        var arguments = [
            "render", "--widget", widget.id, "--out", output.path,
            "--families", families.map(\.rawValue).joined(separator: ","),
            "--language", request.language.rawValue
        ]
        for (name, url) in scenarios(of: widget, request: request) {
            arguments += ["--scenario", "\(name)=\(url.path)"]
        }
        if request.full {
            arguments.append("--full")
        }
        let images = widget.directory.appendingPathComponent("samples/images", isDirectory: true)
        if FileManager.default.fileExists(atPath: images.path) {
            arguments += ["--images", images.path]
        }
        return arguments
    }

    private func scenarios(of widget: WidgetSource, request: PreviewRequest) -> [(String, URL)] {
        widget.samples
            .filter { !$0.key.contains(".") }
            .filter { request.scenarios?.contains($0.key) ?? true }
            .sorted { $0.key < $1.key }
            .map { ($0.key, $0.value) }
    }
}
