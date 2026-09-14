import AWSchema
import Foundation

public struct FeedRun: Codable, Sendable {
    public var widget: String
    public var ok: Bool
    public var changed: Bool
    public var seconds: Double
    public var issues: [Issue]
}

public struct FeedRunner: Sendable {
    public static let logLimit = 1_000_000

    public let workspace: Workspace
    public let store: AppGroupStore
    public let runner: any ProcessRunning
    public let language: Language

    public init(workspace: Workspace, store: AppGroupStore, runner: any ProcessRunning, language: Language = L10n.language) {
        self.workspace = workspace
        self.store = store
        self.runner = runner
        self.language = language
    }

    public func logFile(for id: String) -> URL {
        workspace.logsDir.appendingPathComponent("\(id).log")
    }

    public func environment(for widget: WidgetSource) -> [String: String] {
        let id = widget.id
        let settings = (try? widget.manifest.settings?.canonicalData()).flatMap { String(bytes: $0, encoding: .utf8) } ?? "{}"
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let inherited = ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        var values = [
            "AW_WIDGET_ID": id,
            "AW_LANG": language.rawValue,
            "AW_SETTINGS": settings,
            "AW_STATE_PATH": store.url(AppGroupLayout.state(id)).path,
            "AW_PREVIOUS_PATH": store.url(AppGroupLayout.data(id)).path,
            "AW_IMAGES_DIR": store.url(AppGroupLayout.widgetDirectory(id) + "/images").path,
            "PATH": "/opt/homebrew/bin:/usr/local/bin:\(home)/.local/bin:\(inherited)"
        ]
        for name in widget.manifest.feed?.secrets ?? [] {
            values[name] = workspace.config.secrets?[name]
        }
        return values
    }

    /// Runs the feed once; failures keep the last good data and mark the status stale.
    public func run(_ widget: WidgetSource, now: Date = Date(), validate: (@Sendable (Data) async -> Issue?)? = nil) async -> FeedRun {
        let started = Date()
        guard let feed = widget.manifest.feed else {
            return FeedRun(widget: widget.id, ok: false, changed: false, seconds: 0, issues: [Self.noFeed(widget.id)])
        }
        let missing = (feed.secrets ?? []).filter { (workspace.config.secrets?[$0] ?? "").isEmpty }
        guard missing.isEmpty else {
            return fail(widget, started: started, now: now, issue: Self.missingSecrets(widget.id, missing))
        }
        let images = store.url(AppGroupLayout.widgetDirectory(widget.id) + "/images")
        try? FileManager.default.createDirectory(at: images, withIntermediateDirectories: true)
        let feedEnvironment = environment(for: widget)
        let result: ProcessResult
        do {
            result = try await runner.run(
                "/bin/zsh",
                ["-c", feed.command],
                cwd: widget.directory,
                environment: feedEnvironment,
                timeout: TimeInterval(feed.resolvedTimeout.seconds)
            )
        } catch {
            return fail(widget, started: started, now: now, issue: Self.issue(
                IssueCode.feedFailed,
                en: "The feed of \(widget.id) could not start: \(error.localizedDescription)",
                ru: "Feed виджета \(widget.id) не запустился: \(error.localizedDescription)",
                hint: Self.runHint(widget.id)
            ))
        }
        appendLog(widget.id, result: result, now: now)
        let path = feedEnvironment["PATH"] ?? ""
        if let failure = Self.failure(of: result, widget: widget.id, command: feed.command, path: path, timeout: feed.resolvedTimeout.seconds) {
            return fail(widget, started: started, now: now, issue: failure, result: result)
        }
        let output = Data(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines).utf8)
        guard case .object? = try? JSONDecoder().decode(JSONValue.self, from: output) else {
            return fail(widget, started: started, now: now, issue: Self.invalidOutput(widget.id, result.stdout), result: result)
        }
        if let validate, let issue = await validate(output) {
            return fail(widget, started: started, now: now, issue: issue, result: result)
        }
        return publish(output, widget: widget, started: started, now: now)
    }

    private func publish(_ output: Data, widget: WidgetSource, started: Date, now: Date) -> FeedRun {
        do {
            let changed = try store.publish(output, widget: widget.id)
            try store.writeStatus(FeedStatus(ok: true, checkedAt: now, fetchedAt: now), widget: widget.id)
            return FeedRun(widget: widget.id, ok: true, changed: changed, seconds: Date().timeIntervalSince(started), issues: [])
        } catch {
            return fail(widget, started: started, now: now, issue: Self.issue(
                IssueCode.feedFailed,
                en: "Could not write the data of \(widget.id): \(error.localizedDescription)",
                ru: "Не удалось записать данные \(widget.id): \(error.localizedDescription)",
                hint: L10n.pick(en: "Run `aw doctor` to check the App Group", ru: "Проверь App Group: `aw doctor`")
            ))
        }
    }

    static func missingSecrets(_ id: String, _ names: [String]) -> Issue {
        let list = names.joined(separator: ", ")
        let example = names.map { "\"\($0)\": \"…\"" }.joined(separator: ", ")
        return issue(
            IssueCode.feedSecretMissing,
            en: "The feed of \(id) needs \(list), but aw.local.json has no value for it",
            ru: "Feed виджета \(id) нужен \(list), но в aw.local.json для него нет значения",
            hint: L10n.pick(
                en: "Add \"secrets\": {\(example)} to aw.local.json — it stays on this Mac and out of git",
                ru: "Добавь в aw.local.json \"secrets\": {\(example)} — файл остаётся на этом маке и не попадает в git"
            )
        )
    }

    private func fail(_ widget: WidgetSource, started: Date, now: Date, issue: Issue, result: ProcessResult? = nil) -> FeedRun {
        let previous = store.status(widget: widget.id)
        let status = FeedStatus(
            ok: false,
            checkedAt: now,
            fetchedAt: previous?.fetchedAt,
            error: issue.message,
            exitCode: result?.status,
            stderrTail: result.map { Self.tail($0.stderr) }
        )
        try? store.writeStatus(status, widget: widget.id)
        return FeedRun(widget: widget.id, ok: false, changed: false, seconds: Date().timeIntervalSince(started), issues: [issue])
    }

    static func tail(_ stderr: String, lines: Int = 5) -> [String] {
        Array(stderr.split(whereSeparator: \.isNewline).map(String.init).suffix(lines))
    }

    private func appendLog(_ id: String, result: ProcessResult, now: Date) {
        let flags = result.timedOut ? " timeout" : ""
        var text = "=== \(ISO8601DateFormatter().string(from: now)) exit \(result.status)\(flags) \(String(format: "%.1f", result.duration)) s\n"
        if !result.stderr.isEmpty {
            text += result.stderr.hasSuffix("\n") ? result.stderr : result.stderr + "\n"
        }
        LogFile.append(text, to: logFile(for: id), limit: Self.logLimit)
    }

    static func failure(of result: ProcessResult, widget id: String, command: String, path: String, timeout: Int) -> Issue? {
        if result.timedOut {
            return issue(
                IssueCode.feedTimeout,
                en: "The feed of \(id) ran longer than \(timeout) s and was stopped",
                ru: "Feed виджета \(id) работал дольше \(timeout) с и был остановлен",
                hint: L10n.pick(
                    en: "Make it faster or raise \"timeout\" in the feed section of widget.json, for example \"2m\"",
                    ru: "Ускорь его или подними \"timeout\" в секции feed в widget.json, например \"2m\""
                )
            )
        }
        if result.status == 126 || result.status == 127 {
            return commandIssue(result, widget: id, command: command, path: path)
        }
        guard result.status == 0 else {
            let tail = result.stderr.split(whereSeparator: \.isNewline).suffix(3).joined(separator: " · ")
            let detail = tail.isEmpty ? "" : ": \(tail)"
            return issue(
                IssueCode.feedFailed,
                en: "The feed of \(id) exited with \(result.status)\(detail)",
                ru: "Feed виджета \(id) завершился с кодом \(result.status)\(detail)",
                hint: runHint(id)
            )
        }
        return nil
    }

    static func commandIssue(_ result: ProcessResult, widget id: String, command: String, path: String) -> Issue {
        let denied = result.status == 126
        let name = missingName(in: result.stderr, denied: denied) ?? command.split(separator: " ").first.map(String.init) ?? command
        guard !denied else {
            return issue(
                IssueCode.feedCommandNotFound,
                en: "The feed of \(id) is not allowed to run `\(name)` (exit 126)",
                ru: "Feed виджета \(id) не может запустить `\(name)`: нет прав (код 126)",
                hint: L10n.pick(
                    en: "Make it executable with `chmod +x \(name)`, or call it through its interpreter, for example `python3 \(name)`",
                    ru: "Сделай файл исполняемым: `chmod +x \(name)` — или вызывай через интерпретатор, например `python3 \(name)`"
                )
            )
        }
        return issue(
            IssueCode.feedCommandNotFound,
            en: "The feed of \(id) could not find `\(name)` (exit 127)",
            ru: "Feed виджета \(id) не нашёл `\(name)` (код 127)",
            hint: L10n.pick(
                en: "Install it or write its full path in widget.json; feeds run with PATH=\(path)",
                ru: "Установи его или впиши полный путь в widget.json; feed запускается с PATH=\(path)"
            )
        )
    }

    static func missingName(in stderr: String, denied: Bool) -> String? {
        let patterns = denied
            ? [#"permission denied: (\S+)"#, #"(\S+): [Pp]ermission denied"#]
            : [#"command not found: (\S+)"#, #"(\S+): command not found"#, #"(\S+): not found"#]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: stderr, range: NSRange(stderr.startIndex..., in: stderr)),
                  let range = Range(match.range(at: 1), in: stderr)
            else {
                continue
            }
            return String(stderr[range])
        }
        return nil
    }

    static func invalidOutput(_ id: String, _ stdout: String) -> Issue {
        let sample = stdout.trimmingCharacters(in: .whitespacesAndNewlines).prefix(120)
        return issue(
            IssueCode.feedInvalidOutput,
            en: "The feed of \(id) printed something that is not a JSON object: \(sample)",
            ru: "Feed виджета \(id) напечатал не JSON-объект: \(sample)",
            hint: L10n.pick(
                en: "Print exactly one JSON object shaped like the model, or {\"timeline\": [{\"date\": …, \"data\": {…}}]}; send logs to stderr",
                ru: "Печатай ровно один JSON-объект в форме модели или {\"timeline\": [{\"date\": …, \"data\": {…}}]}; логи — в stderr"
            )
        )
    }

    static func noFeed(_ id: String) -> Issue {
        issue(
            IssueCode.feedFailed,
            en: "Widget \(id) has no feed in widget.json",
            ru: "У виджета \(id) нет feed в widget.json",
            hint: L10n.pick(
                en: "Add \"feed\": {\"command\": \"./feed.py\", \"every\": \"15m\"} or push data with `aw data set \(id) '{…}'`",
                ru: "Добавь \"feed\": {\"command\": \"./feed.py\", \"every\": \"15m\"} или пушни данные: `aw data set \(id) '{…}'`"
            )
        )
    }

    private static func runHint(_ id: String) -> String {
        L10n.pick(
            en: "Try it by hand with `aw feed run \(id)`; stderr is in `aw logs \(id)`",
            ru: "Запусти руками `aw feed run \(id)`; stderr — в `aw logs \(id)`"
        )
    }

    private static func issue(_ code: String, en: String, ru: String, hint: String) -> Issue {
        Issue(code: code, severity: .error, message: L10n.pick(en: en, ru: ru), hint: hint)
    }
}

public enum LogFile {
    public static func append(_ text: String, to url: URL, limit: Int) {
        let fileManager = FileManager.default
        try? fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let size = (try? fileManager.attributesOfItem(atPath: url.path))?[.size] as? Int, size > limit {
            let archive = url.appendingPathExtension("1")
            try? fileManager.removeItem(at: archive)
            try? fileManager.moveItem(at: url, to: archive)
        }
        guard let handle = try? FileHandle(forWritingTo: url) else {
            try? Data(text.utf8).write(to: url)
            return
        }
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: Data(text.utf8))
    }

    public static func tail(_ url: URL, lines: Int) -> [String]? {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return Array(text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init).dropLast(text.hasSuffix("\n") ? 1 : 0).suffix(lines))
    }
}
