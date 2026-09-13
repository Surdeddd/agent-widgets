import CryptoKit
import Foundation

enum Fingerprint {
    static func of(files: [URL], root: URL, extra: [String] = []) -> String {
        var hasher = SHA256()
        for file in files.sorted(by: { $0.path < $1.path }) {
            hasher.update(data: Data(file.path.replacingOccurrences(of: root.path, with: "").utf8))
            if let data = try? Data(contentsOf: file) {
                hasher.update(data: data)
            }
        }
        for item in extra {
            hasher.update(data: Data(item.utf8))
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    static func swiftFiles(in directory: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil) else {
            return []
        }
        return enumerator
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" }
            .sorted { $0.path < $1.path }
    }
}

final class FileLock {
    private let descriptor: Int32

    init(_ url: URL) throws {
        descriptor = open(url.path, O_CREAT | O_RDWR, 0o644)
        guard descriptor >= 0 else {
            throw CocoaError(.fileWriteNoPermission)
        }
        flock(descriptor, LOCK_EX)
    }

    func unlock() {
        flock(descriptor, LOCK_UN)
        close(descriptor)
    }
}
