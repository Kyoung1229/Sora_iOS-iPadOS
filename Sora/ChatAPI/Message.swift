import Foundation
import SwiftData

/// 대화 한 턴을 나타내는 모델
@Model
public final class Message {
    @Attribute(.unique) public var id: UUID
    public var role: String              // "system", "user", "assistant", "tool", "function"
    public var timestamp: Date          // 메시지 생성 시간 (정렬 및 식별용)

    // MessagePart 배열을 JSON Data로 저장
    private var partsData: Data?
    // 계산 프로퍼티로 partsData를 인코딩/디코딩
    public var parts: [MessagePart] {
        get {
            guard let data = partsData else { return [] }
            // JSON 디코딩 시 오류 처리 강화
            do {
                return try JSONDecoder().decode([MessagePart].self, from: data)
            } catch {
                print("Error decoding MessagePart: \(error)")
                return []
            }
        }
        set {
            // JSON 인코딩 시 오류 처리 강화
            do {
                partsData = try JSONEncoder().encode(newValue)
            } catch {
                print("Error encoding MessagePart: \(error)")
                partsData = nil
            }
        }
    }

    // SoraConversationsDatabase와의 관계 설정
    public var conversation: SoraConversationsDatabase? // 각 메시지가 속한 대화

    /// 텍스트 전용 생성자
    public init(
        id: UUID = UUID(), // id 기본값 제공
        role: String,
        parts: [MessagePart],
        timestamp: Date = Date(), // timestamp 기본값 제공
        conversation: SoraConversationsDatabase? = nil // conversation 추가
    ) {
        self.id = id
        self.role = role
        self.timestamp = timestamp
        self.conversation = conversation // conversation 할당
        // parts 설정 시 계산 프로퍼티 setter 사용
        self.parts = parts
    }

    /// 텍스트 + 이미지(Base64) + 파일(Base64) 한 번에 생성
    public convenience init(
        role: String,
        text: String = "",
        imageBase64: String = "",
        imageMime: String = "image/png",
        fileBase64: String = "",
        fileMime: String = "",
        fileName: String = "",
        conversation: SoraConversationsDatabase? = nil // conversation 추가
    ) {
        var arr: [MessagePart] = []
        if !text.isEmpty {
            arr.append(.text(text))
        }
        if !imageBase64.isEmpty {
            arr.append(.image(base64: imageBase64, mimeType: imageMime))
        }
        if !fileBase64.isEmpty {
            arr.append(.file(base64: fileBase64, mimeType: fileMime, fileName: fileName))
        }
        self.init(role: role, parts: arr, conversation: conversation)
    }

    // 편의 생성자 수정: conversation을 nil 또는 전달받도록 수정
    public convenience init(role: String, text: String, conversation: SoraConversationsDatabase? = nil) {
        self.init(role: role, parts: [.text(text)], conversation: conversation)
    }
}

/// 메시지의 세부 파트
public enum MessagePart: Codable, Equatable, Hashable {
    case text(String)
    case image(base64: String, mimeType: String)
    case file(base64: String, mimeType: String, fileName: String)
    // toolCall의 arguments는 [String: String]으로 제한 (Any는 Codable 불가)
    // 또는 별도의 Codable 구조체로 정의 필요
    case toolCall(name: String, arguments: [String: String], description: String, id: String, callId: String)

    // 직접 코딩/디코딩 로직 구현 (enum은 자동 합성이 안 될 수 있음)
    enum CodingKeys: CodingKey {
        case type, textPayload, imagePayload, filePayload, toolCallPayload
    }
    
    public enum PayloadType: String, Codable {
        case text, image, file, toolCall
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(PayloadType.self, forKey: .type)

        switch type {
        case .text:
            let text = try container.decode(String.self, forKey: .textPayload)
            self = .text(text)
        case .image:
            let payload = try container.decode(ImagePayload.self, forKey: .imagePayload)
            self = .image(base64: payload.base64, mimeType: payload.mimeType)
        case .file:
            let payload = try container.decode(FilePayload.self, forKey: .filePayload)
            self = .file(base64: payload.base64, mimeType: payload.mimeType, fileName: payload.fileName)
        case .toolCall:
            let payload = try container.decode(ToolCallPayload.self, forKey: .toolCallPayload)
            self = .toolCall(name: payload.name, arguments: payload.arguments, description: payload.description, id: payload.id, callId: payload.callId)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let text):
            try container.encode(PayloadType.text, forKey: .type)
            try container.encode(text, forKey: .textPayload)
        case .image(let base64, let mimeType):
            try container.encode(PayloadType.image, forKey: .type)
            try container.encode(ImagePayload(base64: base64, mimeType: mimeType), forKey: .imagePayload)
        case .file(let base64, let mimeType, let fileName):
            try container.encode(PayloadType.file, forKey: .type)
            try container.encode(FilePayload(base64: base64, mimeType: mimeType, fileName: fileName), forKey: .filePayload)
        case .toolCall(let name, let arguments, let description, let id, let callId):
            try container.encode(PayloadType.toolCall, forKey: .type)
            try container.encode(ToolCallPayload(name: name, arguments: arguments, description: description, id: id, callId: callId), forKey: .toolCallPayload)
        }
    }

    // Payload 구조체 정의
    public struct ImagePayload: Codable, Hashable { 
        public let base64: String
        public let mimeType: String
        
        public init(base64: String, mimeType: String) {
            self.base64 = base64
            self.mimeType = mimeType
        }
    }
    
    public struct FilePayload: Codable, Hashable { 
        public let base64: String
        public let mimeType: String
        public let fileName: String
        
        public init(base64: String, mimeType: String, fileName: String) {
            self.base64 = base64
            self.mimeType = mimeType
            self.fileName = fileName
        }
    }
    
    public struct ToolCallPayload: Codable, Hashable { 
        public let name: String
        public let arguments: [String: String]
        public let description: String
        public let id: String
        public let callId: String
        
        public init(name: String, arguments: [String: String], description: String, id: String, callId: String) {
            self.name = name
            self.arguments = arguments
            self.description = description
            self.id = id
            self.callId = callId
        }
    }
}
