import Foundation
import Testing
@testable import AWCore

private func sample(_ json: String) throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("aw-sample-\(UUID().uuidString).json")
    try Data(json.utf8).write(to: url)
    return url
}

@Test func onlySamplesWithTextNeedARussianVersion() throws {
    let numbers = try sample(#"{"boot": 1789000000, "load": [1.2, 0.8, 0.5], "ok": true, "extra": null}"#)
    let words = try sample(#"{"city": "Bangkok", "temp": 31}"#)
    let nested = try sample(#"{"rows": [{"value": 3}, {"label": "Disk"}]}"#)
    defer { [numbers, words, nested].forEach { try? FileManager.default.removeItem(at: $0) } }
    #expect(!PreviewPipeline.hasText(numbers))
    #expect(PreviewPipeline.hasText(words))
    #expect(PreviewPipeline.hasText(nested))
    #expect(PreviewPipeline.hasText(URL(fileURLWithPath: "/nonexistent/default.json")))
    #expect(PreviewPipeline.hasText(nil))
}
