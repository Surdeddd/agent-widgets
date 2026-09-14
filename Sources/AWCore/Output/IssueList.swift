import AWSchema

extension Array where Element == Issue {
    public func deduplicated() -> [Issue] {
        var seen = Set<String>()
        return filter { seen.insert("\($0.code)|\($0.message)|\($0.file ?? "")").inserted }
    }
}

extension Issue {
    public var downgraded: Issue {
        var copy = self
        if copy.severity == .error {
            copy.severity = .warning
        }
        return copy
    }

    public var upgraded: Issue {
        var copy = self
        copy.severity = .error
        return copy
    }
}
