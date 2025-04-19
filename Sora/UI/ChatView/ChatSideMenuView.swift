import SwiftUI
import SwiftData
import Combine

// 키보드 높이를 감지하는 ObservableObject
class KeyboardObserver: ObservableObject {
    @Published var keyboardHeight: CGFloat = 0
    @Published var isKeyboardVisible = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .sink { [weak self] notification in
                guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
                self?.keyboardHeight = keyboardFrame.height
                self?.isKeyboardVisible = true
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .sink { [weak self] _ in
                self?.keyboardHeight = 0
                self?.isKeyboardVisible = false
            }
            .store(in: &cancellables)
    }
}

// 키보드 적응형 모디파이어 추가
struct KeyboardAdaptive: ViewModifier {
    @State private var keyboardHeight: CGFloat = 0
    
    private let keyboardWillShow = NotificationCenter.default
        .publisher(for: UIResponder.keyboardWillShowNotification)
        .compactMap { notification in
            notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
        }
        .map { rect in
            rect.height
        }
    
    private let keyboardWillHide = NotificationCenter.default
        .publisher(for: UIResponder.keyboardWillHideNotification)
        .map { _ in CGFloat(0) }
    
    func body(content: Content) -> some View {
        content
            .padding(.top, keyboardHeight)
            .onReceive(
                Publishers.Merge(keyboardWillShow, keyboardWillHide)
            ) { height in
                withAnimation(.easeInOut(duration: 0.25)) {
                    self.keyboardHeight = height
                }
            }
    }
}

extension View {
    func keyboardAdaptive() -> some View {
        ModifiedContent(content: self, modifier: KeyboardAdaptive())
    }
}

struct ChatSideMenuView: View {
    // 환경 변수
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var gyro = GyroManager()
    
    // 상태 변수
    @State private var chatTitle: String
    @State private var tempTitle: String  // 임시 제목 상태 추가
    @State private var selectedModel = ""
    @FocusState private var isTitleFocused: Bool
    
    // 설정 화면 상태
    @State private var showAPISettings = false
    
    // 애니메이션 상태 추가
    @State private var slideOffset: CGFloat = 300
    
    // 스크롤 관련 상태
    @StateObject private var keyboardObserver = KeyboardObserver()
    @State private var scrollViewProxy: ScrollViewProxy? = nil
    @State private var titleFieldID = UUID()
    
    // 대화 및 API 속성
    private var conversation: SoraConversationsDatabase
    private var apiKey: String
    private var onClose: () -> Void
    
    // 모델 선택 옵션
    private let modelOptions = [
        "gpt-4o-mini",
        "gpt-4o",
        "gpt-4.1-nano",
        "gpt-4.1-mini",
        "gpt-4.1",
        "gemini-2.0-flash",
        "gemini-2.5-pro-exp-03-25",
        "gemini-1.5-pro"
    ]
    
    // 초기화
    init(conversation: SoraConversationsDatabase, apiKey: String, onClose: @escaping () -> Void) {
        self.conversation = conversation
        self.apiKey = apiKey
        self.onClose = onClose
        self._chatTitle = State(initialValue: conversation.title)
        self._tempTitle = State(initialValue: conversation.title)  // 임시 제목도 같은 값으로 초기화
    }
    
    var body: some View {
        // 배경 및 메인 컨테이너
        ZStack(alignment: .trailing) {
            // 배경
            GlassRectangle(gyro: gyro, cornerRadius: 0, width: UIScreen.main.bounds.width * 0.75, height: UIScreen.main.bounds.height)
                .ignoresSafeArea()
            
            // 메인 컨테이너
            VStack(spacing: 20) {
                // 상단 헤더
                headerView
                    .padding(.top)
                
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 20) {
                            // 대화 제목 섹션
                            titleSection
                                .id(titleFieldID)
                                .padding(.top, 20)
                            
                            // 모델 설정 섹션
                            modelSection
                            
                            deleteButton
                            // 하단 여백
                            Spacer(minLength: 40)
                            
                            // 다양한 설정 옵션들
                            
                            // 구분선
                            Divider()
                                .padding(.horizontal, 10)
                            
                            // API 설정 화면으로 이동 버튼
                            Button(action: {
                                showAPISettings = true
                            }) {
                                HStack {
                                    Image(systemName: "key.fill")
                                        .foregroundColor(.blue)
                                    
                                    Text("API 설정")
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                .padding(10)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color("ChatBubbleBackgroundColor_User"))
                                )
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                        }
                        .padding(.horizontal)
                    }
                    // 새로운 키보드 적응형 모디파이어는 전체 컨테이너에 적용할 것이므로 여기서 제거
                    // 빈 공간 탭 시에만 키보드 닫기
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // 키보드 숨기기 - 텍스트 필드 외 영역 탭 시
                        if isTitleFocused {
                            saveTitleAndDismissKeyboard()
                        }
                    }
                    .onChange(of: keyboardObserver.isKeyboardVisible) { _, isVisible in
                        if isVisible && isTitleFocused {
                            // 키보드가 나타나면 즉시 제목 필드로 스크롤
                            DispatchQueue.main.async {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    proxy.scrollTo(titleFieldID, anchor: .center)
                                }
                            }
                        }
                    }
                    .onChange(of: isTitleFocused) { _, newValue in
                        if newValue {
                            // 포커스가 활성화되면 해당 위치로 스크롤
                            DispatchQueue.main.async {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    proxy.scrollTo(titleFieldID, anchor: .center)
                                }
                            }
                        } else {
                            // 포커스를 잃으면 제목 저장
                            saveTitle()
                        }
                    }
                    .onAppear {
                        selectedModel = conversation.model
                        scrollViewProxy = proxy
                    }
                }
                
                // 푸터 영역
                
            }
            .ignoresSafeArea(.keyboard)
            .frame(width: UIScreen.main.bounds.width * 0.75, height: UIScreen.main.bounds.height * 0.95)
        }
        .ignoresSafeArea(.keyboard)
        // 슬라이드 애니메이션 적용
        .offset(x: slideOffset)
        // 키보드 높이에 따른 오프셋 수직 조정 추가 - 이제 전체 뷰가 함께 움직임

        .onAppear {
            withAnimation(.smooth) {
                slideOffset = 0
            }
        }
        .onDisappear {
            // 사라질 때는 애니메이션 초기화 (다음에 나타날 때 다시 슬라이드 인 되도록)
            slideOffset = 300
        }
        .onChange(of: titleFieldID) { newValue in
            // titleFieldID가 변경되었을 때, isTitleFocused를 다시 설정
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isTitleFocused = true
            }
        }
        .sheet(isPresented: $showAPISettings) {
            APISettingsView()
        }
    }
    
    // MARK: - 헤더 뷰
    private var headerView: some View {
    HStack {
        Text("대화 메뉴")
            .font(.title2.bold())
            .padding(.leading, 10)
                
        Spacer()
        Button {
            // 설정 버튼 동작을 여기에 구현하세요
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "gearshape")
            }
            .font(.title3)
        }
        .padding(.trailing, 10)
    }
    .padding()
    }
    
    // MARK: - 대화 제목 섹션
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("대화 제목")
                .font(.headline)
                .foregroundColor(.secondary)
            
            // 단순화된 텍스트 필드 - 항상 표시
            TextField("대화 제목", text: $tempTitle)  // chatTitle 대신 tempTitle 사용
                .focused($isTitleFocused)  // 명시적 포커스 상태 관리
                .font(.body)
                .padding(12)
                .background(
                    GlassRectangle(gyro: gyro, cornerRadius: 15, width: UIScreen.main.bounds.width * 0.7, height: 44)
                )
                .cornerRadius(15)

                .onSubmit {
                    saveTitleAndDismissKeyboard()
                }
                .submitLabel(.done) // 키보드 완료 버튼 표시
                .onTapGesture {
                    // 텍스트 필드 탭 시 명시적으로 포커스 설정
                    isTitleFocused = true
                }
        }
        .ignoresSafeArea(.keyboard)
        .padding()
    }
    
    // MARK: - 모델 설정 섹션
    private var modelSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("AI 모델")
                .font(.headline)
                .foregroundColor(.secondary)
            
            GlassDropdown(gyro: gyro, selectedOption: $selectedModel, options: modelOptions, width: UIScreen.main.bounds.width * 0.7, height: 44, cornerRadius: 15)
        }
        .onChange(of: selectedModel) {
            conversation.model = selectedModel
        }
        .padding()
    }
    
    // MARK: - 삭제 버튼
    private var deleteButton: some View {
        Button {
            // 대화 삭제
            modelContext.delete(conversation)
            
            // 애니메이션 적용 후 닫기
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                slideOffset = 300
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onClose()
            }
        } label: {
            HStack {
                Image(systemName: "trash")
                Text("대화 삭제")
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.red.opacity(0.8))
            )
            .foregroundColor(.white)
        }
        .buttonStyle(BorderlessButtonStyle())
        .padding(.horizontal)
        .padding(.bottom)
    }
    
    // MARK: - 헬퍼 함수
    private func saveTitle() {
        // 빈 문자열이면 기본값 사용
        if tempTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            tempTitle = "새로운 대화"
        }
        
        // 대화 제목 업데이트
        chatTitle = tempTitle
        conversation.title = tempTitle
    }
    
    // 저장 후 키보드 닫기
    private func saveTitleAndDismissKeyboard() {
        saveTitle()
        isTitleFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - 프리뷰
#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: SoraConversationsDatabase.self, configurations: config)
    
    // 샘플 대화 생성
    let sampleConversation = SoraConversationsDatabase(chatType: "assistant", model: "gemini-1.5-pro")
    sampleConversation.title = "샘플 대화"
    
    return ChatSideMenuView(conversation: sampleConversation, apiKey: "AIza...", onClose: {})
        .modelContainer(container)
}
