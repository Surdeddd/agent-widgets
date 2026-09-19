import AWSchema
import Foundation

enum MCPHints {
    private static let tools: [(command: String, tool: String)] = [
        ("feed run", "aw_feed_run"),
        ("data set", "aw_data_set"),
        ("init", "aw_init"),
        ("gallery add", "aw_gallery_add"),
        ("gallery", "aw_gallery"),
        ("preview", "aw_preview"),
        ("ship", "aw_ship"),
        ("shot", "aw_shot"),
        ("slot", "aw_slot"),
        ("dev", "aw_dev"),
        ("doctor", "aw_doctor"),
        ("list", "aw_list"),
        ("new", "aw_new"),
        ("explain", "aw_explain"),
        ("templates", "aw_templates")
    ]

    private enum JSON {
        case bool(Bool)
        case int(Int)
        case double(Double)
        case string(String)
        case strings([String])
    }

    static func rewrite(_ text: String) -> String {
        var output = ""
        var index = text.startIndex
        while index < text.endIndex {
            if let next = takeSpan(text, at: index, into: &output) {
                index = next
            } else if let next = takeWorkspace(text, at: index, into: &output) {
                index = next
            } else {
                output.append(text[index])
                index = text.index(after: index)
            }
        }
        return output
    }

    private static func takeSpan(_ text: String, at index: String.Index, into output: inout String) -> String.Index? {
        guard text[index] == "`" else { return nil }
        let innerStart = text.index(after: index)
        guard let close = text[innerStart...].firstIndex(of: "`") else { return nil }
        let inner = String(text[innerStart..<close])
        let after = text.index(after: close)
        if inner.hasPrefix("aw "), let rewritten = rewriteTool(inner) {
            output += "`\(rewritten)`"
            return after
        }
        output += "`\(inner)`"
        if inner.hasPrefix("aw ") {
            let rest = text[after...]
            if !rest.hasPrefix(" (in a shell)") && !rest.hasPrefix(" (в терминале)") {
                output += L10n.pick(en: " (in a shell)", ru: " (в терминале)")
            }
        }
        return after
    }

    private static func takeWorkspace(_ text: String, at index: String.Index, into output: inout String) -> String.Index? {
        let marker = "--workspace"
        guard text[index...].hasPrefix(marker) else { return nil }
        if let last = output.last, last.isLetter || last.isNumber || last == "_" || last == "-" {
            return nil
        }
        let end = text.index(index, offsetBy: marker.count)
        if end < text.endIndex {
            let next = text[end]
            if next.isLetter || next.isNumber || next == "_" || next == "-" {
                return nil
            }
        }
        output += L10n.pick(en: "the `workspace` argument", ru: "аргумент `workspace`")
        return end
    }

    private static func rewriteTool(_ inner: String) -> String? {
        let body = String(inner.dropFirst(3))
        for (command, tool) in tools {
            guard body == command || body.hasPrefix(command + " ") else { continue }
            let tokens = String(body.dropFirst(command.count)).split(whereSeparator: \.isWhitespace).map(String.init)
            guard !tokens.isEmpty else { return tool }
            let positional = ["aw_explain": "code", "aw_init": "workspace"][tool] ?? "id"
            return "\(tool) \(encode(parse(tokens, positional: positional)))"
        }
        return nil
    }

    private static func parse(_ tokens: [String], positional: String) -> [String: JSON] {
        var result: [String: JSON] = [:]
        var index = 0
        while index < tokens.count {
            let token = tokens[index]
            if token.hasPrefix("--") {
                let key = String(token.dropFirst(2)).replacingOccurrences(of: "-", with: "_")
                let next = index + 1 < tokens.count ? tokens[index + 1] : nil
                if let next, !next.hasPrefix("--") {
                    result[key] = value(key: key, raw: next)
                    index += 2
                } else {
                    result[key] = .bool(true)
                    index += 1
                }
            } else {
                if result[positional] == nil {
                    result[positional] = value(key: positional, raw: token)
                }
                index += 1
            }
        }
        return result
    }

    private static func value(key: String, raw: String) -> JSON {
        if key == "families" || key == "scenarios" {
            let parts = raw.split(separator: ",", omittingEmptySubsequences: true)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            return .strings(parts)
        }
        if let number = Int(raw) {
            return .int(number)
        }
        if let number = decimal(raw) {
            return .double(number)
        }
        return .string(raw)
    }

    private static func decimal(_ raw: String) -> Double? {
        let digits = raw.hasPrefix("-") ? String(raw.dropFirst()) : raw
        let parts = digits.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 2, parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }) else {
            return nil
        }
        return Double(raw)
    }

    private static func encode(_ object: [String: JSON]) -> String {
        let pairs = object.keys.sorted().map { key in
            "\"\(key)\": \(encode(object[key]!))"
        }
        return "{\(pairs.joined(separator: ", "))}"
    }

    private static func encode(_ value: JSON) -> String {
        switch value {
        case .bool(let flag):
            return flag ? "true" : "false"
        case .int(let number):
            return String(number)
        case .double(let number):
            return String(number)
        case .string(let text):
            return "\"\(escape(text))\""
        case .strings(let items):
            return "[\(items.map { "\"\(escape($0))\"" }.joined(separator: ", "))]"
        }
    }

    private static func escape(_ text: String) -> String {
        var result = ""
        for character in text {
            switch character {
            case "\\": result += "\\\\"
            case "\"": result += "\\\""
            case "\n": result += "\\n"
            case "\r": result += "\\r"
            case "\t": result += "\\t"
            default: result.append(character)
            }
        }
        return result
    }
}
