import ArgumentParser
import AWCore
import AWSchema

struct DoctorCommand: AWCommand {
    static let configuration = CommandConfiguration(
        commandName: "doctor",
        abstract: L10n.pick(
            en: "Check the toolchain, signing and installed widgets.",
            ru: "Проверить тулчейн, подпись и установленные виджеты."
        )
    )

    @OptionGroup var global: GlobalOptions

    func execute() async throws -> Int32 {
        let doctor = Doctor(runner: SystemProcessRunner())
        var checks = await doctor.run()
        if let workspace = try? global.loadWorkspace() {
            let screen = WindowLocator.screenRecordingAllowed
            checks += await doctor.workspaceChecks(
                workspace,
                paths: .standard(for: workspace.config),
                screenRecording: screen,
                windows: screen ? WindowLocator.current() : [],
                geometry: GeometryStore.load()
            )
        }
        let result = CommandResult(issues: checks.compactMap(\.issue), data: checks)
        global.printer.emit(result) { DoctorFormatter.human($0 ?? []) }
        return result.ok ? 0 : 1
    }
}
