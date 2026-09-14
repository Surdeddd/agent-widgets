import AWSchema
import Foundation

extension Doctor {
    public func workspaceChecks(
        _ workspace: Workspace,
        paths: InstallPaths,
        screenRecording: Bool,
        windows: [WidgetWindow],
        geometry: DeskGeometry?,
        now: Date = Date()
    ) async -> [DoctorCheck] {
        let config = workspace.config
        let installer = Installer(config: config, runner: runner, paths: paths)
        let installed = Installer.bundleID(of: installer.target) == config.appBundleID
        var checks = [screenCheck(screenRecording), appCheck(installer.target, installed: installed)]
        if installed {
            checks.append(await extensionCheck(installer))
        }
        checks.append(devSlotCheck(config, screenRecording: screenRecording, windows: windows))
        checks.append(geometryCheck(geometry))
        if (try? workspace.widgets())?.contains(where: { $0.manifest.feed != nil }) == true {
            checks.append(await daemonCheck(workspace))
            checks += feedChecks(workspace, store: AppGroupStore(root: paths.groupContainer), now: now)
        }
        return checks
    }

    func geometryCheck(_ geometry: DeskGeometry?) -> DoctorCheck {
        let title = L10n.pick(en: "Desktop sizes", ru: "Размеры на столе")
        guard let geometry else {
            return DoctorCheck(
                id: "geometry",
                title: title,
                status: .warn,
                detail: L10n.pick(en: "not measured — previews use built-in sizes", ru: "не сняты — превью рисует по встроенным размерам"),
                issue: GeometryIssues.unknown
            )
        }
        let sizes = [Family.small, .medium, .large].map { family in
            let size = geometry.size(of: family)
            return "\(family.rawValue) \(Int(size.width.rounded()))×\(Int(size.height.rounded()))"
        }
        return DoctorCheck(id: "geometry", title: title, status: .pass, detail: sizes.joined(separator: " · "))
    }

    func daemonCheck(_ workspace: Workspace) async -> DoctorCheck {
        let title = L10n.pick(en: "Feed daemon", ru: "Daemon feed")
        let status = await Daemon(workspace: workspace, runner: runner).status()
        guard status.loaded else {
            return DoctorCheck(
                id: "daemon",
                title: title,
                status: .warn,
                detail: L10n.pick(en: "not installed", ru: "не установлен"),
                issue: Issue(
                    code: IssueCode.daemonMissing,
                    severity: .warning,
                    message: L10n.pick(
                        en: "Widgets have feeds, but nothing runs them on schedule",
                        ru: "У виджетов есть feed, но их никто не запускает по расписанию"
                    ),
                    hint: "aw daemon install"
                )
            )
        }
        return DoctorCheck(id: "daemon", title: title, status: .pass, detail: status.label)
    }

    func screenCheck(_ allowed: Bool) -> DoctorCheck {
        let title = L10n.pick(en: "Screen Recording", ru: "Запись экрана")
        guard allowed else {
            return DoctorCheck(
                id: "screen-recording",
                title: title,
                status: .warn,
                detail: L10n.pick(en: "denied — aw shot cannot see widgets", ru: "нет доступа — aw shot не увидит виджеты"),
                issue: ShotIssues.screenRecording(.warning)
            )
        }
        return DoctorCheck(id: "screen-recording", title: title, status: .pass, detail: L10n.pick(en: "allowed", ru: "есть"))
    }

    func appCheck(_ target: URL, installed: Bool) -> DoctorCheck {
        let title = L10n.pick(en: "Widget app", ru: "Приложение")
        guard installed else {
            return DoctorCheck(
                id: "app",
                title: title,
                status: .warn,
                detail: L10n.pick(en: "not installed yet", ru: "ещё не установлено"),
                issue: Issue(
                    code: IssueCode.installFailed,
                    severity: .warning,
                    message: L10n.pick(en: "\(target.path) is not installed", ru: "\(target.path) не установлено"),
                    hint: L10n.pick(en: "`aw ship <id>` builds and installs it", ru: "`aw ship <id>` соберёт и установит")
                )
            )
        }
        return DoctorCheck(id: "app", title: title, status: .pass, detail: target.path)
    }

    func extensionCheck(_ installer: Installer) async -> DoctorCheck {
        let title = L10n.pick(en: "Extension", ru: "Расширение")
        let identifier = installer.config.extensionBundleID
        guard await installer.isRegistered() else {
            return DoctorCheck(
                id: "extension",
                title: title,
                status: .warn,
                detail: L10n.pick(en: "\(identifier) is not registered", ru: "\(identifier) не зарегистрировано"),
                issue: Issue(
                    code: IssueCode.installFailed,
                    severity: .warning,
                    message: L10n.pick(
                        en: "macOS does not list the widget extension \(identifier)",
                        ru: "macOS не видит расширение виджетов \(identifier)"
                    ),
                    hint: L10n.pick(en: "Run `aw install --hard`", ru: "Запусти `aw install --hard`")
                )
            )
        }
        return DoctorCheck(id: "extension", title: title, status: .pass, detail: identifier)
    }

    func devSlotCheck(_ config: WorkspaceConfig, screenRecording: Bool, windows: [WidgetWindow]) -> DoctorCheck {
        let title = L10n.pick(en: "Dev slot", ru: "Dev-слот")
        guard screenRecording else {
            return DoctorCheck(
                id: "dev-slot",
                title: title,
                status: .warn,
                detail: L10n.pick(en: "unknown without Screen Recording", ru: "не проверить без записи экрана")
            )
        }
        let target = ShotTarget.dev(config)
        let placed = WindowLocator.find(windows, names: target.names, descriptor: target.descriptor)
        guard !placed.isEmpty else {
            return DoctorCheck(
                id: "dev-slot",
                title: title,
                status: .warn,
                detail: L10n.pick(en: "not on the desktop", ru: "нет на столе"),
                issue: ShotIssues.notPlaced(config.devSlotName, appName: config.appName)
            )
        }
        let families = placed.map { $0.family?.rawValue ?? "\($0.width)×\($0.height)" }.joined(separator: ", ")
        return DoctorCheck(id: "dev-slot", title: title, status: .pass, detail: families)
    }
}
