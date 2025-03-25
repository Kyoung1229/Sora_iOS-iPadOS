import SwiftUI
import SwiftData
var messages: [[String: Any]] = []
var model: String = ""
var apiKey: String = ""
var streamingText: String = ""
var oldMessage: String = ""

struct ChatView_Legacy: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var conversations: [SoraConversationsDatabase]
    @State private var isAtBottom: Bool = false

    var CVUUID: UUID
    // 실제 API 키와 모델 (실제 값으로 변경)
    // 각 메시지는 "role"과 "parts" (parts 배열 내 "text") 형태로 저장됨
    @State private var messagesUI: [[String: Any]] = []
    @State private var lastMessage: String = ""
    @State private var lastChunk: String = ""
    @State private var inputText: String = ""
    // 실시간 스트리밍 응답 누적용 (화면 업데이트용)
    @State private var title: String = ""
    @State var conversation: SoraConversationsDatabase?
    
    // finishReason 상태 추가
    @State private var finishReason: String? = nil
    @State private var isStreamingCompleted: Bool = true // 처음에는 완료 상태
    @State private var isFirstMessageSent: Bool = false
    @State private var messageId: UUID = UUID() // 현재 진행 중인 메시지의 고유 ID
    
    // MessagesManager 인스턴스 (appendText, appendChunk, extractAnswer 함수 포함)
    let messagesManager = MessagesManager()
    
    var body: some View {
        ZStack {
            Color("BackgroundColor")
                .frame(maxHeight: .infinity)

            VStack {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            // 이전 대화 메시지들
                            ForEach(0..<messagesUI.count, id: \.self) { index in
                                if let role = messagesUI[index]["role"] as? String {
                                    let parts = messagesUI[index]["parts"] as? [[String: Any]]
                                    let text = parts?.first?["text"] as? String
                                    if role == "user" {
                                        ChatBubble_User(message: text ?? "")
                                            .id(index)
                                    } else if role == "model" && index != messagesUI.count - 1 {
                                        ChatBubble_Model(message: text ?? "")
                                            .id(index)
                                    }
                                }
                            }
                            
                            // 현재 진행 중인 메시지 표시 (안정적인 ID 사용)
                            if !lastMessage.isEmpty {
                                if isStreamingCompleted {
                                    ChatBubble_Model(message: lastMessage)
                                        .id(UUID())
                                        .transition(.opacity)
                                } else {
                                    ChatBubble_Model_Animate(
                                        baseMessage: oldMessage,
                                        updatedChunk: lastChunk,
                                        animationDuration: 0.3
                                    )
                                    .id(UUID())
                                    .transition(.opacity)
                                }
                            }
                            
                            // 스트리밍 완료 여부 표시
                            if isStreamingCompleted && finishReason != nil {
                                HStack {
                                    Spacer()
                                    Text("스트리밍 완료: \(finishReason ?? "")")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                        .padding(.top, 4)
                                        .opacity(0.7)
                                    Spacer()
                                }
                                .id("streaming-status")
                                .transition(.opacity)
                            }
                        }
                        .padding()
                        .onChange(of: lastMessage) { oldValue, newValue in
                            // 메시지가 변경될 때마다 스크롤을 맨 아래로 이동
                            withAnimation {
                                if isStreamingCompleted {
                                    proxy.scrollTo("streaming-status", anchor: .bottom)
                                } else {
                                    proxy.scrollTo("current-message-animate", anchor: .bottom)
                                }
                            }
                        }
                    }
                    .frame(minWidth: 400)
                }                
                // 입력창 및 전송 버튼 영역
                
            }
            .safeAreaInset(edge: .top) {
                ChatViewTopPanel(title: conversation?.title ?? "새로운 대화")
            }
            .safeAreaInset(edge: .bottom) {
                VStack {
                    HStack {
                        TextField("메시지 입력", text: $inputText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Button("전송") { sendMessage() }
                            .disabled(inputText.isEmpty || !isStreamingCompleted)
                    }
                    .padding()
                }
                .background(.ultraThinMaterial)
            }
        }
        .frame(maxHeight: .infinity)
        .onAppear {
            //init
            model = conversation?.model ?? "gemini-2.0-flash"
            title = conversation?.title ?? "새로운 대화"
            apiKey = SoraAPIKeys.shared.load(api: .gemini) ?? ""
            
            //SwiftData init
            // onAppear에서 한 번만 conversation을 fetch하여 @State에 저장
            let predicate = #Predicate<SoraConversationsDatabase> { $0.id == CVUUID }
            let descriptor = FetchDescriptor<SoraConversationsDatabase>(predicate: predicate)
            if let fetched = try? modelContext.fetch(descriptor).first {
                conversation = fetched
                if let conversationMessages = conversation?.messages, !conversationMessages.isEmpty {
                    messages = messagesManager.decodeMessages(conversationMessages)
                    messagesUI = messages
                }
            } else {
                // 없으면 새로 생성
                let newChat = SoraConversationsDatabase(chatType: "assistant", model: "gemini-2.0-flash")
                modelContext.insert(newChat)
                print("New Chat Created! UUID: \(newChat.id)")
                conversation = newChat
            }
        }
    }
    
    // 메시지 전송 및 스트리밍 응답 처리 함수
    func sendMessage() {
        guard !inputText.isEmpty else { return }
        
        // 새 메시지 시작 시 상태 초기화
        messageId = UUID() // 새 메시지에 대한 고유 ID 생성
        lastMessage = ""
        lastChunk = ""
        
        // 기존 메시지가 없다면 초기화
        if messages.isEmpty {
            messages = messagesManager.decodeMessages(conversation?.messages ?? "[]")
        }
        
        // 상태 초기화 - 애니메이션과 함께
        withAnimation(.easeInOut(duration: 0.3)) {
            isStreamingCompleted = false
            finishReason = nil
        }
        
        // 1. 사용자가 입력한 메시지를 Messages 배열에 추가 (user 메시지)
        let userInput = inputText
        messages = messagesManager.appendText(role: "user", content: userInput, messages: messages)
        messagesUI = messages
        
        inputText = ""
        streamingText = ""
        oldMessage = ""
        
        // 2. GeminiAPI의 스트리밍 호출: 각 청크(chunk)가 onChunk 클로저로 전달됨
        GeminiAPI().callWithStreaming(
            model: model,
            apiKey: apiKey,
            messages: messages,
            onChunk: { chunk in
                DispatchQueue.main.sync {
                    // extractAnswer를 사용하여 청크에서 텍스트 추출 (실패 시 기본적으로 chunk 사용)
                    let extracted = messagesManager.extractAnswer(from: chunk) ?? ""
                    if extracted.isEmpty { return } // 빈 응답은 무시
                    
                    // 애니메이션을 위한 텍스트 상태 관리
                    oldMessage = streamingText
                    streamingText += extracted
                    
                    // 마지막 메시지가 이미 모델 메시지라면 새 청크만 이어 붙임, 아니면 최초 한 번만 새 모델 메시지 생성
                    if messages.last?["role"] as? String == "model" {
                        messages = messagesManager.appendChunk(content: extracted, messages: messages)
                        withAnimation(.easeIn(duration: 0.2)) {
                            lastMessage += extracted
                            lastChunk = extracted
                        }
                    } else {
                        messages = messagesManager.appendText(role: "model", content: extracted, messages: messages)
                        withAnimation(.easeIn(duration: 0.2)) {
                            lastMessage = extracted
                            lastChunk = extracted
                        }
                    }
                    print(lastMessage)
                    
                    // UI 업데이트
                    if !isFirstMessageSent {
                        isFirstMessageSent = true
                    }
                    messagesUI = messages
                }
            },
            onComplete: { reason in
                DispatchQueue.main.sync {
                    // 스트리밍 완료 시 애니메이션과 함께 상태 변경
                    withAnimation(.easeInOut(duration: 0.5)) {
                        finishReason = reason
                        isStreamingCompleted = true
                    }
                    
                    // 콘솔에 완료 상태 출력
                    print("🏁 스트리밍 완료! finishReason: \(reason ?? "없음")")
                    print(messages)
                    
                    // 데이터베이스에 대화 저장
                    conversation?.messages = messagesManager.encodeMessages(messages)
                }
            }
        )
    }
}

struct ChatView_Previews: PreviewProvider {
    static var previews: some View {
        ChatView_Legacy(CVUUID: UUID())
    }
}
