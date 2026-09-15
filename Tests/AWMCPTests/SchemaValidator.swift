import MCP

enum SchemaValidator {
    /// Paths where `value` breaks `schema` (type, properties, required, items, anyOf); empty when it conforms.
    static func errors(_ value: Value, _ schema: Value, path: String = "$") -> [String] {
        guard case .object(let rule) = schema else { return [] }
        if case .string(let type)? = rule["type"], !matches(value, type) {
            return ["\(path): expected \(type)"]
        }
        var errors: [String] = []
        if case .array(let options)? = rule["anyOf"], !options.contains(where: { self.errors(value, $0, path: path).isEmpty }) {
            errors.append("\(path): matches none of anyOf")
        }
        if case .object(let object) = value {
            errors += memberErrors(object, rule, path: path)
        }
        if case .array(let items) = value, let item = rule["items"] {
            for (index, element) in items.enumerated() {
                errors += self.errors(element, item, path: "\(path)[\(index)]")
            }
        }
        return errors
    }

    private static func memberErrors(_ object: [String: Value], _ rule: [String: Value], path: String) -> [String] {
        var errors: [String] = []
        if case .array(let required)? = rule["required"] {
            for case .string(let name) in required where object[name] == nil {
                errors.append("\(path).\(name): required")
            }
        }
        if case .object(let properties)? = rule["properties"] {
            for (name, child) in properties {
                if let member = object[name] {
                    errors += self.errors(member, child, path: "\(path).\(name)")
                }
            }
        }
        return errors
    }

    private static func matches(_ value: Value, _ type: String) -> Bool {
        switch (type, value) {
        case ("object", .object), ("array", .array), ("string", .string), ("boolean", .bool), ("null", .null),
             ("number", .int), ("number", .double), ("integer", .int):
            return true
        default:
            return false
        }
    }
}
