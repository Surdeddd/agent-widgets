import Foundation

public struct SigningIdentity: Codable, Equatable, Sendable {
    public var hash: String
    public var name: String
    public var teamID: String?

    public init(hash: String, name: String, teamID: String? = nil) {
        self.hash = hash
        self.name = name
        self.teamID = teamID
    }
}

public enum SigningDetector {
    public static func parseIdentities(_ output: String) -> [SigningIdentity] {
        output.split(whereSeparator: \.isNewline).compactMap { line in
            guard let match = String(line).firstMatch(of: #/^\s*\d+\)\s+([0-9A-F]{40})\s+"(.+)"\s*$/#) else {
                return nil
            }
            return SigningIdentity(hash: String(match.1), name: String(match.2))
        }
    }

    public static func parseTeamID(subject: String) -> String? {
        subject.firstMatch(of: #/OU\s*=\s*([A-Z0-9]{10})/#).map { String($0.1) }
    }

    public static func preferred(_ identities: [SigningIdentity]) -> SigningIdentity? {
        identities.first { $0.name.hasPrefix("Apple Development:") }
            ?? identities.first { $0.name.hasPrefix("Developer ID Application:") }
            ?? identities.first
    }

    public static func detect(runner: any ProcessRunning) async -> SigningIdentity? {
        guard let listing = try? await runner.run("/usr/bin/security", ["find-identity", "-v", "-p", "codesigning"]),
              listing.succeeded,
              var identity = preferred(parseIdentities(listing.stdout))
        else {
            return nil
        }
        identity.teamID = await teamID(for: identity.name, runner: runner)
        return identity
    }

    private static func teamID(for name: String, runner: any ProcessRunning) async -> String? {
        guard let pem = try? await runner.run("/usr/bin/security", ["find-certificate", "-c", name, "-p"]), pem.succeeded else {
            return nil
        }
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("aw-cert-\(UUID().uuidString).pem")
        guard (try? Data(pem.stdout.utf8).write(to: file)) != nil else {
            return nil
        }
        defer { try? FileManager.default.removeItem(at: file) }
        guard let subject = try? await runner.run("/usr/bin/openssl", ["x509", "-noout", "-subject", "-in", file.path]),
              subject.succeeded
        else {
            return nil
        }
        return parseTeamID(subject: subject.stdout)
    }
}
