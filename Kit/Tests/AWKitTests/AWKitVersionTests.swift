import Testing
@testable import AWKit
@testable import AWPreview

@Test func previewTracksKitVersion() {
    #expect(AWPreviewVersion.current == AWKitVersion.current)
}
