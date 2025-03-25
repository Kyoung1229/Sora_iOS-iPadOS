import Foundation
import SwiftData

@Model
class SoraConversationsDatabase {
    @Attribute(.unique) var id: UUID
    var title: String
    var isPinned: Bool
    var messages: String // ✅ JSON 형태로 저장
    var chatType: String
    var model: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String = "새로운 대화",
        isPinned: Bool = false,
        messages: [[String: Any]] = [], // ✅ 기본값
        chatType: String,
        model: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.isPinned = isPinned
        self.messages = MessagesManager().encodeMessages(messages) // ✅ JSON으로 변환
        self.chatType = chatType
        self.model = model
        self.createdAt = createdAt
    }

}

