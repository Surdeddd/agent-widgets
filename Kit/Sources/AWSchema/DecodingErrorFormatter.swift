import Foundation

public enum DecodingErrorFormatter {
    public static func describe(_ error: Error) -> String {
        guard let decoding = error as? DecodingError else {
            return error.localizedDescription
        }
        switch decoding {
        case .keyNotFound(let key, let context):
            return L10n.pick(
                en: "missing key \"\(path(context.codingPath + [key]))\"",
                ru: "нет ключа \"\(path(context.codingPath + [key]))\""
            )
        case .typeMismatch(let type, let context):
            return L10n.pick(
                en: "wrong type at \"\(path(context.codingPath))\", expected \(type)",
                ru: "неверный тип в \"\(path(context.codingPath))\", ожидался \(type)"
            )
        case .valueNotFound(let type, let context):
            return L10n.pick(
                en: "null at \"\(path(context.codingPath))\", expected \(type)",
                ru: "null в \"\(path(context.codingPath))\", ожидался \(type)"
            )
        case .dataCorrupted(let context):
            let location = context.codingPath.isEmpty ? "" : " (\(path(context.codingPath)))"
            return "\(context.debugDescription)\(location)"
        @unknown default:
            return String(describing: decoding)
        }
    }

    private static func path(_ keys: [CodingKey]) -> String {
        keys.map { key in key.intValue.map { "[\($0)]" } ?? key.stringValue }
            .joined(separator: ".")
            .replacingOccurrences(of: ".[", with: "[")
    }
}
