import Foundation
import UIKit
import Combine
import SwiftData

@MainActor
public final class ChatService: ObservableObject {
    // MARK: - Published Properties
    @Published public var lastStreamingText: String = ""
    @Published public var apiLogs: [String] = []
    @Published public var isProcessing: Bool = false
    
    // MARK: - API 설정
    public var apiKey: String = ""
    
    // MARK: - 콜백 함수
    var onMessagesUpdated: (([MessageItem]) -> Void)?
    
    // MARK: - Internal Clients & History
    private var history: ChatHistoryManager?
    private var geminiAPI = GeminiAPI()
    private var openaiAPI = OpenAIAPI()
    
    // MARK: - ModelContext & Current Conversation
    private var modelContext: ModelContext
    private var currentConversation: SoraConversationsDatabase?
    private var conversationId: String = ""
    private var currentModel: String = "gemini-2.0-flash"
    private var currentMessages: [MessageItem] = []
    
    // MARK: - 초기화
    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
        log("ChatService initialized with ModelContext.")
    }
    
    
    // MARK: - 새 대화 설정
    public func setupNewConversation(model: String, conversationId: String) {
        self.currentModel = model
        self.conversationId = conversationId
        self.currentMessages = []
        log("새 대화가 설정되었습니다. 모델: \(model), ID: \(conversationId)")
        objectWillChange.send()
    }
    
    // MARK: - 기존 대화 설정
    func setupExistingConversation(messages: [MessageItem], conversationId: String) {
        self.currentMessages = messages
        self.conversationId = conversationId
        log("기존 대화가 설정되었습니다. ID: \(conversationId), 메시지 수: \(messages.count)")
        objectWillChange.send()
    }
    
    // MARK: - 메시지 전송
    public func sendMessage(_ text: String) {
        guard !isProcessing else {
            log("이미 메시지 처리 중입니다.")
            return
        }
        
        guard !apiKey.isEmpty else {
            log("API 키가 설정되지 않았습니다.")
            return
        }
        

        
        isProcessing = true
        
        // 사용자 메시지 추가
        let userMessage = MessageItem(role: .user, content: text, imageData: nil, timestamp: Date())
        currentMessages.append(userMessage)
        
        // 메시지 업데이트 콜백 호출
        onMessagesUpdated?(currentMessages)
        
        // 응답 생성 중 임시 메시지
        let assistantTypingMessage = MessageItem(role: .model, content: "...", imageData: nil, timestamp: Date())
        currentMessages.append(assistantTypingMessage)
        
        // 메시지 업데이트 콜백 호출
        onMessagesUpdated?(currentMessages)
        
        // Gemini API 호출
        let messages = convertToAPIDicts()
        
        geminiAPI.stream(
            model: currentModel,
            apiKey: apiKey,
            messageDicts: messages,
            tools: [],
            systemPrompt: "",
            onText: { chunk in
                Task { @MainActor in
                    // 누적 스트리밍 텍스트
                    self.lastStreamingText += chunk
                    // 업데이트 콜백에 전체 텍스트 전달
                    self.onMessagesUpdated?(self.currentMessages)
                    self.log("🔹 Gemini chunk: \(chunk)")
                }
            },
            onFunc: { call in
                Task { @MainActor in
                    self.log("🔧 Gemini func: \(call.name)")
                }
            },
            onDone: { finishReason, error in
                Task { @MainActor in
                    self.isProcessing = false
                    
                    if let error = error {
                        self.log("오류 발생: \(error.localizedDescription)")
                        
                        // 오류 메시지로 대체
                        if let lastIndex = self.currentMessages.indices.last {
                            self.currentMessages[lastIndex] = MessageItem(
                                role: .model,
                                content: "메시지 처리 중 오류가 발생했습니다: \(error.localizedDescription)",
                                imageData: nil,
                                timestamp: Date()
                            )
                            
                            // 메시지 업데이트 콜백 호출
                            self.onMessagesUpdated?(self.currentMessages)
                        }
                    } else {
                        self.log("메시지 처리 완료: \(finishReason ?? "unknown")")
                    }
                }
            }
        )
    }
    
    // MARK: - API 형식으로 메시지 변환
    private func convertToAPIDicts() -> [[String: Any]] {
        return currentMessages.map { message in
            var dict: [String: Any] = [
                "role": message.role == .user ? "user" : "model",
                "parts": [["text": message.content]]
            ]
            return dict
        }
    }
    
    // MARK: - 대화 내보내기
    func exportConversation() -> [MessageItem] {
        return currentMessages
    }
    
    // MARK: - Message Management
    
    public func setConversation(_ conversation: SoraConversationsDatabase) {
        self.currentConversation = conversation
        self.history = ChatHistoryManager(modelContext: modelContext, conversation: conversation)
        log("ChatService set to work with conversation: \(conversation.title) (ID: \(conversation.id))")
        objectWillChange.send()
    }
    
    public func addUser(
        text   : String,
        image  : UIImage? = nil,
        fileURL: URL?     = nil
    ) {
        guard let history = history else {
            log("Error: ChatHistoryManager not initialized. Call setConversation() first.")
            return
        }
        history.addUser(text: text, image: image, fileURL: fileURL)
        log("User message added to current conversation.")
        objectWillChange.send()
    }
    
    public var messages: [Message] {
        guard let history = history else {
            log("Warning: ChatHistoryManager not initialized. Returning empty messages.")
            return []
        }
        let fetchedMessages = history.messages
        log("Fetched \(fetchedMessages.count) messages for current conversation.")
        return fetchedMessages
    }
    
    // MARK: - LLM Call Entry
    
    public func run(
        model            : String,
        streaming        : Bool = true,
        tools            : [[String: Any]] = [],
        generationConfig : [String: Any]   = [:],
        instructions     : String          = "",
        systemPrompt     : String          = "",
        onUpdate         : @escaping (String)       -> Void,
        onToolCall       : @escaping (ToolCall)     -> Void,
        onDone           : @escaping (String?, Error?) -> Void
    ) {
        guard let history = history, let conversation = currentConversation else {
            log("Error: Conversation not set. Call setConversation() first.")
            onDone(nil, ChatServiceError.conversationNotSet)
            return
        }
        
        lastStreamingText = ""
        
        let provider = ModelProvider.detect(from: model)
        let currentMessages = history.messages
        let dicts = currentMessages.toDicts(provider: provider)
        
        log("➡️ Request: provider=\(provider) model=\(model) id=\(conversation.id)")
        log("   Messages (\(currentMessages.count)): \(dicts)")
        if !tools.isEmpty {
            log("   Tools: \(tools)")
        }
        if provider == .gemini && !systemPrompt.isEmpty {
            log("   systemPrompt: \(systemPrompt)")
        }
        if provider == .openai && !instructions.isEmpty {
            log("   instructions: \(instructions)")
        }
        if !generationConfig.isEmpty {
            log("   generationConfig: \(generationConfig)")
        }
        
        let handleResponse = { [weak self] (responseText: String?, finish: String?, error: Error?) in
            guard let self = self, let history = self.history, let conv = self.currentConversation else { return }
            Task { @MainActor in
                if let text = responseText, !text.isEmpty {
                    let msg = Message(role: "assistant", text: text, conversation: conv)
                    history.append(msg)
                    self.log("Assistant message added: \(text)")
                    self.objectWillChange.send()
                }
                onDone(finish, error)
            }
        }
        
        switch (provider, streaming) {
        case (.gemini, true):
            geminiAPI.stream(
                model        : model,
                apiKey: apiKey,
                messageDicts : dicts,
                tools        : tools,
                systemPrompt : systemPrompt,
                onText       : { chunk in
                    Task { @MainActor in
                        // 누적 스트리밍 텍스트
                        self.lastStreamingText = chunk
                        // 업데이트 콜백에 전체 텍스트 전달
                        onUpdate(self.lastStreamingText)
                        self.log("🔹 Gemini chunk: \(chunk)")
                    }
                },
                onFunc       : { call in
                    Task { @MainActor in self.log("🔧 Gemini func: \(call.name)") }
                },
                onDone       : { finish, err in
                    handleResponse(finish, "STOP", err)
                }
            )
        case (.gemini, false):
            geminiAPI.generate(
                model         : model,
                apiKey: apiKey,
                messages      : dicts,
                systemPrompt  : systemPrompt,
                generationCfg : generationConfig
            ) { result in
                var resp: String?; var err: Error?; var fin: String? = "stop"
                switch result {
                case .success(let json): resp = LLMResponseParser.textDelta(json, provider: .gemini); onUpdate(resp ?? ""); self.log("✅ Gemini response: \(resp ?? "")")
                case .failure(let e): err = e; fin = nil; self.log("❌ Gemini error: \(e.localizedDescription)")
                }
                handleResponse(resp, fin, err)
            }
        case (.openai, true):
            openaiAPI.stream(
                model        : model,
                apiKey: apiKey,
                input        : dicts,
                tools        : tools,
                instructions : instructions,
                onText       : { chunk in Task { @MainActor in onUpdate(chunk); self.log("🔹 OpenAI chunk: \(chunk)") } },
                onFunc       : { call in Task { @MainActor in self.log("🔧 OpenAI func: \(call.name)") } },
                onDone       : { finish, err in handleResponse(self.lastStreamingText, finish, err) }
            )
        case (.openai, false):
            openaiAPI.generate(
                model        : model,
                apiKey: apiKey,
                input        : dicts,
                instructions : instructions
            ) { result in
                var resp: String?; var err: Error?; var fin: String? = "stop"
                switch result {
                case .success(let json): resp = LLMResponseParser.textDelta(json, provider: .openai); onUpdate(resp ?? ""); self.log("✅ OpenAI response: \(resp ?? "")");
                case .failure(let e): err = e; fin = nil; self.log("❌ OpenAI error: \(e.localizedDescription)")
                }
                handleResponse(resp, fin, err)
            }
        }
    }
    
    // MARK: - Logging Helper
    private func log(_ msg: String) {
        let ts = ISO8601DateFormatter().string(from: Date())
        apiLogs.append("[\(ts)] \(msg)")
    }
    
    // MARK: - ChatService Error
    enum ChatServiceError: LocalizedError {
        case conversationNotSet
        
        var errorDescription: String? {
            switch self {
            case .conversationNotSet: return "ChatService에서 대화가 설정되지 않았습니다. setConversation()를 먼저 호출해주세요."
            }
        }
    }
}
