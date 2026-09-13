import SwiftUI

public enum AWTick: Sendable, Equatable {
    case none
    case everyMinute(count: Int)
    case every(seconds: Int, count: Int)
}

public protocol AWView: View {
    associatedtype Model: Codable & Sendable
    init(entry: AWEntry<Model>)
    static var tick: AWTick { get }
}

extension AWView {
    public static var tick: AWTick {
        .none
    }
}
