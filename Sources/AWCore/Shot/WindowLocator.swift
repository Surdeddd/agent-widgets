import AppKit
import AWSchema
import CoreGraphics
import Foundation

public struct WidgetWindow: Codable, Equatable, Sendable {
    public var id: Int
    public var name: String
    public var width: Int
    public var height: Int
    public var family: Family?
}

public enum WindowLocator {
    public static let ownerBundleID = "com.apple.notificationcenterui"

    public static var screenRecordingAllowed: Bool {
        CGPreflightScreenCaptureAccess()
    }

    public static func current() -> [WidgetWindow] {
        let owners = Set(NSRunningApplication.runningApplications(withBundleIdentifier: ownerBundleID).map(\.processIdentifier))
        let info = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] ?? []
        return parse(info, owners: owners, geometry: GeometryStore.current())
    }

    public static func parse(_ info: [[String: Any]], owners: Set<Int32>, geometry: DeskGeometry = .fallback) -> [WidgetWindow] {
        info.compactMap { window -> WidgetWindow? in
            guard let owner = number(window[kCGWindowOwnerPID as String]), owners.contains(Int32(owner)),
                  let layer = number(window[kCGWindowLayer as String]), layer < 0,
                  let id = number(window[kCGWindowNumber as String]),
                  let bounds = window[kCGWindowBounds as String] as? [String: Any],
                  let width = number(bounds["Width"]),
                  let height = number(bounds["Height"])
            else {
                return nil
            }
            return WidgetWindow(
                id: id,
                name: window[kCGWindowName as String] as? String ?? "",
                width: width,
                height: height,
                family: Family.nearest(windowSize: CGSize(width: width, height: height), in: geometry)
            )
        }
        .sorted { $0.id < $1.id }
    }

    public static func find(_ windows: [WidgetWindow], names: [String], descriptor: String) -> [WidgetWindow] {
        windows.filter { names.contains($0.name) || $0.name.hasSuffix(descriptor) }
    }

    public static func namesHidden(_ windows: [WidgetWindow]) -> Bool {
        !windows.isEmpty && windows.allSatisfy { $0.name.isEmpty }
    }

    private static func number(_ value: Any?) -> Int? {
        (value as? NSNumber)?.intValue
    }
}
