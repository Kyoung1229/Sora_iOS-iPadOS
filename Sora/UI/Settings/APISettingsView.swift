import SwiftUI

enum APIType: String, CaseIterable, Identifiable {
    case gemini = "Gemini"
    case openai = "OpenAI"
    
    var id: String { self.rawValue }
    
    var description: String {
        switch self {
        case .gemini:
            return "Google의 Gemini AI 모델을 사용합니다. 다양한 작업에 적합합니다."
        case .openai:
            return "OpenAI의 GPT 모델을 사용합니다. 텍스트 생성에 강점이 있습니다."
        }
    }
    
    var apiKeyPrompt: String {
        switch self {
        case .gemini:
            return "Google AI Studio에서 API 키를 발급받을 수 있습니다."
        case .openai:
            return "OpenAI Platform에서 API 키를 발급받을 수 있습니다."
        }
    }
    
    var apiKeyLink: URL {
        switch self {
        case .gemini:
            return URL(string: "https://makersuite.google.com/app/apikey")!
        case .openai:
            return URL(string: "https://platform.openai.com/api-keys")!
        }
    }
    
    var apiKeyPlaceholder: String {
        switch self {
        case .gemini:
            return "AIza..."
        case .openai:
            return "sk-..."
        }
    }
}

extension ModelProvider {
    var toAPIType: APIType {
        switch self {
        case .gemini:
            return .gemini
        case .openai:
            return .openai
        }
    }
}

struct APISettingsView: View {
    // 환경 변수
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    // 상태 변수
    @State private var selectedAPI: APIType = .gemini
    @State private var apiKey: String = ""
    @State private var isShowingAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    @State private var isKeyMasked = true
    
    // 효과와 애니메이션
    @StateObject private var gyro = GyroManager()
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .top) {
                // 배경색
                Color("BackgroundColor")
                    .ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 20) {
                    // API 선택
                    Picker("API 선택", selection: $selectedAPI) {
                        ForEach(APIType.allCases) { apiType in
                            Text(apiType.rawValue).tag(apiType)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: selectedAPI) { newValue in
                        // API 유형이 변경되면 저장된 키 로드
                        loadAPIKey()
                    }
                    
                    // 선택된 API 설명
                    VStack(alignment: .leading, spacing: 10) {
                        Text(selectedAPI.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 5)
                        
                        Text(selectedAPI.apiKeyPrompt)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Link("API 키 발급 사이트 바로가기", destination: selectedAPI.apiKeyLink)
                            .font(.subheadline)
                            .foregroundColor(.blue)
                            .padding(.top, 5)
                    }
                    .padding(.vertical, 10)
                    
                    // API 키 입력 필드
                    GlassTextField(
                        gyro: gyro,
                        placeholder: selectedAPI.apiKeyPlaceholder,
                        text: $apiKey,
                        isSecure: isKeyMasked
                    )
                    .overlay(
                        HStack {
                            Spacer()
                            Button(action: {
                                isKeyMasked.toggle()
                            }) {
                                Image(systemName: isKeyMasked ? "eye" : "eye.slash")
                                    .foregroundColor(.secondary)
                            }
                            .padding(.trailing, 10)
                        }
                    )
                    .padding(.vertical, 10)
                    
                    // 저장 버튼
                    Button(action: saveAPIKey) {
                        Text("저장")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.blue)
                            )
                    }
                    .padding(.top, 20)
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 85) // 네비게이션 바 높이만큼 여백
                
                // 커스텀 네비게이션 바
                ZStack {
                    GlassRectangle(gyro: gyro, cornerRadius: 29, width: UIScreen.main.bounds.width * 0.9, height: 60)
                    
                    HStack {
                        Button(action: dismiss.callAsFunction) {
                            Image(systemName: "chevron.left")
                                .font(.title3)
                                .padding(8)
                                .background(Circle().fill(Color("ChatBubbleBackgroundColor_User")))
                                .foregroundColor(.primary)
                        }
                        .padding(.leading, 15)
                        
                        Spacer()
                        
                        Text("API 설정")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        // 균형을 위한 빈 공간
                        Circle()
                            .fill(Color.clear)
                            .frame(width: 40, height: 40)
                            .padding(.trailing, 15)
                    }
                    .frame(alignment: .top)
                    .ignoresSafeArea()
                    .padding(.horizontal)
                    .padding(.top)
                    .padding(.bottom, 15)
                }
            }
            .navigationBarHidden(true)
            .alert(isPresented: $isShowingAlert) {
                Alert(
                    title: Text(alertTitle),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("확인"))
                )
            }
            .onAppear(perform: loadAPIKey)
        }
    }
    
    // MARK: - API 키 불러오기
    private func loadAPIKey() {
        let apiProvider: DataAPIType = (selectedAPI == .gemini) ? .gemini : .openai
        apiKey = SoraAPIKeys.shared.load(api: apiProvider) ?? ""
    }
    
    // MARK: - API 키 저장
    private func saveAPIKey() {
        guard !apiKey.isEmpty else {
            showAlert(title: "API 키 오류", message: "API 키를 입력해주세요.")
            return
        }
        
        let apiProvider: DataAPIType = (selectedAPI == .gemini) ? .gemini : .openai
        let success = SoraAPIKeys.shared.save(api: apiProvider, key: apiKey)
    }
    
    // MARK: - 알림 표시
    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        isShowingAlert = true
    }
}

// MARK: - 유리 효과 텍스트 필드
struct GlassTextField: View {
    let gyro: GyroManager
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool
    
    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                .frame(height: 50)
                .offset(x: gyro.x * 2, y: gyro.y * 2)
            
            if isSecure {
                SecureField(placeholder, text: $text)
                    .padding(.horizontal, 10)
            } else {
                TextField(placeholder, text: $text)
                    .padding(.horizontal, 10)
            }
        }
    }
}

// MARK: - 미리보기
struct APISettingsView_Previews: PreviewProvider {
    static var previews: some View {
        APISettingsView()
    }
} 
