import ArgumentParser
import AWCore
import AWSchema
import Foundation

struct SlotCommand: AWCommand {
    static let configuration = CommandConfiguration(
        commandName: "slot",
        abstract: L10n.pick(
            en: "Wait until the person puts the dev slot on the desktop, then capture it.",
            ru: "Подождать, пока человек поставит dev-слот на стол, и снять его."
        )
    )

    @OptionGroup var global: GlobalOptions

    @Option(help: ArgumentHelp(L10n.pick(
        en: "Families that must be on the desktop, comma separated.",
        ru: "Размеры, которые должны быть на столе, через запятую."
    )))
    var family: String?

    @Option(help: ArgumentHelp(L10n.pick(en: "Seconds to wait for the slot.", ru: "Сколько секунд ждать слот.")))
    var timeout: Double = 600

    func execute() async throws -> Int32 {
        guard WindowLocator.screenRecordingAllowed else {
            global.printer.emit(CommandResult<NoPayload>(issues: [ShotIssues.screenRecording(.error)])) { _ in "" }
            return 3
        }
        let workspace = try global.loadWorkspace()
        let families = Set((family ?? "").split(separator: ",").compactMap { Family(rawValue: String($0)) })
        let config = workspace.config
        Console.note(Self.instruction(slot: config.devSlotName, app: config.appName, families: families, timeout: timeout))
        let windows = await SlotWaiter(families: families, timeout: timeout).wait(
            target: ShotTarget.dev(config),
            locate: { WindowLocator.current() },
            sleep: Self.pause
        )
        guard let windows else {
            let issue = SlotIssues.timeout(
                seconds: timeout,
                slot: config.devSlotName,
                appName: config.appName,
                families: families
            )
            global.printer.emit(CommandResult<NoPayload>(issues: [issue])) { _ in "" }
            return 1
        }
        let runner = SystemProcessRunner()
        var issues: [Issue] = []
        if GeometryStore.load() == nil {
            if let measured = await GeometryProbe.measure(runner: runner) {
                try GeometryStore.save(measured)
            } else {
                issues.append(GeometryIssues.unknown)
            }
        }
        if AppGroupStore(config: config).devTarget() != nil {
            await Reloader(config: config, runner: runner).reload(kind: RegistryGenerator.devKind)
            await Self.pause(2)
        }
        let capture = try await ShotService.capture(workspace, kind: nil, dev: true, runner: runner)
        let review = ShotCompare.review(
            capture.records,
            workspace: workspace,
            target: AppGroupStore(config: config).devTarget()
        )
        issues += capture.issues + review.issues
        let payload = SlotResult(windows: windows, shots: capture.records, comparisons: review.comparisons)
        let artifacts = payload.shots.map(\.path) + payload.comparisons.map(\.image)
        global.printer.emit(CommandResult(issues: issues, artifacts: artifacts, data: payload), human: Self.human)
        return 0
    }

    static func pause(_ seconds: TimeInterval) async {
        guard seconds > 0 else { return }
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    static func instruction(slot: String, app: String, families: Set<Family>, timeout: TimeInterval) -> String {
        let sizes = SlotIssues.list(families)
        let seconds = Int(timeout)
        return L10n.pick(
            en: "Add “\(slot)” to the desktop — right-click the desktop → Edit Widgets → search “\(app)” "
                + "→ add “\(slot)” in \(sizes). Waiting up to \(seconds) s.",
            ru: "Поставь «\(slot)» на стол — правый клик по столу → «Изменить виджеты» → найди «\(app)» "
                + "→ добавь «\(slot)» в \(sizes). Жду до \(seconds) с."
        )
    }

    static func human(_ payload: SlotResult?) -> String {
        guard let payload else { return "" }
        let placed = payload.windows.map { $0.family?.rawValue ?? "?" }
        let shots = payload.shots.map { "✓ \($0.label) \($0.window.family?.rawValue ?? "?") → \($0.path)" }
        return (placed + shots + payload.comparisons.map(\.summary)).joined(separator: "\n")
    }
}

struct SlotResult: Codable {
    var windows: [WidgetWindow]
    var shots: [ShotRecord]
    var comparisons: [ShotComparison]
}
