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

        }
        .modelContainer(sharedModelContainer)
        // ✅ SwiftData 모델 연결
    }
}
