import Foundation

public struct Issue: Codable, Equatable, Hashable, Sendable {
    public enum Severity: String, Codable, Sendable {
        case error
        case warning
        case info
    }

    public var code: String
    public var severity: Severity
    public var message: String
    public var hint: String?
    public var file: String?
    public var line: Int?

    public init(
        code: String,
        severity: Severity,
        message: String,
        hint: String? = nil,
        file: String? = nil,
        line: Int? = nil
    ) {
        self.code = code
        self.severity = severity
        self.message = message
        self.hint = hint
        self.file = file
        self.line = line
    }
}

public enum IssueCode {
    public static let overflow = "OVERFLOW"
    public static let truncation = "TRUNCATION"
    public static let decode = "DECODE"
    public static let tinyText = "TINY_TEXT"
    public static let emptyScenario = "EMPTY"
    public static let unrenderable = "UNRENDERABLE"
    public static let manifestInvalid = "MANIFEST_INVALID"
    public static let duplicateKind = "DUPLICATE_KIND"
    public static let budgetRisk = "BUDGET_RISK"
    public static let missingDefaultSample = "MISSING_DEFAULT_SAMPLE"
    public static let workspaceNotFound = "WORKSPACE_NOT_FOUND"
    public static let workspaceExists = "WORKSPACE_EXISTS"
    public static let engineNotFound = "ENGINE_NOT_FOUND"
    public static let invalidJSON = "INVALID_JSON"
    public static let invalidArgument = "INVALID_ARGUMENT"
    public static let signingMissing = "SIGNING_MISSING"
    public static let toolMissing = "TOOL_MISSING"
    public static let compileError = "COMPILE_ERROR"
    public static let buildError = "BUILD_ERROR"
    public static let installFailed = "INSTALL_FAILED"
    public static let screenRecordingDenied = "SCREEN_RECORDING_DENIED"
    public static let widgetNotPlaced = "WIDGET_NOT_PLACED"
    public static let slotTimeout = "SLOT_TIMEOUT"
    public static let widgetExists = "WIDGET_EXISTS"
    public static let widgetNotFound = "WIDGET_NOT_FOUND"
    public static let widgetIdInvalid = "WIDGET_ID_INVALID"
    public static let templateUnknown = "TEMPLATE_UNKNOWN"
    public static let feedFailed = "FEED_FAILED"
    public static let feedTimeout = "FEED_TIMEOUT"
    public static let feedInvalidOutput = "FEED_INVALID_OUTPUT"
    public static let staleData = "STALE_DATA"
    public static let daemonMissing = "DAEMON_MISSING"
    public static let keptExisting = "KEPT_EXISTING"
    public static let previewCrashed = "PREVIEW_CRASHED"
    public static let scenarioNotFound = "SCENARIO_NOT_FOUND"
    public static let shotUnchanged = "SHOT_UNCHANGED"
    public static let shipUnverified = "SHIP_UNVERIFIED"
    public static let geometryUnknown = "GEOMETRY_UNKNOWN"
    public static let shotMismatch = "SHOT_MISMATCH"
    public static let feedCommandNotFound = "FEED_COMMAND_NOT_FOUND"
    public static let feedSecretMissing = "FEED_SECRET_MISSING"
    public static let secretsInConfig = "SECRETS_IN_CONFIG"
    public static let sampleNotLocalized = "SAMPLE_NOT_LOCALIZED"
    public static let jobUnknown = "JOB_UNKNOWN"
    public static let widgetHidden = "WIDGET_HIDDEN"

    public static let all: [String] = [
        keptExisting, previewCrashed,
        overflow, truncation, decode, tinyText, emptyScenario, unrenderable,
        manifestInvalid, duplicateKind, budgetRisk, missingDefaultSample,
        workspaceNotFound, workspaceExists, engineNotFound, invalidJSON, invalidArgument,
        signingMissing, toolMissing, compileError, buildError, installFailed,
        screenRecordingDenied, widgetNotPlaced, slotTimeout, shotUnchanged, shipUnverified, geometryUnknown,
        widgetExists, widgetNotFound, widgetIdInvalid, templateUnknown, scenarioNotFound,
        feedFailed, feedTimeout, feedInvalidOutput, staleData, daemonMissing,
        shotMismatch, feedCommandNotFound, feedSecretMissing, secretsInConfig, sampleNotLocalized, jobUnknown, widgetHidden
    ]
}
