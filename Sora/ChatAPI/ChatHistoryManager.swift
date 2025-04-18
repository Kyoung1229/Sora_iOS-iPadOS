import UIKit
import SwiftData

@MainActor // ModelContext 접근은 메인 액터에서 수행하는 것이 안전
final class ChatHistoryManager {
    private var modelContext: ModelContext
    // 관리할 특정 대화 객체
    private var currentConversation: SoraConversationsDatabase

    // ModelContext와 관리할 대화 객체를 주입받음
    init(modelContext: ModelContext, conversation: SoraConversationsDatabase) {
        self.modelContext = modelContext
        self.currentConversation = conversation
        // ✅ messages는 이제 non-optional이므로 nil 체크 불필요
        // if self.currentConversation.messages == nil {
        //     self.currentConversation.messages = []
        // }
    }

    // 현재 대화에 속한 메시지들을 가져옴 (timestamp 기준 정렬)
    var messages: [Message] {
        // ✅ currentConversation.messages는 non-optional이므로 guard let 불필요
        // guard let messages = currentConversation.messages else { return [] }
        // 바로 접근하여 정렬
        return currentConversation.messages.sorted { $0.timestamp < $1.timestamp }

        // --- 또는 FetchDescriptor 사용 예시 (Message에 conversationID가 있다고 가정) ---
        /*
        let conversationID = currentConversation.id
        do {
            var descriptor = FetchDescriptor<Message>(
                predicate: #Predicate { $0.conversation?.id == conversationID }, // 관계를 통해 필터링
                sortBy: [SortDescriptor(\.timestamp, order: .forward)]
            )
            return try modelContext.fetch(descriptor)
        } catch {
            print(\"Error fetching messages for conversation \\(conversationID): \\(error)\")
            return []
        }
         */
    }

    // 현재 대화에 사용자 메시지를 추가하는 메서드
    func addUser(text: String,
                 image: UIImage? = nil,
                 fileURL: URL?   = nil)
    {
        var imgB64 = ""
        if let img = image { imgB64 = encodeImageToBase64(img) } // encodeImageToBase64는 Utility.swift에 있어야 함

        var fileB64 = "", fileMime = "", fileName = ""
        if let url = fileURL {
            let v = encodeFileToBase64(url) // encodeFileToBase64는 Utility.swift에 있어야 함
            fileB64 = v.b64; fileMime = v.mime; fileName = v.name
        }

        // Message 생성 시 현재 대화(currentConversation)를 연결
        let msg = Message(role: "user",
                          text: text,
                          imageBase64: imgB64,
                          imageMime: "image/png", // 필요시 이미지 타입 감지 로직 추가
                          fileBase64: fileB64,
                          fileMime: fileMime,
                          fileName: fileName,
                          conversation: currentConversation) // ✅ 대화 연결

        // SwiftData에 메시지 삽입 (자동으로 관계 설정됨)
        modelContext.insert(msg)
        // ✅ messages는 non-optional이므로 옵셔널 체이닝 제거
        currentConversation.messages.append(msg)
        saveContext()
    }

    // 외부에서 생성된 Message 객체를 현재 대화에 추가하는 메서드
    func append(_ m: Message) {
        // 메시지에 현재 대화 연결 확인 및 설정
        if m.conversation == nil {
            m.conversation = currentConversation
        } else if m.conversation?.id != currentConversation.id {
            // 만약 다른 대화에 연결되어 있다면 오류 처리 또는 재연결 로직 필요
            print("Warning: Appending message already linked to a different conversation.")
            m.conversation = currentConversation // 강제로 현재 대화에 재연결 (정책에 따라 다름)
        }

        modelContext.insert(m)
        // ✅ messages는 non-optional이므로 옵셔널 체이닝 제거
        currentConversation.messages.append(m) // 관계 배열에도 추가
        saveContext()
    }

    // 현재 대화의 모든 메시지를 삭제하는 메서드
    func reset() {
        // ✅ messages는 non-optional이므로 guard let 불필요
        // guard let messagesToDelete = currentConversation.messages else { return }
        let messagesToDelete = currentConversation.messages

        // ✅ messages는 non-optional이므로 옵셔널 체이닝 제거
        currentConversation.messages.removeAll()

        // 각 메시지를 ModelContext에서 삭제
        for message in messagesToDelete {
            modelContext.delete(message)
        }
        saveContext()

        // --- 또는 FetchDescriptor와 delete(model:where:) 사용 ---
        /*
        let conversationID = currentConversation.id
        do {
            try modelContext.delete(model: Message.self, where: #Predicate { $0.conversation?.id == conversationID })
            currentConversation.messages?.removeAll() // 관계 배열 비우기
            saveContext()
        } catch {
            print(\"Error deleting messages for conversation \\(conversationID): \\(error)\")
        }
         */
    }

    // 변경사항을 저장하는 도우미 메서드
    private func saveContext() {
        do {
            try modelContext.save()
        } catch {
            // 실제 앱에서는 오류 처리 로직 필요
            print("Error saving context: \(error)")
        }
    }
}
