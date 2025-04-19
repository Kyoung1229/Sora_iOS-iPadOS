import Foundation

enum LLMResponseParser {
    static func textDelta(_ j:[String:Any], provider: ModelProvider) -> String? {
        switch provider {
        case ModelProvider.gemini:
            // Gemini SSE 스트리밍 또는 일반 응답 파싱
            // 먼저 'text' 키 직접 확인
            if let shortText = j["text"] as? String {
                return shortText
            }
            // 'candidates' 기반 파싱
            if let candidates = j["candidates"] as? [[String:Any]],
               let first = candidates.first,
               let content = first["content"] as? [String:Any],
               let parts = content["parts"] as? [[String:Any]] {
               let partsfirst = parts.first
                return partsfirst!["text"] as? String
            }
 
            return nil
        case ModelProvider.openai:
            if let text = j["delta"] as? String {
                return text
            }
            if let response = j["response"] as? [String:Any],
               let output = response["output"] as? [[String:Any]],
               let outputFirst = output.first,
               let content = outputFirst["content"] as? [[String:Any]],
               let contentFirst = content.first,
               let inner = contentFirst["text"] as? String {

                return inner
            }

            return nil
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
            
            for part in parts {
                if let functionCall = part["functionCall"] as? [String:Any],
                   let name = functionCall["name"] as? String {
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
