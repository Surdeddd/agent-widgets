import Foundation

enum PathWalk {
    static func ancestors(of url: URL) -> [URL] {
        var result: [URL] = []
        var path = url.standardizedFileURL.path
        while true {
            result.append(URL(fileURLWithPath: path, isDirectory: true))
            if path == "/" || path.isEmpty {
                return result
            }
            path = (path as NSString).deletingLastPathComponent
        }
    }

    /// Regular, visible files under `directory` with their paths relative to it; symlinks on the way to `directory` do not skew the paths.
    static func files(in directory: URL) -> [(url: URL, relative: String)] {
        let base = directory.resolvingSymlinksInPath()
        let enumerator = FileManager.default.enumerator(at: base, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])
        let prefix = base.path.hasSuffix("/") ? base.path : base.path + "/"
        return (enumerator?.compactMap { $0 as? URL } ?? [])
            .filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }
            .compactMap { file -> (url: URL, relative: String)? in
                let path = file.resolvingSymlinksInPath().path
                guard path.hasPrefix(prefix) else { return nil }
                return (file, String(path.dropFirst(prefix.count)))
            }
            .sorted { $0.relative < $1.relative }
    }
}
