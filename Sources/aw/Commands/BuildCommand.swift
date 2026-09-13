import ArgumentParser
import AWCore
import AWSchema
import Foundation

struct BuildCommand: AWCommand {
    static let configuration = CommandConfiguration(
        commandName: "build",
        abstract: L10n.pick(
            en: "Generate the Xcode project and build the widget app.",
            ru: "Сгенерировать Xcode-проект и собрать приложение с виджетами."
        )
    )

    @OptionGroup var global: GlobalOptions

    @Flag(name: .customLong("no-sign"), help: ArgumentHelp(L10n.pick(en: "Build without code signing (CI).", ru: "Собрать без подписи (для CI).")))
    var noSign = false

    @Option(help: ArgumentHelp(L10n.pick(en: "Xcode configuration.", ru: "Конфигурация Xcode.")))
    var configuration = "Release"

    func execute() async throws -> Int32 {
        let workspace = try global.loadWorkspace()
        let builder = Builder(workspace: workspace, engine: try Engine.current(), runner: SystemProcessRunner())
        let outcome = try await builder.build(sign: !noSign, configuration: configuration)
        let result = CommandResult(issues: outcome.issues, artifacts: [outcome.app, outcome.log].compactMap { $0 }, data: outcome)
        global.printer.emit(result) { outcome in
            guard let outcome else { return "" }
            let seconds = String(format: "%.0f", outcome.seconds)
            if let app = outcome.app {
                return L10n.pick(en: "✓ built in \(seconds) s\n  app: \(app)", ru: "✓ собрано за \(seconds) с\n  app: \(app)")
            }
            return L10n.pick(en: "✗ build failed after \(seconds) s\n  log: \(outcome.log)", ru: "✗ сборка упала через \(seconds) с\n  лог: \(outcome.log)")
        }
        return outcome.app == nil ? 4 : 0
    }
}
