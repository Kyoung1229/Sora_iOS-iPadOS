import Foundation

// 더 명확한 메시지 구조체 정의
struct Message: Codable, Identifiable, Equatable {
    var id = UUID()
    var role: String
    var parts: [MessagePart]
    
    // 생성자 추가
    init(role: String, parts: [MessagePart]) {
        self.role = role
        self.parts = parts
    }
    
    // 텍스트만 있는 메시지 생성 간편 생성자
    init(role: String, text: String) {
        self.role = role
        self.parts = [MessagePart.text(text)]
    }
}

// 메시지 파트 정의 (텍스트 또는 이미지)
enum MessagePart: Codable, Equatable {
    case text(String)
    case image(String, mimeType: String) // base64 이미지 데이터와 MIME 타입
    
    // 인코딩 구현
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .text(let text):
            try container.encode(["text": text], forKey: .part)
        case .image(let base64Data, let mimeType):
            try container.encode([
                "inline_data": [
                    "data": base64Data,
                    "mime_type": mimeType
                ]
            ], forKey: .part)
        }
    }
    
    // 디코딩 구현
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let part = try container.decode([String: Any].self, forKey: .part)
        
        if let text = part["text"] as? String {
            self = .text(text)
        } else if let inlineData = part["inline_data"] as? [String: Any],
                  let data = inlineData["data"] as? String,
                  let mimeType = inlineData["mime_type"] as? String {
            self = .image(data, mimeType: mimeType)
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "파트 형식을 해석할 수 없습니다"
                )
            )
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case part
    }
}

// Any 타입의 디코딩을 위한 확장
extension KeyedDecodingContainer {
    func decode(_ type: [String: Any].Type, forKey key: K) throws -> [String: Any] {
        let json = try decode(Data.self, forKey: key)
        let dict = try JSONSerialization.jsonObject(with: json, options: [])
        return dict as? [String: Any] ?? [:]
    }
}

extension KeyedEncodingContainer {
    mutating func encode(_ value: [String: Any], forKey key: K) throws {
        let data = try JSONSerialization.data(withJSONObject: value, options: [])
        try encode(data, forKey: key)
    }
}

struct MessagesManager {
    // 새 텍스트 메시지 추가
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
    
    // 이미지와 텍스트가 포함된 메시지 추가
    func appendTextWithImage(role: String, text: String, imageBase64: String, mimeType: String = "image/jpeg", messages: [[String: Any]]) -> [[String: Any]] {
        var newMessages = messages
        
        // 이미지와 텍스트 모두 포함된 메시지 구성
        let newContent: [String: Any] = [
            "role": role,
            "parts": [
                ["text": text],
                [
                    "inline_data": [
                        "data": imageBase64,
                        "mime_type": mimeType
                    ]
                ]
            ]
        ]
        
        newMessages.append(newContent)
        return newMessages
    }
    
    // 마지막 메시지에 텍스트 추가 (스트리밍용)
    func appendChunk(content: String, messages: [[String: Any]]) -> [[String: Any]] {
        var newMessages = messages
        
        // 메시지가 없으면 새 메시지 생성
        guard !newMessages.isEmpty else {
            return appendText(role: "model", content: content, messages: messages)
        }
        
        let lastIndex = newMessages.count - 1
        var lastMessage = newMessages[lastIndex]
        
        // parts 배열이 없으면 생성
        guard var parts = lastMessage["parts"] as? [[String: Any]] else {
            lastMessage["parts"] = [["text": content]]
            newMessages[lastIndex] = lastMessage
            return newMessages
        }
        
        // parts가 비어있으면 새 text 부분 추가
        if parts.isEmpty {
            parts.append(["text": content])
        } else {
            // 마지막 파트가 텍스트인 경우에만 이어붙이기
            var lastPart = parts.last!
            if lastPart["text"] != nil {
                let existingText = lastPart["text"] as? String ?? ""
                lastPart["text"] = existingText + content
                parts[parts.count - 1] = lastPart
            } else {
                // 마지막 파트가 텍스트가 아니면 새 텍스트 파트 추가
                parts.append(["text": content])
            }
        }
        
        lastMessage["parts"] = parts
        newMessages[lastIndex] = lastMessage
        return newMessages
    }

    // 응답에서 텍스트 추출 (더 견고한 버전)
    func extractAnswer(from jsonObject: [String: Any]) -> String? {
        // 후보 배열이 있는 경우 (표준 형식)
        if let candidates = jsonObject["candidates"] as? [[String: Any]],
           let firstCandidate = candidates.first,
           let content = firstCandidate["content"] as? [String: Any],
           let parts = content["parts"] as? [[String: Any]] {
            // 텍스트 파트 찾기
            for part in parts {
                if let text = part["text"] as? String {
                    return text
                }
            }
        }
        
        // 단순 컨텐츠 형식 (컨텐츠가 직접 포함된 경우)
        if let content = jsonObject["content"] as? [String: Any],
           let parts = content["parts"] as? [[String: Any]] {
            for part in parts {
                if let text = part["text"] as? String {
                    return text
                }
            }
        }
        
        // 파츠가 직접 포함된 경우
        if let parts = jsonObject["parts"] as? [[String: Any]] {
            for part in parts {
                if let text = part["text"] as? String {
                    return text
                }
            }
        }
        
        // 텍스트가 직접 포함된 경우
        if let text = jsonObject["text"] as? String {
            return text
        }
        
        print("JSON 형식에서 텍스트를 추출할 수 없습니다: \(jsonObject)")
        return nil
    }
    
    // 이미지 데이터 추출 
    func extractImage(from jsonObject: [String: Any]) -> (data: String, mimeType: String)? {
        // 후보 배열이 있는 경우
        if let candidates = jsonObject["candidates"] as? [[String: Any]],
           let firstCandidate = candidates.first,
           let content = firstCandidate["content"] as? [String: Any],
           let parts = content["parts"] as? [[String: Any]] {
            
            // 이미지 파트 찾기
            for part in parts {
                if let inlineData = part["inline_data"] as? [String: Any],
                   let data = inlineData["data"] as? String,
                   let mimeType = inlineData["mime_type"] as? String {
                    return (data, mimeType)
                }
            }
        }
        
        // 직접 콘텐츠 형식
        if let content = jsonObject["content"] as? [String: Any],
           let parts = content["parts"] as? [[String: Any]] {
            for part in parts {
                if let inlineData = part["inline_data"] as? [String: Any],
                   let data = inlineData["data"] as? String,
                   let mimeType = inlineData["mime_type"] as? String {
                    return (data, mimeType)
                }
            }
        }
        
        return nil
    }
    
    // JSON 문자열에서 메시지 배열 디코딩
    func decodeMessages(_ jsonString: String) -> [[String: Any]] {
        guard !jsonString.isEmpty else { return [] }
        
        do {
            guard let data = jsonString.data(using: .utf8) else {
                print("JSON 문자열을 데이터로 변환할 수 없습니다")
                return []
            }
            
            if let jsonArray = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
                return jsonArray
            } else if let jsonObject = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                return [jsonObject] // 단일 객체인 경우 배열로 변환
            } else {
                print("JSON을 배열 또는 객체로 파싱할 수 없습니다")
                return []
            }
        } catch {
            print("JSON 디코딩 오류: \(error.localizedDescription)")
            return []
        }
    }
    
    // 메시지 배열 인코딩
    func encodeMessages(_ messages: [[String: Any]]) -> String {
        do {
            let data = try JSONSerialization.data(withJSONObject: messages, options: [])
            if let jsonString = String(data: data, encoding: .utf8) {
                return jsonString
            }
        } catch {
            print("JSON 인코딩 오류: \(error.localizedDescription)")
        }
        return "[]" // 기본값: 빈 배열
    }
    
    // 구조체 Message 배열을 [[String: Any]] 형식으로 변환
    func convertMessagesToDict(messages: [Message]) -> [[String: Any]] {
        var result: [[String: Any]] = []
        
        for message in messages {
            var messageParts: [[String: Any]] = []
            
            for part in message.parts {
                switch part {
                case .text(let text):
                    messageParts.append(["text": text])
                case .image(let base64Data, let mimeType):
                    messageParts.append([
                        "inline_data": [
                            "data": base64Data,
                            "mime_type": mimeType
                        ]
                    ])
                }
            }
            
            result.append([
                "role": message.role,
                "parts": messageParts
            ])
        }
        
        return result
    }
    
    // [[String: Any]] 형식의 메시지를 구조체 Message 배열로 변환
    func convertDictToMessages(messages: [[String: Any]]) -> [Message] {
        var result: [Message] = []
        
        for messageDict in messages {
            guard let role = messageDict["role"] as? String,
                  let parts = messageDict["parts"] as? [[String: Any]] else {
                continue
            }
            
            var messageParts: [MessagePart] = []
            
            for part in parts {
                if let text = part["text"] as? String {
                    messageParts.append(.text(text))
                } else if let inlineData = part["inline_data"] as? [String: Any],
                          let data = inlineData["data"] as? String,
                          let mimeType = inlineData["mime_type"] as? String {
                    messageParts.append(.image(data, mimeType: mimeType))
                }
            }
            
            if !messageParts.isEmpty {
                result.append(Message(role: role, parts: messageParts))
            }
        }
        
        return result
    }
    
    // 디버깅을 위한 메시지 로그 출력
    func logMessages(_ messages: [[String: Any]], prefix: String = "") {
        print("\(prefix) 메시지 개수: \(messages.count)")
        for (index, message) in messages.enumerated() {
            print("\(prefix) 메시지 #\(index):")
            if let role = message["role"] as? String {
                print("\(prefix)   역할: \(role)")
            }
            if let parts = message["parts"] as? [[String: Any]] {
                print("\(prefix)   파트 개수: \(parts.count)")
                for (partIndex, part) in parts.enumerated() {
                    print("\(prefix)     파트 #\(partIndex):")
                    if let text = part["text"] as? String {
                        let shortText = text.count > 30 ? "\(text.prefix(30))..." : text
                        print("\(prefix)       텍스트: \(shortText)")
                    } else if let inlineData = part["inline_data"] as? [String: Any] {
                        print("\(prefix)       이미지: \(inlineData["mime_type"] ?? "알 수 없는 타입")")
                    } else {
                        print("\(prefix)       알 수 없는 파트 형식")
                    }
                }
            }
        }
    }
}
