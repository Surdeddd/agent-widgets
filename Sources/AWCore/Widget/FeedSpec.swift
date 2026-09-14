import AWSchema

public struct FeedSpec: Codable, Equatable, Sendable {
    public static let defaultTimeout = Interval(seconds: 60)

    public var command: String
    public var every: Interval
    public var timeout: Interval?
    public var secrets: [String]?

    public init(command: String, every: Interval, timeout: Interval? = nil, secrets: [String]? = nil) {
        self.command = command
        self.every = every
        self.timeout = timeout
        self.secrets = secrets
    }

    public var resolvedTimeout: Interval {
        timeout ?? Self.defaultTimeout
    }
}
