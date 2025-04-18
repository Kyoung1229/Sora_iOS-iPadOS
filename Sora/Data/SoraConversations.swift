import Foundation
import SwiftData

@Model
public final class SoraConversationsDatabase {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var isPinned: Bool
    public var messages: [Message] = []
    public var chatType: String
    public var model: String
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        title: String = "새로운 대화",
        isPinned: Bool = false,
        messages: [Message] = [],
        chatType: String,
        model: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.isPinned = isPinned
        self.messages = messages
        self.chatType = chatType
        self.model = model
        self.createdAt = createdAt
    }

}

