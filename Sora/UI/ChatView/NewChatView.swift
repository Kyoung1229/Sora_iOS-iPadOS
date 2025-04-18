import SwiftUI
import SwiftData
import PhotosUI

// 메시지 타입 정의
enum MessageRole: String {
    case user
    case model
}

// UI 강제 업데이트를 위한 Modifier
struct ForceUpdateViewModifier: ViewModifier {
    let update: Bool  // 사용되지 않지만 변경될 때 뷰를 다시 렌더링하도록 함
    
    func body(content: Content) -> some View {
        content
        // 이 modifier는 update 값이 변경될 때마다 뷰를 다시 렌더링
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
    @StateObject private var gyro = GyroManager()
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Query private var conversations: [SoraConversationsDatabase]
    
    // 대화 관련 상태
    @State private var messages: [MessageItem] = []
    @State private var inputText: String = ""
    @State var isStreamingResponse: Bool = false
    @State var currentStreamedText: String = ""
    @State var previousStreamedText: String = ""
    @State private var hasNewInput: Bool = false
    @State private var finishReason: String? = nil
    @State private var scrollToBottomTrigger: Bool = false // 스크롤 트리거
    @State private var lastReceivedChunk: [String: Any] = [:]
    
    // 스크롤 뷰 참조
    @State private var scrollViewProxy: ScrollViewProxy? = nil
    
    // API 관련 상태
    @State private var apiKey: String = ""
    @State private var model: String = "gemini-2.0-flash"
    @State private var showAPIKeyAlert: Bool = false
    @State private var showAPIKeySettings: Bool = false
    
    // 메시지 매니저
    private let messagesManager = MessagesManager()
    
    // 대화 컨텍스트
    var conversationId: UUID
    @State private var conversation: SoraConversationsDatabase?
    @State private var apiMessages: [[String: Any]] = []
    
    // 추가 상태 변수
    @State private var streamingMessageId: UUID = UUID() // 스트리밍 중인 메시지의 고유 ID
    @State private var isAnimating: Bool = false // 애니메이션 상태 관리
    @State private var streamedChunksCount: Int = 0
    @State private var isRecoveredFromReset: Bool = false
    @State var forceUIUpdate: Bool = false // 추가된 상태 변수
    
    // UI 애니메이션 관련 상태
    @State private var keyboardHeight: CGFloat = 0
    @State private var isKeyboardVisible: Bool = false
    @Namespace private var bottomID
    
    // 우측 메뉴 상태 추가
    @State private var showSideMenu = false
    
    // 스트리밍 메시지 UI 일관성 유지 메서드
    private func ensureStreamingConsistency() {
        // 메시지 및 스트리밍 상태 확인
        print("메시지 상태 확인: 총 \(messages.count)개 메시지, 스트리밍 상태=\(isStreamingResponse), 전역 텍스트 길이=\(StreamingStorage.currentText.count)")
        
        // 전역 저장소에 데이터가 있는지 확인
        if StreamingStorage.currentText.count > 0 && currentStreamedText.isEmpty {
            print("⚠️ 전역 저장소에 데이터가 있지만 현재 스트리밍 텍스트가 비어 있음. 복구 시도")
            currentStreamedText = StreamingStorage.currentText
            previousStreamedText = StreamingStorage.currentText
            streamingMessageId = UUID() // 새 ID 생성
            return
        }
        
        // 스트리밍 중인데 currentStreamedText가 비어있는 비정상 상태 감지
        if isStreamingResponse && currentStreamedText.isEmpty && apiMessages.count > 0 {
            // API 메시지에서 마지막 모델 응답 복구 시도
            if let modelMessage = apiMessages.last, 
               let role = modelMessage["role"] as? String, 
               role == "model",
               let parts = modelMessage["parts"] as? [[String: Any]], 
               let textPart = parts.first, 
               let text = textPart["text"] as? String,
               !text.isEmpty {
                
                print("🛠️ 스트리밍 메시지 복구: API에 저장된 텍스트 \(text.count)자 복구")
                
                // 상태 업데이트
                currentStreamedText = text
                previousStreamedText = text
                streamingMessageId = UUID() // 새 ID 생성
                
                // 전역 저장소도 업데이트
                StreamingStorage.currentText = text
                
                // 추적용 상태 업데이트
                isRecoveredFromReset = true
            }
        }
    }
    
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
        }
    }
    
    // MARK: - 대화 로드 함수
    private func loadConversation() {
        // API 키 확인 (앱 시작 시 null 체크)
        apiKey = SoraAPIKeys.shared.load(api: .gemini) ?? ""
        if apiKey.isEmpty {
            print("⚠️ 경고: Gemini API 키가 설정되지 않았습니다. 설정 화면에서 API 키를 설정해주세요.")
        } else {
            print("✅ Gemini API 키가 성공적으로 로드되었습니다.")
        }
        
        // SwiftData에서 대화 로드
        let predicate = #Predicate<SoraConversationsDatabase> { $0.id == conversationId }
        let descriptor = FetchDescriptor<SoraConversationsDatabase>(predicate: predicate)
        
        if let fetched = try? modelContext.fetch(descriptor).first {
            conversation = fetched
            
            // 대화 정보 로드
            if let conversationMessages = conversation?.messages, !conversationMessages.isEmpty {
                // 메시지 복원 (이전 메시지 초기화)
                apiMessages = messagesManager.decodeMessages(conversationMessages)
                
                // 메시지 배열 초기화 (중복 방지)
                messages = []
                
                // API 메시지를 MessageItem으로 변환
                apiMessages.forEach { message in
                    if let role = message["role"] as? String,
                       let parts = message["parts"] as? [[String: Any]],
                       let textPart = parts.first(where: { $0["text"] != nil }),
                       let text = textPart["text"] as? String {
                        
                        let messageRole = MessageRole(rawValue: role) ?? .user
                        messages.append(MessageItem(
                            role: messageRole,
                            content: text,
                            imageData: nil,
                            timestamp: Date()
                        ))
                    }
                }
                
                print("💬 대화 로드 성공: 메시지 \(messages.count)개")
                
                // 초기 로드 후 스크롤
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    triggerScrollToBottom()
                }
            } else {
                print("💬 새 대화 시작 (메시지 없음)")
            }
        } else {
            // 새 대화 생성
            let newChat = SoraConversationsDatabase(id: conversationId, chatType: "assistant", model: model)
            modelContext.insert(newChat)
            conversation = newChat
            print("🆕 새 대화 생성됨: \(conversationId)")
        }
    }
    
    // 메시지 전송 함수
    private func sendMessage() {
        // 중복 전송 방지
        guard !isStreamingResponse else {
            print("⚠️ 이미 스트리밍 중")
            return
        }
        
        // 텍스트가 비어있는 경우 반환
        let userMessageText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userMessageText.isEmpty else { return }
        
        // 키보드 숨기기
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        
        // 전역 저장소 초기화
        StreamingStorage.reset()
        
        // 새 스트리밍 메시지를 위한 ID 생성 (고유성 보장)
        streamingMessageId = UUID()
        StreamingStorage.messageId = streamingMessageId
        
        // UI 상태 초기화
        currentStreamedText = ""
        previousStreamedText = ""
        isStreamingResponse = true
        
        // 사용자 메시지 생성 및 추가
        let userMessage = MessageItem(
            role: .user,
            content: userMessageText,
            imageData: nil,
            timestamp: Date()
        )
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            messages.append(userMessage)
            inputText = ""  // 입력 필드 비우기
        }
        
        // API 메시지 업데이트
        apiMessages = messagesManager.appendText(
            role: "user",
            content: userMessageText,
            messages: apiMessages
        )
        
        // 스크롤
        triggerScrollToBottom()
        
        // API 호출
        print("📡 API 호출 시작: ID \(streamingMessageId)")
        
        // API 호출 - 텍스트만 전송
        GeminiAPI().callWithStreaming(
            model: model,
            apiKey: apiKey,
            messages: apiMessages,
            onChunk: { [self] chunk in
                processStreamChunk(chunk)
            },
            onComplete: { [self] reason in
                handleStreamComplete(reason)
            }
        )
    }
    
    // 프로세스 스트림 청크 메서드를 단순화하고 안정성 강화
    private func processStreamChunk(_ chunk: [String: Any]) {
        DispatchQueue.main.async { [self] in
            // 스트리밍 중이 아닌 경우 처리하지 않음
            guard self.isStreamingResponse else {
                print("⚠️ 스트리밍이 종료된 상태에서 청크 수신 (무시됨)")
                return
            }
            
            // 메시지 ID 검증 - 일치하지 않으면 무시
            guard StreamingStorage.messageId == self.streamingMessageId else {
                print("⚠️ 메시지 ID 불일치 - 현재: \(self.streamingMessageId), 저장소: \(StreamingStorage.messageId)")
                return
            }
            
            // 응답 텍스트 추출
            if let extracted = self.messagesManager.extractAnswer(from: chunk) {
                if extracted.isEmpty {
                    print("⚠️ 추출된 텍스트가 비어 있음 (무시)")
                    return
                }
                
                // 마지막 개행 문자 제거
                let cleanedText = extracted.hasSuffix("\n") ? String(extracted.dropLast()) : extracted
                
                // 중복 체크 (완전히 동일한 텍스트가 추가되는 것 방지)
                if self.currentStreamedText.hasSuffix(cleanedText) && cleanedText.count > 5 {
                    print("⚠️ 중복 텍스트 감지됨 (무시): \(cleanedText.prefix(10))...")
                    return
                }
                
                // 진단 로깅
                print("🔄 청크 #\(StreamingStorage.chunksCount + 1) 수신: \(cleanedText.prefix(15))...")
                
                // 전역 저장소에 텍스트 추가
                StreamingStorage.appendText(cleanedText)
                triggerStreamingHaptic()
                
                // 상태 업데이트 전에 이전 값 저장
                self.previousStreamedText = self.currentStreamedText
                
                // 콘텐츠 업데이트를 위한 핵심 로직: withAnimation으로 깜박임 방지
                withAnimation(.easeIn(duration: 0.2)) {
                    // 직접 텍스트에 추가
                    self.currentStreamedText += cleanedText
                    
                    // UI 업데이트 트리거 (뷰 강제 갱신)
                    self.forceUIUpdate.toggle()
                }
                
                // API 메시지 업데이트 (무결성 유지)
                if self.apiMessages.last?["role"] as? String == "model" {
                    self.apiMessages = self.messagesManager.appendChunk(
                        content: cleanedText,
                        messages: self.apiMessages
                    )
                } else {
                    self.apiMessages = self.messagesManager.appendText(
                        role: "model",
                        content: cleanedText,
                        messages: self.apiMessages
                    )
                }
                
            } else {
                // 텍스트 추출 실패 시 디버깅
                print("⚠️ 청크에서 텍스트를 추출할 수 없음")
                
                // 청크 구조 디버깅 (오류 진단)
                if let jsonData = try? JSONSerialization.data(withJSONObject: chunk, options: [.prettyPrinted]),
                   let jsonStr = String(data: jsonData, encoding: .utf8)?.prefix(200) {
                    print("📋 파싱 실패한 청크: \(jsonStr)...")
                }
                
                // 청크를 추출할 수 없지만 오류가 있는지 확인
                if let error = chunk["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    print("❌ API 오류: \(message)")
                    // 오류 발생 시 스트리밍 종료
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.handleStreamComplete("ERROR")
                    }
                }
            }
        }
    }
    
    // 스트리밍 완료 처리 단순화
    private func handleStreamComplete(_ reason: String?) {
        DispatchQueue.main.async { [self] in
            // 이미 완료된 경우 중복 호출 방지
            guard self.isStreamingResponse else {
                print("⚠️ 이미 완료된 상태에서 완료 이벤트 수신 (무시)")
                return
            }
            
            // 메시지 ID 검증
            guard StreamingStorage.messageId == self.streamingMessageId else {
                print("⚠️ 완료 이벤트의 메시지 ID 불일치 (무시)")
                return
            }
            HapticManager().success()
            print("✅ 스트리밍 완료: 사유=\(reason ?? "없음"), 텍스트 길이=\(self.currentStreamedText.count)자")
            
            // 텍스트가 비어 있으면 저장소에서 복구 시도
            if self.currentStreamedText.isEmpty && !StreamingStorage.currentText.isEmpty {
                self.currentStreamedText = StreamingStorage.currentText
                print("📌 스트리밍 완료 시 텍스트 복구: \(StreamingStorage.currentText.count)자")
            }
            
            // 최종 텍스트 내용 결정
            var messageContent = self.currentStreamedText.isEmpty ? 
                                StreamingStorage.currentText : 
                                self.currentStreamedText
            
            // 마지막 개행 문자 제거
            if messageContent.hasSuffix("\n") {
                messageContent = String(messageContent.dropLast())
                print("📝 마지막 개행 문자 제거됨")
            }
            
            // 완료 사유 저장
            self.finishReason = reason
            
            // 텍스트가 있는 경우에만 처리
            if !messageContent.isEmpty {
                // 완성된 메시지 객체 생성
                let modelMessage = MessageItem(
                    role: .model,
                    content: messageContent,
                    imageData: nil,
                    timestamp: Date()
                )
                
                // 중복 메시지 체크
                let isDuplicate = self.messages.contains { 
                    $0.role == .model && $0.content == messageContent 
                }
                
                if !isDuplicate {
                    // 애니메이션 순서: 먼저 스트리밍 UI 숨기고, 그 다음 완성된 메시지 추가
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.isStreamingResponse = false
                    }
                    
                    // 약간 지연 후 완성된 메시지 추가
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            self.messages.append(modelMessage)
                            self.currentStreamedText = ""
                            self.previousStreamedText = ""
                        }
                        
                        // 대화 저장
                        let encodedMessages = self.messagesManager.encodeMessages(self.apiMessages)
                        self.conversation?.messages = encodedMessages
                        print("💾 메시지 저장됨: \(self.apiMessages.count)개")
                        
                        // 스크롤 보장
                        self.triggerScrollToBottom()
                    }
                } else {
                    // 중복인 경우 상태만 초기화
                    withAnimation {
                        self.isStreamingResponse = false
                        self.currentStreamedText = ""
                        self.previousStreamedText = ""
                    }
                }
            } else {
                // 빈 메시지인 경우 상태만 초기화
                withAnimation {
                    self.isStreamingResponse = false
                }
                print("⚠️ 메시지가 비어 있음 - 추가되지 않음")
            }
            
            // 상태 초기화 및 스크롤 보장
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                StreamingStorage.reset()
                self.triggerScrollToBottom()
            }
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
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    // 스크롤 트리거 함수
    private func triggerScrollToBottom() {
        DispatchQueue.main.async {
            scrollToBottomTrigger.toggle()
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
            NewChatView(conversationId: UUID())
        }
    }
} 
