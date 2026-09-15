import AWSchema
import Foundation
import MCP

enum ArgumentCheck {
    /// Problems with `values` against a tool's input schema: unknown names, values of the wrong type, missing required ones.
    static func problems(_ values: [String: Value], schema: Value) -> [String] {
        guard case .object(let root) = schema else { return [] }
        let properties = members(root["properties"])
        let required = root["required"]?.arrayValue?.compactMap(\.stringValue) ?? []
        var problems: [String] = []
        for name in values.keys.sorted() {
            guard let property = properties[name] else {
                let known = properties.keys.sorted().joined(separator: ", ")
                problems.append(L10n.pick(
                    en: "unknown argument \"\(name)\"; this tool takes \(known)",
                    ru: "неизвестный аргумент «\(name)»; этот инструмент принимает \(known)"
                ))
                continue
            }
            guard let value = values[name], let type = members(property)["type"]?.stringValue, !accepts(value, type, property: members(property)) else {
                continue
            }
            problems.append(L10n.pick(
                en: "\"\(name)\" must be \(english(type)), got \(english(value))",
                ru: "«\(name)» должен быть \(russian(type)), а пришло: \(russian(value))"
            ))
        }
        for name in required where isMissing(values[name]) {
            problems.append(L10n.pick(en: "missing \"\(name)\"", ru: "нет аргумента «\(name)»"))
        }
        return problems
    }

    static func issue(_ problem: String) -> Issue {
        Issue(
            code: IssueCode.invalidArgument,
            severity: .error,
            message: problem,
            hint: L10n.pick(
                en: "Names and types are in the tool's input schema; `aw explain INVALID_ARGUMENT` says more",
                ru: "Имена и типы — в схеме аргументов инструмента; подробнее `aw explain INVALID_ARGUMENT`"
            )
        )
    }

    private static func members(_ value: Value?) -> [String: Value] {
        if case .object(let object)? = value {
            return object
        }
        return [:]
    }

    private static func isMissing(_ value: Value?) -> Bool {
        switch value {
        case .none, .null?: true
        default: false
        }
    }

    private static func accepts(_ value: Value, _ type: String, property: [String: Value]) -> Bool {
        switch (type, value) {
        case (_, .null), ("string", .string), ("boolean", .bool), ("number", .int), ("number", .double), ("integer", .int), ("array", .string):
            return true
        case ("array", .array(let items)):
            guard members(property["items"])["type"]?.stringValue == "string" else { return true }
            return items.allSatisfy { item in
                if case .string = item {
                    return true
                }
                return false
            }
        default:
            return false
        }
    }

    private static func english(_ type: String) -> String {
        switch type {
        case "string": "a string"
        case "boolean": "true or false"
        case "number": "a number"
        case "integer": "a whole number"
        case "array": "an array of strings"
        default: type
        }
    }

    private static func russian(_ type: String) -> String {
        switch type {
        case "string": "строкой"
        case "boolean": "true или false"
        case "number": "числом"
        case "integer": "целым числом"
        case "array": "массивом строк"
        default: type
        }
    }

    private static func english(_ value: Value) -> String {
        switch value {
        case .string: "a string"
        case .bool: "a boolean"
        case .int, .double: "a number"
        case .array: "an array"
        case .object: "an object"
        case .null: "null"
        case .data: "data"
        }
    }

    private static func russian(_ value: Value) -> String {
        switch value {
        case .string: "строка"
        case .bool: "булево значение"
        case .int, .double: "число"
        case .array: "массив"
        case .object: "объект"
        case .null: "null"
        case .data: "данные"
        }
    }
}
