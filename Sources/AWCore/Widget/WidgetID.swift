import Foundation

public enum WidgetID {
    public static func isValid(_ id: String) -> Bool {
        id.range(of: "^[a-z][a-z0-9-]{0,39}$", options: .regularExpression) != nil
    }
}
