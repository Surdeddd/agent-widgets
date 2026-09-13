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
}
