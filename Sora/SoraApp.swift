import SwiftUI
import SwiftData

@main
struct SoraApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            SoraConversationsDatabase.self, // ✅ 여기에 모델이 추가되어야 함
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            NavigationView {
                TabView {
                    // 기존 채팅 탭
                    ChatListView()
                        .tabItem {
                            Label("기존 채팅", systemImage: "message.fill")
                        }
                    
                    // 새로운 채팅 시작 탭
                    ZStack {
                        // 배경
                        Color("BackgroundColor")
                            .ignoresSafeArea()
                        
                        VStack(spacing: 24) {
                            Text("새로운 채팅 경험")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Text("개선된 UI와 이미지 전송을 지원하는 새로운 채팅 인터페이스를 경험해보세요.")
                                .font(.body)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 32)
                            
                            Spacer().frame(height: 20)
                            
                            // 화려한 새 대화 시작 버튼
                            NavigationLink(destination: NewChatView(conversationId: UUID())) {
                                HStack {
                                    Image(systemName: "sparkles.tv")
                                        .font(.headline)
                                    Text("새 대화 시작")
                                        .font(.headline)
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.accentColor, Color.accentColor.opacity(0.7)]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .clipShape(Capsule())
                                .shadow(color: Color.accentColor.opacity(0.4), radius: 8, x: 0, y: 4)
                            }
                            
                            Spacer()
                        }
                        .padding()
                    }
                    .tabItem {
                        Label("새 채팅", systemImage: "sparkles.tv")
                    }
                }
                .accentColor(.accentColor)
            }
        }
        .modelContainer(sharedModelContainer)
        // ✅ SwiftData 모델 연결
    }
}
