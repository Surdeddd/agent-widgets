import AWSchema
import Foundation

public struct SlotWaiter: Sendable {
    public var families: Set<Family>
    public var timeout: TimeInterval
    public var interval: TimeInterval

    public init(families: Set<Family>, timeout: TimeInterval, interval: TimeInterval = 2) {
        self.families = families
        self.timeout = timeout
        self.interval = interval
    }

    /// Polls `locate` until matching windows cover every requested family (an empty set: any one); nil after `timeout`.
    public func wait(
        target: ShotTarget,
        locate: @Sendable () -> [WidgetWindow],
        sleep: @Sendable (TimeInterval) async -> Void,
        now: @Sendable () -> Date = { Date() }
    ) async -> [WidgetWindow]? {
        let deadline = now().addingTimeInterval(timeout)
        while true {
            let found = WindowLocator.find(locate(), names: target.names, descriptor: target.descriptor)
            if covers(found) {
                return found
            }
            if now() >= deadline {
                return nil
            }
            await sleep(interval)
        }
    }

    private func covers(_ windows: [WidgetWindow]) -> Bool {
        if families.isEmpty {
            return !windows.isEmpty
        }
        return families.isSubset(of: Set(windows.compactMap(\.family)))
    }
}

public enum SlotIssues {
    public static func timeout(
        seconds: TimeInterval,
        slot: String,
        appName: String,
        families: Set<Family>
    ) -> Issue {
        let wait = Int(seconds)
        let sizes = list(families)
        return Issue(
            code: IssueCode.slotTimeout,
            severity: .error,
            message: L10n.pick(
                en: "The dev slot did not appear in \(wait) s",
                ru: "Dev-слот не появился за \(wait) с"
            ),
            hint: L10n.pick(
                en: "Right-click the desktop → Edit Widgets → search “\(appName)” → add “\(slot)” in \(sizes)",
                ru: "Правый клик по столу → «Изменить виджеты» → найди «\(appName)» → добавь «\(slot)» в \(sizes)"
            )
        )
    }

    public static func list(_ families: Set<Family>) -> String {
        if families.isEmpty {
            return L10n.pick(en: "any size", ru: "любом размере")
        }
        return Family.allCases.filter { families.contains($0) }.map(\.rawValue).joined(separator: ", ")
    }
}
