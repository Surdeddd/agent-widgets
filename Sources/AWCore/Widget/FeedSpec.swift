import AWSchema

public struct FeedSpec: Codable, Equatable, Sendable {
    public static let defaultTimeout = Interval(seconds: 60)

    public var command: String
    public var every: Interval
    public var timeout: Interval?

    public init(command: String, every: Interval, timeout: Interval? = nil) {
        self.command = command
        self.every = every
        self.timeout = timeout
    }

    public var resolvedTimeout: Interval {
        timeout ?? Self.defaultTimeout
    }
}
