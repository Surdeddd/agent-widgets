import AWSchema
import Foundation
import Testing
@testable import AWKit

private func store() throws -> (AWStore, URL) {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("aw-dev-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return (AWStore(root: root), root)
}

@Test func devProviderIsEmptyWithoutTarget() throws {
    let (store, root) = try store()
    defer { try? FileManager.default.removeItem(at: root) }
    let entry = AWDevProvider(store: store).load()
    #expect(entry.widget == nil)
    #expect(entry.data == nil)
}

@Test func devProviderReadsScenarioCopy() throws {
    let (store, root) = try store()
    defer { try? FileManager.default.removeItem(at: root) }
    try store.write(AWJSON.encoder().encode(DevTarget(widget: "weather", scenario: "long")), to: AppGroupLayout.devTarget)
    try store.write(Data(#"{"scenario":true}"#.utf8), to: AppGroupLayout.devData)
    try store.write(Data(#"{"live":true}"#.utf8), to: AppGroupLayout.data("weather"))
    let entry = AWDevProvider(store: store).load()
    #expect(entry.widget == "weather")
    #expect(entry.data == Data(#"{"scenario":true}"#.utf8))
}

@Test func devProviderReadsLiveData() throws {
    let (store, root) = try store()
    defer { try? FileManager.default.removeItem(at: root) }
    try store.write(AWJSON.encoder().encode(DevTarget(widget: "weather")), to: AppGroupLayout.devTarget)
    try store.write(Data(#"{"live":true}"#.utf8), to: AppGroupLayout.data("weather"))
    #expect(AWDevProvider(store: store).load().data == Data(#"{"live":true}"#.utf8))
}
