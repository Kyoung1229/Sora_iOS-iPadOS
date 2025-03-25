import Foundation

struct MessagesManager {
    // 새 메시지를 추가하는 메서드 (role에 따라 새 메시지 생성)
    func appendText(role: String, content: String, messages: [[String: Any]]) -> [[String: Any]] {
        var newMessages = messages
        let newContent: [String: Any] = [
            "role": role,
            "parts": [
                ["text": content]
            ]
        ]
        newMessages.append(newContent)
        return newMessages
    }
    // 마지막 메시지의 "parts" 내 "text"에 content를 이어 붙입니다.
    // 만약 messages가 비어있다면 새 model 메시지를 추가합니다.
    func appendChunk(content: String, messages: [[String: Any]]) -> [[String: Any]] {
        var newMessages = messages
        guard !newMessages.isEmpty else {
             return appendText(role: "model", content: content, messages: messages)
        }
        
        let lastIndex = newMessages.count - 1
        var lastMessage = newMessages[lastIndex]
        var parts = lastMessage["parts"] as? [[String: Any]] ?? []
        
        if parts.isEmpty {
             parts.append(["text": content])
        } else {
             // 기존 parts 배열의 마지막 요소에 이어 붙임
             var lastPart = parts.last!
             let existingText = lastPart["text"] as? String ?? ""
             lastPart["text"] = existingText + content
             parts[parts.count - 1] = lastPart
        }
        
        lastMessage["parts"] = parts
        newMessages[lastIndex] = lastMessage
        return newMessages
    }

    // Data에서 JSON을 파싱하여 answer를 추출하는 메서드
    func extractAnswer(from jsonObject: [String: Any]) -> String? {
        guard let candidates = jsonObject["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            print("JSON 구조가 예상과 다릅니다.")
            return nil
        }
        return text
    }
    func decodeMessages(_ jsonString: String) -> [[String: Any]] {
        guard let data = jsonString.data(using: .utf8),
              let jsonArray = try? JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] else {
            return []
        }
        return jsonArray
    }
    func decodeMessagesNOTARRAY(_ jsonString: String) -> [String: Any] {
        guard let data = jsonString.data(using: .utf8),
              let jsonArray = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            return [:]
        }
        return jsonArray
    }
    
    func encodeMessages(_ messages: [[String: Any]]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: messages, options: .prettyPrinted),
              let jsonString = String(data: data, encoding: .utf8) else {
            return "[]" // 기본값: 빈 배열
        }
        return jsonString
    }
    func encodeMessagesNOTARRAY(_ messages: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: messages, options: .prettyPrinted),
              let jsonString = String(data: data, encoding: .utf8) else {
            return "[]" // 기본값: 빈 배열
        }
        return jsonString
    }
    
    // [[String: Any]]를 Message 배열로 변환하는 함수
    func decodeStructMessage(from rawMessages: [[String: Any]]) -> [Message] {
        do {
            let data = try JSONSerialization.data(withJSONObject: rawMessages, options: [])
            let messages = try JSONDecoder().decode([Message].self, from: data)
            return messages
        } catch {
            print("디코딩 에러: \(error)")
            return []
        }
    }

    // Message 배열을 [[String: Any]]로 변환하는 함수
    func encodeMessages(_ messages: [Message]) -> [[String: Any]]? {
        do {
            let data = try JSONEncoder().encode(messages)
            if let jsonObject = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
                return jsonObject
            }
        } catch {
            print("인코딩 에러: \(error)")
        }
        return nil
    }
}
struct Message: Codable, Identifiable, Equatable {
    var id = UUID()
    var role: String
    var parts: [Part]
}

struct Part: Codable, Equatable {
    var text: String
}
