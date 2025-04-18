import Foundation

enum LLMResponseParser {
    static func textDelta(_ j:[String:Any], provider: ModelProvider) -> String? {
        switch provider {
        case ModelProvider.gemini:
            guard let part = ((j["candidates"] as? [[String:Any]])?
                .first?["content"] as? [String:Any])?["parts"] as? [[String:Any]]
            else { return nil }
            return part.compactMap { $0["text"] as? String }.joined()
        case ModelProvider.openai:
            return j["delta"] as? String ?? (j["choices"] as? [[String:Any]])?
                .first?["delta"] as? String
        }
    }
    
    static func toolCall(_ j:[String:Any], provider: ModelProvider) -> ToolCall? {
        switch provider {
        case ModelProvider.gemini:
            // Gemini 응답에서 도구 호출 추출
            guard let candidates = j["candidates"] as? [[String:Any]],
                  let firstCandidate = candidates.first,
                  let content = firstCandidate["content"] as? [String:Any],
                  let parts = content["parts"] as? [[String:Any]]
            else { return nil }
            
            // 도구 호출 찾기
            for part in parts {
                if let functionCall = part["functionCall"] as? [String:Any],
                   let name = functionCall["name"] as? String {
                    // 인수 파싱 (문자열이나 Dictionary 형태일 수 있음)
                    var arguments: [String: Any] = [:]
                    if let args = functionCall["args"] as? [String:Any] {
                        arguments = args
                    } else if let argsStr = functionCall["args"] as? String,
                              let data = argsStr.data(using: .utf8),
                              let parsed = try? JSONSerialization.jsonObject(with: data) as? [String:Any] {
                        arguments = parsed
                    }
                    
                    return ToolCall(
                        name: name,
                        arguments: arguments,
                        id: (functionCall["id"] as? String) ?? UUID().uuidString,
                        description: ""
                    )
                }
            }
            return nil
            
        case ModelProvider.openai:
            // OpenAI 응답에서 도구 호출 추출
            if let toolCalls = j["tool_calls"] as? [[String:Any]],
               let firstTool = toolCalls.first,
               let function = firstTool["function"] as? [String:Any],
               let name = function["name"] as? String {
                
                // 인수 파싱
                var arguments: [String: Any] = [:]
                if let argsStr = function["arguments"] as? String,
                   let data = argsStr.data(using: .utf8),
                   let parsed = try? JSONSerialization.jsonObject(with: data) as? [String:Any] {
                    arguments = parsed
                }
                
                return ToolCall(
                    name: name,
                    arguments: arguments,
                    id: (firstTool["id"] as? String) ?? UUID().uuidString,
                    description: ""
                )
            }
            return nil
        }
    }
}
