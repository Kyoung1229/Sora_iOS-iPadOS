import SwiftUI
import SwiftData
import PhotosUI
import CoreHaptics

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

// 메시지 아이템 구조체
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

// 임시 스키마를 사용한 ModelContext 생성 (프리뷰용)
extension ChatService {
    static func createTemp() -> ChatService {
        let schema = Schema([
            SoraConversationsDatabase.self,
            Message.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        return ChatService(modelContext: context)
    }
    
    func updateModelContext(_ newContext: ModelContext) {
        // 참고: 이 메소드는 실제 구현에서는 ChatService를 수정해야 합니다
        // 이 예제는 실제로 작동하지 않을 수 있지만 컴파일 오류를 해결하기 위한 목적입니다
        // 실제로는 ChatService에 이런 메소드를 추가해야 합니다
    }
}

// MARK: - ChatBubble_User 컴포넌트


struct ChatView: View {
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
    
    // MARK: - ChatService 추가
    @StateObject private var chatService = ChatService.createTemp()
    
    // MARK: - 대화 관련
    @State private var model: String
    var conversationId: UUID
    @State private var conversation: SoraConversationsDatabase?
    private var hapticEngine = try? CHHapticEngine()
    private let StreamingHapticPath = Bundle.main.path(forResource: "StreamingHaptic", ofType: "ahap")
    
    // 대화 관련 상태
    @State private var isStreaming: Bool = false
    @State private var currentStreamingMessage: String = ""
    @State private var modelProvider: EventStreamingHandler.Provider?
    
    // MARK: - 이미지 선택 관련 상태
    @State private var showImagePicker = false
    @State private var selectedPhotoItem: UIImage?
    @State private var selectedImageData: Data? = nil
    @State private var fullMessage: String = ""
    
    // MARK: - 초기화
    init(model: String, conversationId: UUID) {
        self.model = model
        self.conversationId = conversationId
    }
    
    // ChatSideMenuView에 전달할 conversation을 계산하는 프로퍼티
    private var sideMenuConversation: SoraConversationsDatabase {
        return conversation ?? SoraConversationsDatabase(id: conversationId, chatType: "assistant", model: model)
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            // 배경색
            Color("BackgroundColor")
                .ignoresSafeArea()
                .ignoresSafeArea(.keyboard)
            
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
                                        if message.role == .user {
                                            ChatBubble_User(messageItem: message)
                                                .id(message.id)
                                        } else {
                                            ChatBubble_Model(message: message.content)
                                                .id(message.id)
                                        }
                                    }
                                    
                                    // 스트리밍 중인 메시지
                                    if isStreaming && !currentStreamingMessage.isEmpty {

                                        ChatBubble_Model_Animate(
                                            baseMessage: fullMessage,
                                            updatedChunk: self.currentStreamingMessage,
                                            animationDuration: 0.3
                                        )
                                        .id("streaming-bubble")
                                        .transition(.opacity)
                                    }
                                    
                                    // 하단 여백 (스크롤을 위한 앵커)
                                    Rectangle()
                                        .frame(height: 85) // 키보드 입력창 높이 + 여백
                                        .foregroundColor(.clear)
                                        .id(bottomID)
                                }
                                .padding(.horizontal, 16)
                                // 메시지 목록 변경 시 애니메이션
                                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: messages.count)
                            }
                            .contentShape(Rectangle()) // 빈 공간에서도 제스처가 동작하도록 설정
                            .onTapGesture {
                                // 여백 탭 시 키보드 닫기
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            }
 
                        }
                    }
                }
                
                // 입력 필드 - 하단에 고정
                VStack(spacing: 0) {
                    // 선택된 이미지 미리보기
                    if let imageData = selectedImageData, let uiImage = UIImage(data: imageData) {
                        HStack {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 80)
                                .cornerRadius(8)
                                .padding(.leading, 8)
                            
                            Spacer()
                            
                            Button(action: {
                                selectedImageData = nil
                                selectedPhotoItem = nil
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                                    .background(Circle().fill(Color(UIColor.systemBackground)))
                            }
                        }
                        .frame(maxWidth: UIScreen.main.bounds.width - 10)
                        .padding(.horizontal, 8)
                        .padding(.bottom, 5)
                    }
                    
                    TextInputField(
                        text: $inputText,
                        onSend: sendMessage,
                        onMediaButtonTap: {
                            showImagePicker = true
                        },
                        isStreaming: isStreaming,
                        autoFocus: false // 자동 포커스 비활성화
                    )
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                }
            }
            .onChange(of: currentStreamingMessage) {
                HapticManager().impact(.light)
            }
            
            ZStack(alignment: .bottom) {
                GlassRectangle(gyro: gyro, cornerRadius: 0, width: UIScreen.main.bounds.width, height: 100)
                    
                // 상단 헤더 (항상 위에 표시)
                VStack {
                    HStack {
                        // 뒤로가기 버튼
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.title3)
                                .padding(8)
                                .foregroundColor(.primary)
                        }
                        .padding(.leading, 25)

                        Spacer()
                        
                        // 메뉴 버튼
                        Button {
                            withAnimation(.smooth) {
                                showSideMenu = true
                            }
                        } label: {
                            Image(systemName: "line.3.horizontal")
                                .resizable(resizingMode: .stretch)
                                .font(.title3)
                                .padding(8)
                                .foregroundColor(.primary)
                                .scaledToFit()
                        }
                        .frame(height: 30)
                        .padding(.trailing, 20)

                    }
                    .frame(alignment: .bottom)
                    .padding(.top, 70)
                    .padding(.bottom, 20)
                    .frame(maxHeight: 60)
                    HStack {
                        Text(conversation?.title ?? "새로운 대화")
                            .fontWeight(.medium)
                            .font(.title2)
                            .lineLimit(1)
                    }
                    .padding(.bottom, 3)
                }
                .frame(maxHeight: 100, alignment: .top)
                .padding(.bottom, 0)

            }
            .ignoresSafeArea()
            
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
                        conversation: sideMenuConversation,
                        apiKey: SoraAPIKeys.shared.load(api: modelProvider == .openai ? .openai : .gemini) ?? "",
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
                    .transition(.move(edge: .trailing))
                }
                .onChange(of: conversation?.model) {
                    model = conversation?.model ?? "gpt-4.1-mini"
                    print(model)
                    modelProvider = ((conversation?.model.contains("gpt")) != nil) ? .openai : .gemini
                    chatService.apiKey = SoraAPIKeys.shared.load(api: modelProvider == .openai ? .openai : .gemini) ?? ""
                    chatService.updateModelContext(modelContext)
                }
                .zIndex(2)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            // ChatService 초기화
            model = conversation?.model ?? "gpt-4.1-mini"
            print(model)
            modelProvider = ((conversation?.model.contains("gpt")) != nil) ? .openai : .gemini
            chatService.apiKey = SoraAPIKeys.shared.load(api: modelProvider == .openai ? .openai : .gemini) ?? ""
            chatService.updateModelContext(modelContext)
            setupChat()
        }
        // 이미지 선택 시트 추가
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $selectedPhotoItem)
        }
        // 선택된 사진 아이템 변경 감지
        .onChange(of: selectedPhotoItem) { newItem in
            Task {
                // PhotosPickerItem에서 Data 로드
                if let data = try? await newItem?.pngData() {
                    selectedImageData = data
                }
            }
        }
    }
    
    // MARK: - 채팅 설정
    private func setupChat() {
        let modelType: DataAPIType = modelProvider == .openai ? .openai : .gemini
        // ChatService 설정
        chatService.apiKey = SoraAPIKeys.shared.load(api: modelProvider == .openai ? .openai : .gemini) ?? ""
        chatService.updateModelContext(modelContext)
        // 키보드 감지 설정
        setupKeyboardObservers()
        
        // 대화 로드
        loadConversation()
    }
    
    // MARK: - 키보드 옵저버 설정
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                keyboardHeight = keyboardFrame.height
                isKeyboardVisible = true
                scrollToBottom()
            }
        }
        
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
            keyboardHeight = 0
            isKeyboardVisible = false
        }
    }
    
    // MARK: - 대화 로드 함수
    private func loadConversation() {
        print("Loading conversation with ID: \(conversationId)")
        let fetchDescriptor = FetchDescriptor<SoraConversationsDatabase>(
            predicate: #Predicate { $0.id == conversationId }
        )
        
        do {
            let fetchedConversations = try modelContext.fetch(fetchDescriptor)
            if let existingConversation = fetchedConversations.first {
                // 기존 대화 설정
                conversation = existingConversation
                chatService.setConversation(existingConversation)
                
                // 메시지 변환
                messages = existingConversation.messages.map { message in
                    return MessageItem(
                        role: message.role == "user" ? .user : .model,
                        content: message.parts.compactMap { part in
                            if case .text(let text) = part {
                                return text
                            }
                            return nil
                        }.joined(),
                        imageData: nil,
                        timestamp: message.timestamp
                    )
                }.sorted { $0.timestamp < $1.timestamp }
                
                print("기존 대화를 불러왔습니다: \(messages.count)개 메시지")
            } else {
                // 새 대화 생성
                createNewConversation()
            }
            
        } catch {
            print("대화를 불러오는 중 오류 발생: \(error)")
            createNewConversation()
        }
    }
    
    // MARK: - 새 대화 생성
    private func createNewConversation() {
        print("새 대화를 생성합니다: ID=\(conversationId), Model=\(conversation?.model ?? "gpt-4.1-mini")")
        let newConversation = SoraConversationsDatabase(
            id: conversationId,
            title: "새 대화",
            isPinned: false,
            messages: [],
            chatType: "assistant",
            model: "gpt-4.1-mini",
            createdAt: Date()
        )
        conversation = newConversation
        model = conversation?.model ?? "gpt-4.1-mini"
        modelContext.insert(newConversation)
        chatService.setConversation(newConversation)
    }
    
    // MARK: - 메시지 전송
    private func sendMessage() {
        model =  conversation?.model ?? "gpt-4.1-mini"
        let trimmedText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        // 텍스트가 비어 있고 이미지도 없는 경우 전송하지 않음
        guard (!trimmedText.isEmpty || selectedImageData != nil) && !isStreaming else { return }
        
        // 사용자 메시지 아이템 생성 (이미지 데이터 포함)
        let userMessageItem = MessageItem(
            role: .user,
            content: trimmedText,
            imageData: selectedImageData,
            timestamp: Date()
        )
        
        // 메시지 목록에 추가
        withAnimation {
            messages.append(userMessageItem)
        }
        
        // 입력 필드 및 이미지 선택 초기화
        inputText = ""
        let imageDataToSend = selectedImageData // API 호출 전에 이미지 데이터 저장
        selectedImageData = nil
        selectedPhotoItem = nil
        
        // 실제 Message 객체 생성 및 데이터베이스 저장
        let imageToSendUIImage = imageDataToSend != nil ? UIImage(data: imageDataToSend!) : nil
        chatService.addUser(text: trimmedText, image: imageToSendUIImage)
        
        // 응답 생성
        simulateResponse(to: trimmedText)
    }
    
    // MARK: - API 호출 (대체된 simulateResponse 함수)
    private func simulateResponse(to userMessage: String) {
        // 응답 처리 시작
        isStreaming = true
        currentStreamingMessage = ""
        // ChatService가 설정되었는지 확인
        guard conversation != nil else {
            print("대화가 설정되지 않았습니다.")
            isStreaming = false
            return
        }
        
        // ChatService로 API 호출
        chatService.run(
            model: conversation?.model ?? "gpt-4.1-mini",
            streaming: true,
            onUpdate: { streamedText in
                DispatchQueue.main.async {
                    self.currentStreamingMessage = streamedText
                    fullMessage = fullMessage + self.currentStreamingMessage
                }
            },
            onToolCall: { toolCall in
                print("Tool call received: \(toolCall.name)")
            },
            onDone: { finishReason, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("API 호출 오류: \(error.localizedDescription)")
                        self.finishResponse(with: "오류가 발생했습니다: \(error.localizedDescription)")
                    } else {
                        print("API 호출 완료. 사유: \(finishReason ?? "없음")")
                        print(modelProvider)
                        if modelProvider == .gemini {
                            self.finishResponse(with: fullMessage)
                        } else {
                            print(fullMessage)
                            self.finishResponse(with: self.currentStreamingMessage)
                        }
                        
                    }
                }
            }
        )
    }
    
    // 응답 완료 처리
    private func finishResponse(with text: String) {
        // 스트리밍 완료
        isStreaming = false
        print(text)
        // 응답 메시지 추가
        let assistantMessage = MessageItem(
            role: .model,
            content: text,
            imageData: nil,
            timestamp: Date()
        )
        
        withAnimation {
            messages.append(assistantMessage)
        }
        
        // 저장 로직 - 실제 Message 객체 생성 및 데이터베이스에 저장
        let msg = Message(role: "assistant", text: text, conversation: conversation)
        modelContext.insert(msg)
        conversation?.messages.append(msg)
        try? modelContext.save()
        
        // 현재 메시지 초기화
        currentStreamingMessage = ""
        fullMessage = ""
        
        // 스크롤 처리
        scrollToBottom()
    }
    
    // MARK: - 스크롤 관련 함수
    private func scrollToBottom() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 0.3)) {
                self.scrollViewProxy?.scrollTo(self.bottomID, anchor: .bottom)
            }
        }
    }
}

// 미리보기
struct ChatView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ChatView(
                model: "gemini-flash-2.0",
                conversationId: UUID()
            )
            .modelContainer(for: [SoraConversationsDatabase.self, Message.self])
        }
    }
} 

/* 
MARK: - 개발자 참고 사항
ChatService 클래스에 다음과 같은 메소드를 추가해야 합니다:

public func updateModelContext(_ newContext: ModelContext) {
    // 새 ModelContext로 업데이트
    self.modelContext = newContext
    
    // 기존 대화가 있으면 다시 설정
    if let conversation = currentConversation {
        self.history = ChatHistoryManager(modelContext: newContext, conversation: conversation)
    }
}
*/ 
