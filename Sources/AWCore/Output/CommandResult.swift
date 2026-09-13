import AWSchema

public struct NoPayload: Codable, Equatable, Sendable {
    public init() {}
}

public struct CommandResult<Payload: Encodable & Sendable>: Encodable, Sendable {
    public var ok: Bool
    public var issues: [Issue]
    public var artifacts: [String]
    public var data: Payload?

    public init(issues: [Issue] = [], artifacts: [String] = [], data: Payload? = nil) {
        self.ok = !issues.contains { $0.severity == .error }
        self.issues = issues
        self.artifacts = artifacts
        self.data = data
    }
}
