import Foundation
import MCP

actor ProgressReporter {
    typealias Send = @Sendable (ProgressNotification.Parameters) async -> Void

    static let silent = ProgressReporter(token: nil) { _ in }

    private let token: ProgressToken?
    private let send: Send
    private var last: Double = 0

    init(token: ProgressToken?, send: @escaping Send) {
        self.token = token
        self.send = send
    }

    /// Sends a progress notification when the caller asked for them; the progress value follows `elapsed` and never goes back.
    func report(_ message: String, elapsed: TimeInterval) async {
        guard let token else { return }
        last = max(last + 0.001, elapsed)
        await send(ProgressNotification.Parameters(progressToken: token, progress: last, message: message))
    }
}

actor ClientProfile {
    private(set) var name: String?

    func set(_ name: String) {
        self.name = name
    }
}
