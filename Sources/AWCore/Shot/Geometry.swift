import AWSchema
import Foundation

public enum GeometryProbe {
    /// Reads widget sizes from chronod log lines such as `:systemSmall::164.00/164.00/27.88`.
    public static func parseChronod(_ log: String, now: Date = Date()) -> DeskGeometry? {
        let pattern = #":system(Small|Medium|Large|ExtraLarge)::([0-9.]+)/([0-9.]+)/([0-9.]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        var counts: [String: [String: Int]] = [:]
        var radii: [String: Int] = [:]
        let range = NSRange(log.startIndex..., in: log)
        for match in regex.matches(in: log, range: range) {
            let parts = (1...4).compactMap { Range(match.range(at: $0), in: log).map { String(log[$0]) } }
            guard parts.count == 4 else { continue }
            counts[parts[0], default: [:]]["\(parts[1])x\(parts[2])", default: 0] += 1
            radii[parts[3], default: 0] += 1
        }
        func size(_ family: String) -> CGSize? {
            guard let key = counts[family]?.max(by: { $0.value < $1.value })?.key else { return nil }
            let numbers = key.split(separator: "x").compactMap { Double($0) }
            return numbers.count == 2 ? CGSize(width: numbers[0], height: numbers[1]) : nil
        }
        guard let small = size("Small"), let medium = size("Medium"), let large = size("Large"),
              let radius = radii.max(by: { $0.value < $1.value }).flatMap({ Double($0.key) })
        else {
            return nil
        }
        let gap = max(medium.width - 2 * small.width, 0)
        let extraLarge = size("ExtraLarge") ?? CGSize(width: 2 * large.width + gap, height: large.height)
        return DeskGeometry(small: small, medium: medium, large: large, extraLarge: extraLarge, cornerRadius: radius, source: "chronod", measuredAt: now)
    }

    public static func measure(runner: any ProcessRunning, now: Date = Date()) async -> DeskGeometry? {
        for window in ["2h", "1d"] {
            let arguments = ["show", "--last", window, "--style", "compact", "--predicate", #"process == "chronod" AND composedMessage CONTAINS ":system""#]
            let result = try? await runner.run("/usr/bin/log", arguments, cwd: nil, environment: nil, timeout: 180)
            if let result, result.succeeded, let geometry = parseChronod(result.stdout, now: now) {
                return geometry
            }
        }
        return nil
    }
}

public enum GeometryIssues {
    public static var unknown: Issue {
        Issue(
            code: IssueCode.geometryUnknown,
            severity: .warning,
            message: L10n.pick(
                en: "Could not read widget sizes from the system log; previews use the built-in sizes",
                ru: "Не удалось прочитать размеры виджетов из системного лога; превью рисует по встроенным размерам"
            ),
            hint: L10n.pick(
                en: "Put any widget on the desktop, then run aw geometry --measure",
                ru: "Поставь любой виджет на стол и запусти aw geometry --measure"
            )
        )
    }
}

public enum GeometryStore {
    public static func url(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
        home.appendingPathComponent("Library/Application Support/agent-widgets/geometry.json")
    }

    public static func load(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> DeskGeometry? {
        guard let data = try? Data(contentsOf: url(home: home)) else { return nil }
        return try? JSONDecoder().decode(DeskGeometry.self, from: data)
    }

    public static func save(_ geometry: DeskGeometry, home: URL = FileManager.default.homeDirectoryForCurrentUser) throws {
        let target = url(home: home)
        try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(geometry).write(to: target, options: .atomic)
    }

    public static func current(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> DeskGeometry {
        load(home: home) ?? .fallback
    }
}
