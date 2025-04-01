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

// 스트리밍 청크 추적용 전역 저장소
struct StreamingStorage {
    static var currentText: String = ""
    static var chunksCount: Int = 0
    static var lastResponse: [String: Any] = [:]
    static var recoveryAttempted: Bool = false
    static var timerActive: Bool = false
    static var isReset: Bool = false // 리셋 상태 추적
    static var messageId: UUID = UUID() // 현재 메시지의 ID 추적
    
    // 캐시 제한 설정
    private static let maxCachedTextLength = 100000 // 최대 10만 자
    private static let maxChunksCount = 1000 // 최대 1000개 청크
    
    // 유효하지 않은 상태가 감지될 때 true
    static var stateInvalid: Bool {
        return currentText.count > 0 && chunksCount > 0
    }
    
    // 캐시 크기 체크 및 정리
    static func checkAndTruncateCache() {
        // 텍스트가 너무 길어진 경우 잘라내기
        if currentText.count > maxCachedTextLength {
            let excessLength = currentText.count - maxCachedTextLength
            print("⚠️ 캐시 텍스트가 너무 큽니다: \(currentText.count)자 -> \(maxCachedTextLength)자로 잘라냅니다.")
            currentText = String(currentText.dropFirst(excessLength))
        }
        
        // 청크가 너무 많은 경우 리셋
        if chunksCount > maxChunksCount {
            print("⚠️ 청크 수가 너무 많습니다: \(chunksCount) -> 카운터를 리셋합니다.")
            chunksCount = maxChunksCount / 2 // 절반으로 줄임
        }
    }
    
    static func reset() {
        isReset = true
        currentText = ""
        chunksCount = 0
        lastResponse = [:]
        recoveryAttempted = false
        timerActive = false
        messageId = UUID()
        
        // 리셋 로그
        print("🔄 StreamingStorage 완전 초기화됨")
    }
    
    // 동기화 시작 - 비동기 UI 상태를 감시하고 복구
    static func startSyncTimer(viewInstance: NewChatView) {
        guard !timerActive else { return }
        
        timerActive = true
        isReset = false // 타이머 시작 시 리셋 상태 해제
        
        // 타이머 시작 시점 저장
        let startTime = Date()
        let messageIDAtStart = messageId
        
        // 반복 타이머 생성
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard timerActive && !isReset else { 
                if isReset {
                    print("🛑 타이머 중단: 저장소가 초기화됨")
                }
                return 
            }
            
            // 타이머 실행 시간 체크 (비상용 안전장치)
            let timeElapsed = Date().timeIntervalSince(startTime)
            if timeElapsed > 60.0 {
                print("⚠️ 타이머가 너무 오래 실행됨 (60초 초과) - 강제 종료")
                stopSyncTimer()
                return
            }
            
            // 메시지 ID가 변경되었는지 확인 (새 메시지가 전송됨)
            if messageIDAtStart != messageId {
                print("⚠️ 타이머 실행 중 메시지 ID 변경 감지: \(messageIDAtStart) -> \(messageId) - 타이머 중단")
                stopSyncTimer()
                return
            }
            
            // 캐시 크기 확인 및 관리
            checkAndTruncateCache()
            
            // 상태 검사
            if viewInstance.currentStreamedText.isEmpty && !currentText.isEmpty {
                print("🔄 타이머에 의한 상태 동기화: 전역 텍스트(\(currentText.count)자)를 UI에 복원")
                
                DispatchQueue.main.async {
                    viewInstance.currentStreamedText = currentText
                    viewInstance.previousStreamedText = currentText
                    viewInstance.forceUIUpdate.toggle() // UI 강제 업데이트
                }
            }
            
            // 스트리밍이 완료되었는지 확인
            if !viewInstance.isStreamingResponse {
                print("ℹ️ 스트리밍이 완료되어 타이머 중단")
                stopSyncTimer()
                return
            }
            
            // 재귀적으로 타이머 지속
            startSyncTimer(viewInstance: viewInstance)
        }
    }
    
    static func stopSyncTimer() {
        timerActive = false
        print("🛑 StreamingStorage 타이머 중지됨")
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
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query private var conversations: [SoraConversationsDatabase]
    
    // 대화 관련 상태
    @State private var messages: [MessageItem] = []
    @State private var inputText: String = ""
    @State private var isStreamingResponse: Bool = false
    @State var currentStreamedText: String = ""
    @State var previousStreamedText: String = ""
    @State private var hasNewInput: Bool = false
    @State private var finishReason: String? = nil
    @State private var showPhotoPicker: Bool = false  // 사진 선택기 표시 여부
    @State private var scrollToBottomTrigger: Bool = false // 스크롤 트리거
    @State private var lastReceivedChunk: [String: Any] = [:]
    
    // 스크롤 뷰 참조
    @State private var scrollViewProxy: ScrollViewProxy? = nil
    
    // API 관련 상태
    private let apiKey = SoraAPIKeys.shared.load(api: .gemini) ?? ""
    private let model = "gemini-2.0-flash"
    
    // 이미지 관련 상태
    @State private var selectedImage: UIImage? = nil
    @State private var photosPickerItem: PhotosPickerItem? = nil
    
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
            StreamingStorage.recoveryAttempted = true
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
                StreamingStorage.recoveryAttempted = true
            }
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 배경 그라데이션 (개선된 디자인)
                backgroundView
                
                VStack(spacing: 0) {
                    // 대화 내용 영역 (스크롤 뷰)
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 18) {
                                // 상단 여백
                                Color.clear.frame(height: 10)
                                
                                // 메시지 목록 - 각 메시지마다 안정적인 ID 사용
                                ForEach(messages, id: \.id) { message in
                                    MessageBubble(message: message)
                                        .id(message.id)
                                        .transition(.asymmetric(
                                            insertion: .opacity.combined(with: .scale(scale: 0.95)).animation(.spring(response: 0.4, dampingFraction: 0.7)),
                                            removal: .opacity.animation(.easeOut(duration: 0.2))
                                        ))
                                        .shadow(color: colorScheme == .dark ? Color.black.opacity(0.2) : Color.black.opacity(0.1), 
                                               radius: 2, x: 0, y: 1)
                                }
                                
                                // 스트리밍 중인 메시지 (현재 입력 중인 모델 응답)
                                Group {
                                    if isStreamingResponse && !currentStreamedText.isEmpty {
                                        VStack(alignment: .leading, spacing: 8) {
                                            ChatBubble_Model_Animate(
                                                baseMessage: previousStreamedText,
                                                updatedChunk: String(currentStreamedText.dropFirst(previousStreamedText.count)),
                                                animationDuration: 0.3
                                            )
                                            .id(streamingMessageId)
                                            .transition(.asymmetric(
                                                insertion: .opacity.combined(with: .scale(scale: 0.95)).animation(.spring(response: 0.4, dampingFraction: 0.7)),
                                                removal: .opacity.animation(.easeOut(duration: 0.2))
                                            ))
                                            .modifier(ForceUpdateViewModifier(update: forceUIUpdate))
                                            
                                            // 로딩 인디케이터 (퍼즐 조각 모양)
                                            HStack {
                                                ForEach(0..<3, id: \.self) { i in
                                                    Circle()
                                                        .fill(Color.accentColor.opacity(0.7))
                                                        .frame(width: 6, height: 6)
                                                        .scaleEffect(isAnimating ? 1.0 : 0.5)
                                                        .opacity(isAnimating ? 1.0 : 0.3)
                                                        .animation(
                                                            Animation.easeInOut(duration: 0.6)
                                                                .repeatForever(autoreverses: true)
                                                                .delay(Double(i) * 0.2),
                                                            value: isAnimating
                                                        )
                                                }
                                            }
                                            .padding(.leading, 4)
                                            .padding(.top, -4)
                                            .onAppear {
                                                isAnimating = true
                                            }
                                            .onDisappear {
                                                isAnimating = false
                                            }
                                        }
                                        .onAppear {
                                            // 스트리밍 시작 시 로그
                                            print("스트리밍 메시지 표시됨: \(streamingMessageId)")
                                        }
                                    }
                                }
                                
                                // 스트리밍 상태 표시
                                if !isStreamingResponse && finishReason != nil {
                                    HStack {
                                        Spacer()
                                        Text("완료: \(finishReason ?? "")") 
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                            .padding(8)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(colorScheme == .dark ? 
                                                          Color.black.opacity(0.3) : 
                                                          Color.white.opacity(0.5))
                                                    .blur(radius: 0.5)
                                            )
                                        Spacer()
                                    }
                                    .id("completion-status-\(streamingMessageId)")
                                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: finishReason)
                                }
                                
                                // 스크롤 앵커 (바닥)
                                Color.clear
                                    .frame(height: 1)
                                    .id(bottomID)
                            }
                            .padding(.horizontal)
                            .padding(.bottom, selectedImage != nil ? 180 : 100)
                        }
                        .scrollDismissesKeyboard(.immediately)
                        .onAppear {
                            scrollViewProxy = proxy
                            // 초기 로드 시 스크롤
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                // 스트리밍 데이터 일관성 확인
                                ensureStreamingConsistency()
                                
                                // 스크롤 및 메시지 상태 확인
                                triggerScrollToBottom()
                                debugPrintMessages()
                                
                                // 애니메이션 시작
                                withAnimation {
                                    isAnimating = true
                                }
                            }
                        }
                        .onChange(of: scrollToBottomTrigger) { _, _ in
                            scrollToBottom()
                        }
                        .onChange(of: messages.count) { oldCount, newCount in
                            print("메시지 배열 변경: \(oldCount) -> \(newCount)")
                            
                            // 메시지가 추가될 때마다 스크롤
                            if newCount > oldCount {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        triggerScrollToBottom()
                                    }
                                }
                            }
                        }
                    }
                    
                    Spacer(minLength: 0)
                    
                    // 하단 입력 영역 (고정)
                    VStack(spacing: 0) {
                        // 이미지 미리보기 영역 (조건부 표시)
                        if let selectedImage = selectedImage {
                            HStack {
                                Image(uiImage: selectedImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 100)
                                    .cornerRadius(12)
                                    .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 1)
                                
                                Button(action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        self.selectedImage = nil
                                    }
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                        .font(.system(size: 22))
                                        .padding(8)
                                        .background(Circle().fill(.ultraThinMaterial))
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.top, 8)
                            .background(
                                colorScheme == .dark 
                                    ? Color.black.opacity(0.2) 
                                    : Color.white.opacity(0.2)
                            )
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        
                        // 입력 컨트롤 영역
                        ZStack {
                            // 실제 입력 필드
                            TextInputField(
                                text: $inputText, 
                                onSend: {
                                    sendMessage()
                                },
                                onMediaButtonTap: {
                                    showPhotoPicker = true
                                },
                                isStreaming: isStreamingResponse
                            )
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                        }
                        .frame(height: 70)
                        .background(
                            // 입력 영역 배경 효과
                            Rectangle()
                                .fill(.ultraThinMaterial)
                                .opacity(0.8)
                                .blur(radius: 0.3)
                                .shadow(color: colorScheme == .dark ? 
                                        Color.black.opacity(0.3) : 
                                        Color.black.opacity(0.1), 
                                       radius: 5, x: 0, y: -3)
                        )
                    }
                    .background(Color.clear)
                }
                .ignoresSafeArea(edges: .bottom)
                .sheet(isPresented: $showPhotoPicker) {
                    PhotosPicker(
                        selection: $photosPickerItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        VStack {
                            HStack {
                                Text("사진 선택")
                                    .font(.headline)
                                    .padding()
                                Spacer()
                                Button(action: {
                                    showPhotoPicker = false
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.gray)
                                        .padding()
                                }
                            }
                            .background(
                                Rectangle()
                                    .fill(.ultraThinMaterial)
                                    .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
                            )
                            
                            Spacer()
                        }
                    }
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                }
            }
            .onChange(of: photosPickerItem) { _, newItem in
                if let newItem = newItem {
                    Task {
                        if let data = try? await newItem.loadTransferable(type: Data.self),
                           let uiImage = UIImage(data: data) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                selectedImage = uiImage
                                showPhotoPicker = false
                                // 이미지가 추가되면 스크롤
                                triggerScrollToBottom()
                            }
                        }
                    }
                }
            }
            .onChange(of: messages) { _, newValue in
                // 메시지가 변경되면 스크롤
                if !newValue.isEmpty {
                    triggerScrollToBottom()
                }
            }
            .onChange(of: currentStreamedText) { _, _ in
                // 스트리밍 중에도 스크롤
                if isStreamingResponse {
                    triggerScrollToBottom()
                }
            }
            .onChange(of: isStreamingResponse) { _, newValue in
                // 스트리밍 상태 변경 시 스크롤
                triggerScrollToBottom()
            }
            .onChange(of: forceUIUpdate) { _, _ in
                // 강제 업데이트 상태가 변경될 때마다 스크롤 및 상태 확인
                if isStreamingResponse {
                    print("🔄 UI 강제 업데이트 발생: 현재 텍스트 길이=\(currentStreamedText.count)")
                    
                    // 스트리밍 메시지가 표시되고 있는데 텍스트가 빈 경우 복구 시도
                    if currentStreamedText.isEmpty && !StreamingStorage.currentText.isEmpty {
                        DispatchQueue.main.async {
                            currentStreamedText = StreamingStorage.currentText
                            print("⚠️ onChange에서 텍스트 복구: \(StreamingStorage.currentText.count)자")
                        }
                    }
                    
                    // 스크롤 트리거
                    triggerScrollToBottom()
                }
            }
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
        .navigationTitle(conversation?.title ?? "새 대화")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: {
                        // 대화 내보내기
                    }) {
                        Label("대화 내보내기", systemImage: "square.and.arrow.up")
                    }
                    
                    Button(action: {
                        // 대화 내용 지우기
                        withAnimation {
                            messages = []
                            apiMessages = []
                            conversation?.messages = "[]"
                        }
                    }) {
                        Label("대화 지우기", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                }
            }
        }
    }
    
    // 배경 뷰
    private var backgroundView: some View {
        ZStack {
            // 기본 배경색
            Color("BackgroundColor")
                .ignoresSafeArea()
            
            // 그라데이션 오버레이
            LinearGradient(
                gradient: Gradient(colors: [
                    colorScheme == .dark ? 
                        Color.blue.opacity(0.04) : 
                        Color.blue.opacity(0.02),
                    colorScheme == .dark ? 
                        Color.purple.opacity(0.04) : 
                        Color.purple.opacity(0.02)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // 서브틀한 패턴
            GeometryReader { geometry in
                ZStack {
                    // 미묘한 원형 하이라이트
                    ForEach(0..<3) { i in
                        Circle()
                            .fill(
                                RadialGradient(
                                    gradient: Gradient(colors: [
                                        colorScheme == .dark ? 
                                            Color.blue.opacity(0.03) : 
                                            Color.blue.opacity(0.02),
                                        Color.clear
                                    ]),
                                    center: .center,
                                    startRadius: 1,
                                    endRadius: geometry.size.width * 0.6
                                )
                            )
                            .frame(width: geometry.size.width, height: geometry.size.width)
                            .position(
                                x: geometry.size.width * [0.2, 0.8, 0.5][i % 3],
                                y: geometry.size.height * [0.2, 0.7, 0.5][i % 3]
                            )
                            .opacity(0.7)
                    }
                }
            }
        }
    }
    
    // 스크롤을 맨 아래로 이동 (애니메이션 적용)
    private func scrollToBottom() {
        withAnimation(.easeOut(duration: 0.3)) {
            scrollViewProxy?.scrollTo(bottomID, anchor: .bottom)
        }
    }
    
    // 스크롤 트리거 함수
    private func triggerScrollToBottom() {
        DispatchQueue.main.async {
            scrollToBottomTrigger.toggle()
        }
    }
    
    // 대화 로드
    private func loadConversation() {
        let predicate = #Predicate<SoraConversationsDatabase> { $0.id == conversationId }
        let descriptor = FetchDescriptor<SoraConversationsDatabase>(predicate: predicate)
        
        if let fetched = try? modelContext.fetch(descriptor).first {
            conversation = fetched
            
            // 메시지 복원
            if let conversationMessages = conversation?.messages, !conversationMessages.isEmpty {
                apiMessages = messagesManager.decodeMessages(conversationMessages)
                
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
                
                // 초기 로드 후 스크롤
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    triggerScrollToBottom()
                }
            }
        } else {
            // 새 대화 생성
            let newChat = SoraConversationsDatabase(chatType: "assistant", model: model)
            modelContext.insert(newChat)
            conversation = newChat
        }
    }
    
    // 메시지 전송 함수
    private func sendMessage() {
        // 텍스트가 비어있고 이미지도 없는 경우 반환
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedImage != nil else { return }
        
        // 이미 스트리밍 중인 경우 중복 전송 방지
        if isStreamingResponse {
            print("⚠️ 이미 스트리밍 중인 상태에서 전송 시도 차단됨")
            return
        }
        
        // 전역 저장소 초기화 (새 메시지 전송 시)
        StreamingStorage.reset()
        
        // 동기화 타이머 시작 (자동 복구)
        StreamingStorage.startSyncTimer(viewInstance: self)
        
        // 사용자 메시지 생성
        let userMessageText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        var userMessageData: Data? = nil
        
        // 새 스트리밍 메시지를 위한 ID 생성
        streamingMessageId = UUID()
        StreamingStorage.messageId = streamingMessageId // 전역 저장소에도 ID 저장
        
        // 첫 번째 메시지인지 확인
        let isFirstMessage = messages.isEmpty
        
        // 입력 초기화 (UI 업데이트 전에 먼저 처리)
        let tempInputText = inputText
        inputText = ""
        
        // 메시지 전송 로그
        print("📤 메시지 전송 시작: \(userMessageText.prefix(30))... (이미지: \(selectedImage != nil ? "있음" : "없음"))")
        
        // 사용자 메시지 생성 및 추가 (이미지 여부에 따라 다르게 처리)
        if let image = selectedImage {
            // 이미지 압축 및 변환
            userMessageData = image.jpegData(compressionQuality: 0.7)
            
            if let imageData = userMessageData {
                // 메시지 아이템 생성 (UI용)
                let userMessage = MessageItem(
                    role: .user,
                    content: userMessageText,
                    imageData: imageData,
                    timestamp: Date()
                )
                
                // UI에 사용자 메시지 추가 (메인 스레드에서 명시적으로 UI 업데이트)
                DispatchQueue.main.async {
                    // 메시지 추가와 상태 업데이트를 한 번의 애니메이션으로 처리
                    withAnimation(.easeInOut(duration: 0.3)) {
                        // 메시지 추가
                        self.messages.append(userMessage)
                        // 상태 업데이트
                        self.isStreamingResponse = true
                        self.currentStreamedText = ""
                        self.previousStreamedText = ""
                        self.finishReason = nil
                        self.isAnimating = true
                        
                        // 이미지 선택 초기화
                        self.selectedImage = nil
                    }
                    
                    // 스크롤 트리거
                    self.triggerScrollToBottom()
                    
                    // 디버깅용 출력
                    print("🖼️ 이미지 메시지 추가 완료: 현재 메시지 수: \(self.messages.count), ID: \(self.streamingMessageId)")
                }
                
                // 이미지를 Base64로 인코딩
                let base64String = imageData.base64EncodedString()
                
                // API 메시지 배열에 이미지와 텍스트가 포함된 메시지 추가
                apiMessages = messagesManager.appendTextWithImage(
                    role: "user",
                    text: userMessageText,
                    imageBase64: base64String,
                    messages: apiMessages
                )
                
                // 디버깅용 로그
                print("📤 이미지와 함께 메시지 전송 준비: \(userMessageText.prefix(30))...")
                messagesManager.logMessages(apiMessages, prefix: "전송")
                
                // API 호출 지연 (UI 업데이트 후)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    // 이미지 첨부 API 호출 
                    GeminiAPI().callWithStreamingAndImage(
                        model: "gemini-pro-vision",
                        apiKey: self.apiKey,
                        textMessage: userMessageText,
                        imageBase64: base64String,
                        previousMessages: [],  // 이미지는 이전 컨텍스트 없이 새로 시작
                        onChunk: self.processStreamChunk,
                        onComplete: self.handleStreamComplete
                    )
                }
            }
        } else {
            // 텍스트만 있는 경우
            // 메시지 아이템 생성 (UI용)
            let userMessage = MessageItem(
                role: .user,
                content: userMessageText,
                imageData: nil,
                timestamp: Date()
            )
            
            // UI에 사용자 메시지 추가 (메인 스레드에서 명시적으로 UI 업데이트)
            DispatchQueue.main.async {
                // 메시지 추가와 상태 업데이트를 한 번의 애니메이션으로 처리
                withAnimation(.easeInOut(duration: 0.3)) {
                    // 메시지 추가
                    self.messages.append(userMessage)
                    // 상태 업데이트
                    self.isStreamingResponse = true
                    self.currentStreamedText = ""
                    self.previousStreamedText = ""
                    self.finishReason = nil
                    self.isAnimating = true
                }
                
                // 스크롤 트리거
                self.triggerScrollToBottom()
                
                // 디버깅용 출력
                print("📤 텍스트 메시지 추가 완료: 현재 메시지 수: \(self.messages.count), ID: \(self.streamingMessageId)")
            }
            
            // API 메시지 배열에 텍스트 메시지 추가
            apiMessages = messagesManager.appendText(
                role: "user",
                content: userMessageText,
                messages: apiMessages
            )
            
            // 디버깅용 로그
            print("📤 텍스트 메시지 전송 준비: \(userMessageText.prefix(30))...")
            
            // API 호출 지연 (UI 업데이트 후)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                // 스트리밍 시작 시점 추적 - 메시지 ID와 타임스탬프 확인
                print("📡 API 호출 시작: ID \(self.streamingMessageId), 시간: \(Date())")
                
                // 일반 API 호출
                GeminiAPI().callWithStreaming(
                    model: self.model,
                    apiKey: self.apiKey,
                    messages: self.apiMessages,
                    onChunk: self.processStreamChunk,
                    onComplete: self.handleStreamComplete
                )
            }
        }
        
        // 첫 메시지인 경우 즉시 제목 업데이트
        if isFirstMessage {
            DispatchQueue.main.async {
                // 대화 제목이 없는 경우 첫 메시지 내용으로 설정
                if self.conversation?.title == "새 대화" {
                    let titleText = userMessageText
                    let newTitle = String(titleText.prefix(while: { $0 != "\n" }).prefix(20))
                    if !newTitle.isEmpty {
                        self.conversation?.title = newTitle + (newTitle.count >= 20 ? "..." : "")
                        print("📝 대화 제목 업데이트: \(self.conversation?.title ?? "")")
                    }
                }
            }
        }
    }
    
    // 스트리밍 청크 처리
    private func processStreamChunk(_ chunk: [String: Any]) {
        DispatchQueue.main.async {
            // 전역 저장소 업데이트
            StreamingStorage.lastResponse = chunk
            StreamingStorage.chunksCount += 1
            
            // 디버깅용 상태 업데이트
            lastReceivedChunk = chunk
            streamedChunksCount = StreamingStorage.chunksCount
            
            // 스트리밍이 종료된 상태에서 청크를 받는 경우 (정상적이지 않은 상황)
            if !self.isStreamingResponse {
                print("⚠️ 스트리밍이 종료된 상태에서 청크 수신 (무시됨): 청크 #\(StreamingStorage.chunksCount)")
                return
            }
            
            // 청크 ID와 현재 메시지 ID가 일치하는지 확인
            if StreamingStorage.messageId != self.streamingMessageId {
                print("⚠️ 메시지 ID 불일치: 저장소 ID \(StreamingStorage.messageId) vs 현재 ID \(self.streamingMessageId) (무시됨)")
                return
            }
            
            // 진단 로그
            print("🔄 청크 #\(StreamingStorage.chunksCount) 수신: \(chunk.keys.joined(separator: ", "))")
            
            // 응답 텍스트 추출 (개선된 방식으로)
            if let extracted = messagesManager.extractAnswer(from: chunk) {
                // 응답 청크 길이 확인
                if extracted.isEmpty {
                    print("⚠️ 추출된 청크가 비어 있음 (무시됨)")
                    return
                }
                
                // 비정상적으로 큰 청크 감지
                if extracted.count > 10000 {
                    print("⚠️ 비정상적으로 큰 청크 감지됨: \(extracted.count)자 (처리는 계속됨)")
                }
                
                // UI 상태가 초기화된 경우 전역 저장소에서 복원
                if StreamingStorage.chunksCount > 1 && currentStreamedText.isEmpty && !StreamingStorage.currentText.isEmpty {
                    print("🔄 청크 처리 중 UI 상태가 초기화됨: 전역 텍스트로 복원 (\(StreamingStorage.currentText.count)자)")
                    currentStreamedText = StreamingStorage.currentText
                }
                
                // 상태 업데이트 전에 이전 값 저장
                previousStreamedText = currentStreamedText.isEmpty ? StreamingStorage.currentText : currentStreamedText
                
                // 전역 저장소의 텍스트에 추가
                StreamingStorage.currentText += extracted
                
                // 캐시 크기 체크 및 정리
                StreamingStorage.checkAndTruncateCache()
                
                // 현재 텍스트 업데이트 (전역 스토리지 값으로)
                currentStreamedText = StreamingStorage.currentText
                
                // UI 강제 업데이트 트리거 (상태 변수 토글)
                forceUIUpdate.toggle()
                
                // UI 업데이트 체크
                print("🔄 스트리밍 청크: \(extracted.prefix(20))... (길이: \(extracted.count)) [총: \(currentStreamedText.count)자]")
                
                // currentStreamedText가 빈 값에서 다시 복구된 경우 (비정상적인 상황)
                if currentStreamedText.count > 0 && previousStreamedText.isEmpty && StreamingStorage.chunksCount > 1 {
                    print("⚠️ 텍스트가 초기화된 후 복구됨 - 데이터 일관성 문제 감지")
                    isRecoveredFromReset = true
                    StreamingStorage.recoveryAttempted = true
                }
                
                // API 메시지 업데이트 (역할에 따라 다르게 처리)
                if apiMessages.last?["role"] as? String == "model" {
                    // 모델 응답이 이미 있으면 텍스트만 추가
                    apiMessages = messagesManager.appendChunk(
                        content: extracted,
                        messages: apiMessages
                    )
                } else {
                    // 첫 모델 응답이면 새 메시지 생성
                    apiMessages = messagesManager.appendText(
                        role: "model",
                        content: extracted,
                        messages: apiMessages
                    )
                }
                
                // 각 청크마다 스크롤 트리거 (성능 최적화: 10번째 청크마다)
                if StreamingStorage.chunksCount % 10 == 0 || StreamingStorage.chunksCount < 5 {
                    triggerScrollToBottom()
                }
            } else {
                print("⚠️ 청크에서 텍스트를 추출할 수 없음: \(String(describing: chunk))")
            }
        }
    }
    
    // 스트리밍 완료 처리
    private func handleStreamComplete(_ reason: String?) {
        // 메인 스레드에서 실행
        DispatchQueue.main.async {
            // 중복 호출 체크 (이미 완료 처리된 경우 무시)
            if !self.isStreamingResponse {
                print("⚠️ 이미 스트리밍이 완료된 상태에서 완료 이벤트 수신됨 (무시)")
                return
            }
            
            // 메시지 ID 확인 - 잘못된 ID의 완료 이벤트 무시
            if StreamingStorage.messageId != self.streamingMessageId {
                print("⚠️ 메시지 ID 불일치: 저장소 ID \(StreamingStorage.messageId) vs 현재 ID \(self.streamingMessageId) (무시됨)")
                return
            }
            
            // 동기화 타이머 중지
            StreamingStorage.stopSyncTimer()
            
            print("✅ 스트리밍 완료: finishReason=\(reason ?? "nil"), 텍스트 길이=\(currentStreamedText.count)자, 청크=\(StreamingStorage.chunksCount)개")
            
            // 최종 상태 강제 동기화 (전역 저장소 → UI 상태)
            if currentStreamedText.isEmpty && !StreamingStorage.currentText.isEmpty {
                currentStreamedText = StreamingStorage.currentText
                // UI 강제 업데이트
                forceUIUpdate.toggle()
                print("📌 스트리밍 완료 시 전역 저장소에서 텍스트 강제 복원: \(StreamingStorage.currentText.count)자")
            }
            
            // 전역 저장소 사용 (데이터 일관성 유지)
            let finalText = currentStreamedText.isEmpty ? StreamingStorage.currentText : currentStreamedText
            
            // API 메시지 확인 (디버깅용)
            if let modelMessage = apiMessages.last, let role = modelMessage["role"] as? String, role == "model" {
                if let parts = modelMessage["parts"] as? [[String: Any]], 
                   let textPart = parts.first, 
                   let text = textPart["text"] as? String {
                    print("🔍 API 메시지에 저장된 텍스트 길이: \(text.count)자")
                    
                    // finalText가 비어 있는데 API 메시지에 텍스트가 있는 경우 복구 시도
                    if finalText.isEmpty && !text.isEmpty {
                        print("⚠️ currentStreamedText 및 전역 스토리지가 비어 있지만 API 메시지에 텍스트가 있어 복구합니다")
                        currentStreamedText = text
                        // 전역 저장소도 업데이트
                        StreamingStorage.currentText = text
                    }
                }
            }
            
            // 최종 텍스트 결정 (다시 확인)
            let messageContent = currentStreamedText.isEmpty ? StreamingStorage.currentText : currentStreamedText
            
            // 스트리밍 완료 플래그 설정
            finishReason = reason
            
            // 완료된 텍스트가 있는 경우에만 처리
            if !messageContent.isEmpty {
                print("✅ 새 완성 메시지 추가: 길이=\(messageContent.count)자")
                
                // 완료된 메시지 객체 생성
                let modelMessage = MessageItem(
                    role: .model,
                    content: messageContent,
                    imageData: nil,
                    timestamp: Date()
                )
                
                // 중복 체크 - 같은 내용의 메시지가 이미 있는지 확인
                let alreadyAddedMessageExists = messages.contains { message in
                    message.role == .model && message.content == messageContent
                }
                
                if !alreadyAddedMessageExists {
                    // 스트리밍 관련 상태 업데이트 (UI 변경 전)
                    withAnimation(.easeInOut(duration: 0.3)) {
                        // 완성된 메시지를 배열에 추가
                        self.messages.append(modelMessage)
                        
                        // 디버깅용 출력
                        print("✅ 완성된 메시지 추가됨: \(self.messages.count)번째 메시지")
                    }
                    
                    // 스크롤 트리거
                    self.triggerScrollToBottom()
                    
                    // 약간의 지연 후 스트리밍 상태 변경
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            // 상태 변경은 마지막에 한 번에 처리
                            self.isStreamingResponse = false
                            self.isAnimating = false
                        }
                    }
                    
                    // 대화 저장
                    let encodedMessages = self.messagesManager.encodeMessages(self.apiMessages)
                    self.conversation?.messages = encodedMessages
                    print("💾 메시지가 데이터베이스에 저장됨: \(self.apiMessages.count)개")
                } else {
                    print("⚠️ 이미 추가된 메시지가 있어 중복 추가하지 않음")
                    
                    // 상태만 업데이트
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isStreamingResponse = false
                        isAnimating = false
                    }
                }
            } else {
                print("⚠️ 스트리밍이 완료되었으나 텍스트가 비어 있음 (복구 시도)")
                
                // API 메시지에서 마지막 모델 메시지 추출 시도
                if let modelMessage = apiMessages.last, let role = modelMessage["role"] as? String, role == "model" {
                    if let parts = modelMessage["parts"] as? [[String: Any]], 
                       let textPart = parts.first, 
                       let text = textPart["text"] as? String,
                       !text.isEmpty {
                        
                        print("🛠️ API 메시지에서 텍스트 복구 시도: \(text.prefix(30))...")
                        
                        // 복구된 메시지 추가
                        let recoveredMessage = MessageItem(
                            role: .model,
                            content: text,
                            imageData: nil,
                            timestamp: Date()
                        )
                        
                        withAnimation(.easeInOut(duration: 0.3)) {
                            self.messages.append(recoveredMessage)
                            print("🛠️ 복구된 메시지 추가 완료")
                        }
                    }
                }
                
                // 상태 업데이트 (스트리밍 종료)
                withAnimation(.easeInOut(duration: 0.3)) {
                    isStreamingResponse = false
                    isAnimating = false
                }
            }
            
            // 상태 변수 초기화 (다음 대화를 위해)
            streamedChunksCount = 0
            isRecoveredFromReset = false
            
            // 전역 저장소 초기화
            StreamingStorage.reset()
            
            // 스크롤 확실히 보장
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
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
