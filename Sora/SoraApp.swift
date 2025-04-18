import SwiftUI
import SwiftData

// 파일 앱 지원을 위한 앱 델리게이트
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let sceneConfig = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        
        if connectingSceneSession.role == .windowApplication {
            sceneConfig.delegateClass = SceneDelegate.self
        }
        
        return sceneConfig
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        // 앱 종료 시 대기 중인 모든 메모 저장
        MemoProcessor.saveAllPendingMemos()
    }
}

// 파일 앱에서 열기 지원을 위한 씬 델리게이트
class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        completionHandler(false)
    }
    
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else {
            return
        }
        
        // 파일 앱에서 마크다운 파일 열기
        if url.pathExtension == "md" {
            guard let content = try? String(contentsOf: url),
                  var memo = MemoProcessor.fromMarkdown(content) else {
                return
            }
            
            // 파일 이름에서 제목 추출
            memo.title = url.deletingPathExtension().lastPathComponent
            
            // 기존 앱 메모 디렉토리에 저장하고 처리
            MemoProcessor.saveToMarkdownFile(memo: memo)
            
            // 이벤트 통지
            NotificationCenter.default.post(name: NSNotification.Name("OpenMemoFromFileApp"), object: memo)
        }
    }
    
    func sceneDidEnterBackground(_ scene: UIScene) {
        // 백그라운드로 전환 시 대기 중인 메모 저장
        MemoProcessor.saveAllPendingMemos()
    }
}

@main
struct SoraApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    
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
            SoraMainView()
                .modelContainer(sharedModelContainer)
                .onOpenURL { url in
                    print("앱에서 URL 열기: \(url)")
                }
        }
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .background, .inactive:
                // 앱이 백그라운드로 전환될 때 저장
                MemoProcessor.saveAllPendingMemos()
            default:
                break
            }
        }
    }
}
