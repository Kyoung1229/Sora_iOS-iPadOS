import SwiftUI
import SwiftData
import PhotosUI
import CoreHaptics
import AVFoundation

// 메시지 타입 정의
enum MessageRole: String, Codable {
    case user
    case model
}

// UI 강제 업데이트를 위한 Modifier
struct ForceUpdateViewModifier: ViewModifier {
    var update: Bool
    
    func body(content: Content) -> some View {
        content.id(update)
    }
}

// StreamingStorage 구조체를 간소화하고 필수 기능만 유지합니다
struct StreamingStorage {
    static var currentText: String = ""
    static var chunksCount: Int = 0
    static var messageId: UUID = UUID()
    
    // 간소화된 초기화 함수
    static func reset() {
        currentText = ""
        chunksCount = 0
        messageId = UUID()
        print("🔄 StreamingStorage 초기화됨")
    }
    
    // 텍스트 추가 및 캐시 관리 기능만 유지
    static func appendText(_ text: String) {
        // 마지막 개행 문자 제거
        let cleanedText = text.hasSuffix("\n") ? String(text.dropLast()) : text
        
        currentText += cleanedText
        chunksCount += 1
        
        // 너무 큰 텍스트 관리 (단순화된 로직)
        if currentText.count > 100000 { // 10만 자 제한
            currentText = String(currentText.suffix(90000)) // 앞부분 제거하고 9만 자만 유지
            print("⚠️ 텍스트가 너무 커서 앞부분을 자름")
        }
    }
}

struct MessageItem: Identifiable, Equatable {
    let id = UUID()
    let role: MessageRole
    let content: String
    let imageData: Data?
    let timestamp: Date
    
    static func == (lhs: MessageItem, rhs: MessageItem) -> Bool {
        return lhs.id == rhs.id
    }
}

struct NewChatView: View {
    // MARK: - 환경 변수
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    // MARK: - 상태 변수
    @State private var inputText = ""
    @State private var messages: [MessageItem] = []
    @State private var showSideMenu = false
    @State private var keyboardHeight: CGFloat = 0
    @State private var isKeyboardVisible = false
    @State private var scrollToBottomTrigger = false
    @State private var forceUIUpdate = false
    
    // MARK: - 스크롤 관련
    @State private var scrollViewProxy: ScrollViewProxy?
    @State private var bottomID = "bottom"
    
    // MARK: - 제스처 감지용
    @StateObject private var gyro = GyroManager()
    
    // MARK: - ChatService 선언
    @StateObject private var chat = ChatService(modelContext: modelContext)
    
    // MARK: - 대화 관련
    let model: String
    var conversationId: UUID
    @State private var conversation: SoraConversationsDatabase?
    
    // 대화 관련 상태
    @State private var isStreamingResponse: Bool = false
    @State private var currentStreamedText: String = ""
    @State private var previousStreamedText: String = ""
    @State private var hasNewInput: Bool = false
    @State private var finishReason: String? = nil
    @State private var lastReceivedChunk: [String: Any] = [:]
    
    // 추가 상태 변수
    @State private var streamingMessageId: UUID = UUID() // 스트리밍 중인 메시지의 고유 ID
    @State private var isAnimating: Bool = false // 애니메이션 상태 관리
    @State private var streamedChunksCount: Int = 0
    @State private var isRecoveredFromReset: Bool = false
    
    // UI 애니메이션 관련 상태
    @Namespace private var bottomIDmo
    
    var body: some View {
        ZStack(alignment: .top) {
            // 배경색
            Color("BackgroundColor")
                .ignoresSafeArea()
            
            // 메인 콘텐츠
            ZStack(alignment: .bottom) {
                // 메시지 스크롤 영역
                GeometryReader { geometry in
                    ZStack(alignment: .center) {
                        ScrollViewReader { scrollView in
                            ScrollView {
                                LazyVStack(spacing: 24) {
                                    // 상단 여백 (네비게이션 바를 위한 공간)
                                    Rectangle()
                                        .frame(height: 65)
                                        .foregroundColor(.clear)
                                    
                                    // 메시지 목록
                                    ForEach(messages) { message in
                                        Group {
                                            if message.role == .user {
                                                ChatBubble_User(message: message.content)
                                                    .id(message.id)
                                                    .transition(.asymmetric(
                                                        insertion: .opacity.combined(with: .scale(scale: 0.95).combined(with: .move(edge: .bottom))).animation(.spring(response: 0.4, dampingFraction: 0.7)),
                                                        removal: .opacity.animation(.easeOut(duration: 0.2))
                                                    ))
                                            } else {
                                                ChatBubble_Model(message: message.content)
                                                    .id(message.id)
                                                    
                                            }
                                        }
                                    }
                                    
                                    // 스트리밍 중인 메시지
                                    if isStreamingResponse && !currentStreamedText.isEmpty {
                                        VStack(alignment: .leading, spacing: 8) {
                                            ChatBubble_Model_Animate(
                                                baseMessage: previousStreamedText,
                                                updatedChunk: String(currentStreamedText.dropFirst(previousStreamedText.count)),
                                                animationDuration: 0.3
                                            )
                                            // 보다 안정적인 ID 시스템 (길이 기반)
                                            .id("streaming-\(currentStreamedText.count)")
                                            // 적절한 애니메이션 추가
                                            .transition(.opacity)

                                            // UI 업데이트 모디파이어
                                            .modifier(ForceUpdateViewModifier(update: forceUIUpdate))
                                        }
                                        // 콘텐츠 전체를 위한 ID 추가
                                        .id("stream-container-\(streamingMessageId)")
                                    }
                                    
                                    // 하단 여백 (스크롤을 위한 앵커)
                                    Rectangle()
                                        .frame(height: 85) // 키보드 입력창 높이 + 여백
                                        .foregroundColor(.clear)
                                        .id(bottomID)
                                }
                                .padding(.horizontal, 16)
                            }
                            .contentShape(Rectangle()) // 빈 공간에서도 제스처가 동작하도록 설정
                            .onTapGesture {
                                // 여백 탭 시 키보드 닫기
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            }
                            .onAppear {
                                self.scrollViewProxy = scrollView
                                // 초기 스크롤
                                triggerScrollToBottom()
                            }
                            .onChange(of: messages.count) { _, _ in
                                // 메시지 추가 시 스크롤
                                triggerScrollToBottom()
                            }
                            .onChange(of: forceUIUpdate) { _, _ in
                                // 강제 업데이트 상태가 변경될 때마다 스크롤 및 상태 확인
                                if isStreamingResponse {
                                    print("🔄 UI 강제 업데이트 발생: 현재 텍스트 길이=\(currentStreamedText.count)")
                                    
                                    // 스트리밍 메시지가 표시되고 있는데 텍스트가 빈 경우 복구 시도
                                    if currentStreamedText.isEmpty && !StreamingStorage.currentText.isEmpty {
                                        withAnimation(.easeIn(duration: 0.2)) {
                                            currentStreamedText = StreamingStorage.currentText
                                            print("⚠️ onChange에서 텍스트 복구: \(StreamingStorage.currentText.count)자")
                                        }
                                    }
                                }
                            }
                        }

                    }
                }
                
                // 입력 필드 - 하단에 고정
                VStack(spacing: 0) {
                    Spacer()
                    TextInputField(
                        text: $inputText,
                        onSend: {
                            let trimmedText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmedText.isEmpty {
                                sendMessage()
                            }
                        },
                        onMediaButtonTap: nil, // 사진 업로드 기능 비활성화
                        isStreaming: isStreamingResponse,
                        autoFocus: false // 자동 포커스 비활성화
                    )
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                }
            }
            
            ZStack {
                GlassRectangle(gyro: gyro, cornerRadius: 29, width: UIScreen.main.bounds.width * 0.9, height: 60)
                // 상단 헤더 (항상 위에 표시)
                HStack {
                    // 뒤로가기 버튼
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                            .padding(8)
                            .background(Circle().fill(Color("ChatBubbleBackgroundColor_User")))
                            .foregroundColor(.primary)
                    }
                    .padding(.leading, 15)
                    
                    Spacer()
                    
                    // 제목
                    Text(conversation?.title ?? "새로운 대화")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    // 메뉴 버튼
                    Button {
                        withAnimation(.smooth) {
                            showSideMenu = true
                        }
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.title3)
                            .padding(8)
                            .background(Circle().fill(Color("ChatBubbleBackgroundColor_User")))
                            .foregroundColor(.primary)
                    }
                    .padding(.trailing, 15)
                }
                .frame(alignment: .top)
                .ignoresSafeArea()
                .padding(.horizontal)
                .padding(.top)
                .padding(.bottom, 15)
            }
            
            // 우측 메뉴 오버레이
            if showSideMenu {
                // 뒷 배경 (탭하면 메뉴 닫힘)
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.smooth) {
                            showSideMenu = false
                        }
                    }
                
                // 사이드 메뉴
                HStack(spacing: 0) {
                    Spacer()
                    
                    ChatSideMenuView(
                        conversation: conversation ?? SoraConversationsDatabase(chatType: "assistant", model: model),
                        apiKey: SoraAPIKeys.shared.load(api: .gemini) ?? "",
                        onClose: {
                            withAnimation(.smooth) {
                                showSideMenu = false
                            }
                            // 메뉴가 닫힐 때 대화 정보 갱신
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                loadConversation()
                            }
                        }
                    )
                    .padding(.trailing, 20)
                    .transition(.move(edge: .trailing))
                }
                .zIndex(2)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            // ChatService 초기화
            chat.apiKey = SoraAPIKeys.shared.load(api: .gemini) ?? ""
            chat.initialize()
            
            // 키보드 감지 설정
            NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { notification in
                if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                    keyboardHeight = keyboardFrame.height
                    isKeyboardVisible = true
                    triggerScrollToBottom()
                }
            }
            
            NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
                keyboardHeight = 0
                isKeyboardVisible = false
            }
            
            loadConversation()
            
            // ChatService의 메시지 업데이트 감지
            chat.onMessageUpdate = { [weak self] in
                self?.updateMessages()
            }
        }
    }
    
    // MARK: - 대화 로드 함수
    private func loadConversation() {
        // API 키 설정
        chat.apiKey = SoraAPIKeys.shared.load(api: .gemini)
        
        if chat.apiKey.isEmpty {
            // API 키가 없을 경우 처리
            print("API 키가 설정되지 않았습니다.")
            return
        }
        
        // 기존 대화 불러오기 (데이터베이스)
        let fetchDescriptor = FetchDescriptor<SoraConversationsDatabase>(
            predicate: #Predicate { $0.id == conversationId }
        )
        
        do {
            let fetchedConversations = try modelContext.fetch(fetchDescriptor)
            if let existingConversation = fetchedConversations.first {
                conversation = existingConversation
                messages = existingConversation.messages
                chat.setupExistingConversation(messages: messages, conversationId: conversationId)
                print("기존 대화를 불러왔습니다: \(messages.count)개 메시지")
            } else {
                // 새 대화 생성
                print("새 대화를 생성합니다: \(conversationId)")
                let newConversation = SoraConversationsDatabase(
                    id: conversationId,
                    title: "새 대화",
                    model: model,
                    chatType: "assistant",
                    messages: []
                )
                conversation = newConversation
                modelContext.insert(newConversation)
                
                // 새 대화 설정
                chat.setupNewConversation(model: model, conversationId: conversationId)
            }
            
            // 메시지 업데이트 구독
            chat.onMessagesUpdated = { [weak self] updatedMessages in
                self?.updateMessages(updatedMessages)
            }
        } catch {
            print("대화를 불러오는 중 오류 발생: \(error)")
        }
    }
    
    // MARK: - 메시지 업데이트
    private func updateMessages(_ updatedMessages: [MessageItem]) {
        // UI 스레드에서 실행
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.3)) {
                self.messages = updatedMessages
                self.forceUIUpdate.toggle() // 강제 UI 업데이트 트리거
                
                // 스크롤 트리거 설정
                if !self.messages.isEmpty {
                    self.scrollToBottomTrigger.toggle()
                }
            }
            
            // 모델 컨텍스트에 저장
            self.conversation?.messages = self.messages
            try? self.modelContext.save()
        }
    }
    
    // MARK: - 메시지 전송
    private func sendMessage() {
        // 중복 제출 방지
        let trimmedText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        let userMessageText = trimmedText
        inputText = "" // 입력 필드 초기화
        
        // 메시지 전송 및 응답 처리
        chat.sendMessage(userMessageText)
        
        // 메시지 전송 후 스크롤 처리
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.scrollToBottomTrigger.toggle()
        }
    }
    
    // 메시지 처리 추가 확인용 함수
    private func debugPrintMessages() {
        print("===== 현재 메시지 상태 =====")
        print("총 메시지 수: \(messages.count)")
        for (index, message) in messages.enumerated() {
            print("메시지 #\(index): 역할=\(message.role), 텍스트=\(message.content.prefix(30))...")
        }
        print("===========================")
    }
    
    // 스크롤을 맨 아래로 이동 (애니메이션 적용)
    private func scrollToBottom() {
        withAnimation(.easeOut(duration: 0.3)) {
            scrollViewProxy?.scrollTo(bottomID, anchor: .bottom)
        }
    }
    func triggerStreamingHaptic() {
        HapticManager().light()
    }
    // 스크롤 트리거 함수
    private func triggerScrollToBottom() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 0.5)) {
                self.scrollViewProxy?.scrollTo(self.bottomID, anchor: .bottom)
            }
        }
    }
    
    // JSON 데이터 포맷팅 함수 추가
    private func formatJSON(_ jsonString: String) -> String {
        guard let data = jsonString.data(using: .utf8) else { return jsonString }
        do {
            let json = try JSONSerialization.jsonObject(with: data, options: [])
            let prettyData = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted])
            return String(data: prettyData, encoding: .utf8) ?? jsonString
        } catch {
            return jsonString
        }
    }
}

// 메시지 버블 뷰
struct MessageBubble: View {
    let message: MessageItem
    
    var body: some View {
        HStack {
            if message.role == .model {
                VStack(alignment: .leading, spacing: 8) {
                    ChatBubble_Model(message: message.content)
                }
                Spacer()
            } else {
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
                    if let imageData = message.imageData, let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 200)
                            .cornerRadius(12)
                    }
                    
                    if !message.content.isEmpty {
                        ChatBubble_User(message: message.content)
                    }
                }
            }
        }
    }
}

// 미리보기
struct NewChatView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            NewChatView(conversationId: UUID().uuidString, model: "gemini-2.0-flash")
        }
    }
} 
