// Message+Dicts.swift

import Foundation

extension Message {
    func toOpenAIDict() -> [String:Any] {
        var d: [String:Any] = ["role": role]
        if parts.count == 1, case .text(let s) = parts[0] {
            d["content"] = s
        } else {
            d["content"] = parts.map { part -> [String:Any] in
                switch (part, role) {
                case (.text(let s), "user"):
                    return ["type":"input_text","text": s]
                case (.text(let s), "assistant"):
                    return ["type":"output_text","text": s]
                case (.image(let b, let m), role):
                    return ["type":"input_image","image_url": "data:\(m);base64,\(b)"]
                case (.file(let b, let m, let n), role):
                    let urlDict: [String:Any] = ["url": "data:\(m);base64,\(b)", "file_name": n]
                    return ["type":"input_file","file_url": urlDict]
                case (.toolCall(let name, let args, let desc, let id, let cid), role):
                    let callDict: [String:Any] = [
                        "name": name,
                        "arguments": args,
                        "description": desc,
                        "id": id,
                        "call_id": cid
                    ]
                    return ["type":"tool","tool_call": callDict]
                default:
                    return [:]
                }
                }
        }
        return d
    }
    
    func toGeminiDict() -> [String:Any] {
        return [
            "role": role,
            "parts": parts.map { part -> [String:Any] in
                switch part {
                case .text(let s):
                    return ["text": s]
                case .image(let b, let m):
                    return ["inline_data": ["mime_type": m, "data": b]]
                case .file(let b, let m, let n):
                    return ["inline_data": ["mime_type": m, "data": b, "file_name": n]]
                case .toolCall(let name, let args, let desc, let id, let cid):
                    var fc: [String:Any] = [
                        "name": name,
                        "arguments": args
                    ]
                    fc["description"] = desc
                    fc["id"]          = id
                    fc["call_id"]     = cid
                    return ["function_call": fc]
                }
            }
        ]
    }
}

extension Array where Element == Message {
    func toDicts(provider: ModelProvider) -> [[String:Any]] {
        map { provider == .openai
            ? $0.toOpenAIDict()
            : $0.toGeminiDict()
        }
    }
}
