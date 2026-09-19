import AWSchema
import CoreGraphics
import Foundation
import ImageIO

public struct ShotRecord: Codable, Equatable, Sendable {
    public var label: String
    public var window: WidgetWindow
    public var path: String
    public var settled: Bool
}

public struct ShotTarget: Equatable, Sendable {
    public var label: String
    public var names: [String]
    public var descriptor: String

    public static func descriptor(_ config: WorkspaceConfig, kind: String) -> String {
        "::\(config.extensionBundleID):\(kind)"
    }

    public static func dev(_ config: WorkspaceConfig) -> ShotTarget {
        ShotTarget(
            label: RegistryGenerator.devKind,
            names: [config.devSlotName],
            descriptor: descriptor(config, kind: RegistryGenerator.devKind)
        )
    }

    public static func resolve(_ workspace: Workspace, kind: String?, dev: Bool) throws -> [ShotTarget] {
        let config = workspace.config
        if dev || kind == RegistryGenerator.devKind {
            return [Self.dev(config)]
        }
        let manifests = try workspace.widgets().map(\.manifest)
        let targets = manifests.map {
            ShotTarget(label: $0.resolvedKind, names: $0.name.all, descriptor: descriptor(config, kind: $0.resolvedKind))
        }
        guard let kind else {
            return targets + [Self.dev(config)]
        }
        guard let index = manifests.firstIndex(where: { $0.resolvedKind == kind || $0.id == kind }) else {
            throw AWError.widgetNotFound(kind)
        }
        return [targets[index]]
    }
}

public struct Capture: Sendable {
    public let runner: any ProcessRunning

    public init(runner: any ProcessRunning) {
        self.runner = runner
    }

    public func shot(_ window: WidgetWindow, to url: URL) async -> Bool {
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let result = try? await runner.run(
            "/usr/sbin/screencapture",
            ["-x", "-o", "-l", String(window.id), url.path],
            cwd: nil,
            environment: nil,
            timeout: 30
        )
        return result?.succeeded == true && FileManager.default.fileExists(atPath: url.path)
    }

    /// The captured window as an encoded image; `FrameDiff` compares such frames by picture.
    public func frame(_ window: WidgetWindow, to url: URL) async -> Data? {
        guard await shot(window, to: url) else { return nil }
        return try? Data(contentsOf: url)
    }

    /// Waits until two consecutive frames show the same picture and it differs from `baseline`; a running timer counts as neither. Nil on timeout.
    public static func settle(baseline: Data?, timeout: TimeInterval, interval: TimeInterval, frame: () async -> Data?) async -> Data? {
        let deadline = Date().addingTimeInterval(timeout)
        var previous: Data?
        while true {
            if Task.isCancelled {
                return nil
            }
            if let current = await frame() {
                if let previous, FrameDiff.alike(previous, current), FrameDiff.differs(current, from: baseline, steadiedBy: previous) {
                    return current
                }
                previous = current
            } else {
                previous = nil
            }
            if Date() >= deadline {
                return nil
            }
            if interval > 0 {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }
}

public struct Shooter: Sendable {
    public let directory: URL
    public let capture: Capture

    public init(directory: URL, capture: Capture) {
        self.directory = directory
        self.capture = capture
    }

    public func file(for label: String, window: WidgetWindow, now: Date = Date()) -> URL {
        let family = window.family?.rawValue ?? "window"
        return directory.appendingPathComponent("\(label)-\(family)-\(window.id)-\(Stamp.string(now)).png")
    }

    public func take(_ windows: [WidgetWindow], label: String) async -> [ShotRecord] {
        var records: [ShotRecord] = []
        for window in windows {
            let url = file(for: label, window: window)
            if await capture.shot(window, to: url) {
                records.append(ShotRecord(label: label, window: window, path: url.path, settled: true))
            }
        }
        return records
    }

    public func baselines(_ windows: [WidgetWindow]) async -> [Int: Data] {
        var frames: [Int: Data] = [:]
        for window in windows {
            let scratch = directory.appendingPathComponent(".baseline-\(window.id).png")
            if let frame = await capture.frame(window, to: scratch) {
                frames[window.id] = frame
            }
        }
        return frames
    }

    public func settle(_ windows: [WidgetWindow], label: String, baselines: [Int: Data], timeout: TimeInterval) async -> [ShotRecord] {
        var records: [ShotRecord] = []
        for window in windows {
            let url = file(for: label, window: window)
            let frame = await Capture.settle(baseline: baselines[window.id], timeout: timeout, interval: 1) {
                await capture.frame(window, to: url)
            }
            if FileManager.default.fileExists(atPath: url.path) {
                records.append(ShotRecord(label: label, window: window, path: url.path, settled: frame != nil))
            }
        }
        return records
    }
}

public enum ShotIssues {
    public static func screenRecording(_ severity: Issue.Severity) -> Issue {
        Issue(
            code: IssueCode.screenRecordingDenied,
            severity: severity,
            message: L10n.pick(
                en: "No Screen Recording access, so real widget windows cannot be captured",
                ru: "Нет доступа к записи экрана — снять реальные окна виджетов нельзя"
            ),
            hint: L10n.pick(
                en: "System Settings → Privacy & Security → Screen Recording → enable the app that runs aw (Terminal, iTerm, Claude…), then restart it",
                ru: "Системные настройки → Конфиденциальность и безопасность → Запись экрана → включи приложение, из которого запускается aw "
                    + "(Терминал, iTerm, Claude…), и перезапусти его"
            )
        )
    }

    public static func notPlaced(_ name: String, appName: String) -> Issue {
        Issue(
            code: IssueCode.widgetNotPlaced,
            severity: .warning,
            message: L10n.pick(en: "“\(name)” is not on the desktop, so there is nothing to capture", ru: "«\(name)» нет на столе — снимать нечего"),
            hint: L10n.pick(
                en: "Right-click the desktop → Edit Widgets → search “\(appName)” → add “\(name)”, "
                    + "then run `aw slot` (it waits until the slot appears)",
                ru: "Правый клик по столу → «Изменить виджеты» → найди «\(appName)» → добавь «\(name)», "
                    + "затем `aw slot` (ждёт, пока слот появится)"
            )
        )
    }

    public static func hidden(_ name: String, families: [Family]) -> Issue {
        let sizes = families.isEmpty ? "" : " (\(families.map(\.rawValue).joined(separator: ", ")))"
        return Issue(
            code: IssueCode.widgetHidden,
            severity: .warning,
            message: L10n.pick(
                en: "“\(name)”\(sizes) is not visible — covered by windows, on another Space or no longer on the desktop — "
                    + "so macOS does not draw it and a screenshot would be empty",
                ru: "«\(name)»\(sizes) не виден — закрыт окнами, на другом Space или уже не на столе — "
                    + "macOS его не рисует, снимок был бы пустым"
            ),
            hint: L10n.pick(
                en: "Ask the person to show the desktop and, if the slot is gone, add it again (right-click the desktop → Edit Widgets); "
                    + "then run `aw slot` — it waits until the slot is visible and captures it",
                ru: "Попроси человека показать рабочий стол и, если слота нет, добавить его снова (правый клик по столу → «Изменить виджеты»); "
                    + "затем `aw slot` — он дождётся, пока слот станет виден, и снимет его"
            )
        )
    }

    public static func unchanged(after seconds: TimeInterval) -> Issue {
        Issue(
            code: IssueCode.shotUnchanged,
            severity: .warning,
            message: L10n.pick(
                en: "The dev slot looked the same for \(Int(seconds)) s after the install",
                ru: "Dev-слот не изменился за \(Int(seconds)) с после установки"
            ),
            hint: L10n.pick(
                en: "If the change was visual, the widget has not redrawn yet: run `aw shot --dev` again or `aw install --hard`",
                ru: "Если правка видимая — виджет ещё не перерисовался: повтори `aw shot --dev` или `aw install --hard`"
            )
        )
    }
}
