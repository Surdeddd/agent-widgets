import Testing
@testable import AWSchema

@Test func schemaVersionIsPositive() {
    #expect(SchemaVersion.current > 0)
}
