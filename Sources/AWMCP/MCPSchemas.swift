import Foundation
import MCP

enum OutputSchema {
    static func object(_ properties: [String: Value], required: [String] = [], summary: Bool = true) -> Value {
        var all = properties
        var needed = required
        if summary {
            all["summary"] = string
            needed.append("summary")
        }
        return .object([
            "type": .string("object"),
            "properties": .object(all),
            "required": .array(needed.map(Value.string))
        ])
    }

    static let string: Value = .object(["type": .string("string")])
    static let number: Value = .object(["type": .string("number")])
    static let boolean: Value = .object(["type": .string("boolean")])
    static let anyObject: Value = .object(["type": .string("object")])
    static let anyArray: Value = .object(["type": .string("array")])
    static let strings: Value = .object(["type": .string("array"), "items": .object(["type": .string("string")])])

    static let job = object(["id": string, "tool": string, "stage": string, "elapsed": number], required: ["id", "tool", "stage", "elapsed"], summary: false)

    static let gallery = object(["widgets": anyArray], required: ["widgets"])
    static let templates = object(["templates": anyArray], required: ["templates"])
    static let created = object(["files": strings], required: ["files"])
    static let preview = object([
        "widget": string,
        "report": anyObject,
        "issues": anyArray,
        "compiled": boolean,
        "compileSeconds": number,
        "renderSeconds": number
    ], required: ["widget", "issues", "compiled"])
    static let ship = object([
        "widget": string,
        "stage": string,
        "preview": anyObject,
        "build": anyObject,
        "install": anyObject,
        "dev": anyObject,
        "shots": anyArray,
        "comparisons": anyArray,
        "issues": anyArray,
        "seconds": anyObject,
        "job": job
    ])
    static let shot = object(["shots": anyArray, "comparisons": anyArray], required: ["shots", "comparisons"])
    static let slot = object(["windows": anyArray, "shots": anyArray, "comparisons": anyArray, "job": job])
    static let dev = object([
        "target": anyObject,
        "shots": anyArray,
        "comparisons": anyArray,
        "issues": anyArray,
        "seconds": number,
        "job": job
    ])
    static let wait = object([:])
    static let doctor = object(["checks": anyArray], required: ["checks"])
    static let list = object(["widgets": anyArray], required: ["widgets"])
    static let data = object(["changed": boolean], required: ["changed"])
    static let feed = object(["widget": string, "ok": boolean, "changed": boolean, "seconds": number, "issues": anyArray, "job": job])
    static let explain: Value = .object([
        "type": .string("object"),
        "anyOf": .array([
            object(
                ["code": string, "title": anyObject, "cause": anyObject, "fix": anyObject, "example": string],
                required: ["code", "title", "cause", "fix"]
            ),
            object(["codes": strings], required: ["codes"])
        ])
    ])
}
