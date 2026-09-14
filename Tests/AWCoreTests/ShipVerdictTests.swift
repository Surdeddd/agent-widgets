import AWSchema
import Foundation
import Testing
@testable import AWCore

private func demoWindow() -> WidgetWindow {
    WidgetWindow(id: 1, name: "Demo · Dev", width: 344, height: 170, family: .medium)
}

@Test func requireShotPromotesNotPlacedToError() {
    var outcome = ShipOutcome(widget: "w", stage: .done)
    outcome.issues = [ShotIssues.notPlaced("Demo · Dev", appName: "Demo")]
    outcome.requireShot(true)
    #expect(outcome.stage == .unverified)
    #expect(outcome.exitCode == 5)
    #expect(outcome.issues.contains { $0.code == IssueCode.widgetNotPlaced && $0.severity == .error })
}

@Test func requireShotKeepsDoneWhenAShotSettled() {
    var outcome = ShipOutcome(widget: "w", stage: .done)
    outcome.shots = [ShotRecord(label: "aw.dev", window: demoWindow(), path: "/tmp/shot.png", settled: true)]
    outcome.requireShot(true)
    #expect(outcome.stage == .done)
    #expect(outcome.exitCode == 0)
    #expect(!outcome.issues.contains { $0.code == IssueCode.shipUnverified })
}

@Test func requireShotPromotesUnchangedWhenShotDidNotSettle() {
    var outcome = ShipOutcome(widget: "w", stage: .done)
    outcome.shots = [ShotRecord(label: "aw.dev", window: demoWindow(), path: "/tmp/shot.png", settled: false)]
    outcome.issues = [ShotIssues.unchanged(after: 30)]
    outcome.requireShot(true)
    #expect(outcome.stage == .unverified)
    #expect(outcome.issues.contains { $0.code == IssueCode.shotUnchanged && $0.severity == .error })
}

@Test func requireShotAddsUnverifiedErrorWhenThereIsNoShotEvidence() {
    var outcome = ShipOutcome(widget: "w", stage: .done)
    outcome.requireShot(true)
    #expect(outcome.stage == .unverified)
    #expect(outcome.issues.contains { $0.code == IssueCode.shipUnverified && $0.severity == .error })
}

@Test func requireShotWarnsWhenShotWasNotRequested() {
    var outcome = ShipOutcome(widget: "w", stage: .done)
    outcome.requireShot(false)
    #expect(outcome.stage == .done)
    #expect(outcome.exitCode == 0)
    #expect(outcome.issues.contains { $0.code == IssueCode.shipUnverified && $0.severity == .warning })
}

@Test func requireShotLeavesNonDoneStagesAlone() {
    var outcome = ShipOutcome(widget: "w", stage: .build)
    outcome.requireShot(true)
    #expect(outcome.stage == .build)
    #expect(outcome.issues.isEmpty)
}
