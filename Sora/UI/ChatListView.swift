import SwiftUI
import SwiftData

struct ChatListView: View {
    @Environment(\.modelContext) private var modelContext
    // 생성일(createdAt) 기준 내림차순 정렬하여 채팅 목록 자동 로드
    @Query private var conversations: [SoraConversationsDatabase]
    var sortedConversations: [SoraConversationsDatabase] {
            conversations.sorted { $0.createdAt > $1.createdAt }
        }

    var body: some View {
        NavigationView {
            ZStack {
                Color("BackgroundColor")
                    .frame(maxHeight: .infinity)
                
                
                VStack {
                    if conversations.count != 0 {
                        VStack {
                            List(sortedConversations) { conversation in
                                NavigationLink(conversation.title, destination: ChatView_Legacy(CVUUID: conversation.id))
                            }
                        }
                        .safeAreaInset(edge: .top) {
                            ChatListViewTopPanel()
                                .padding(.top, 40)
                        }
                    } else {
                        ZStack {
                            VStack() {
                                Spacer()
                            }
                            .safeAreaInset(edge: .top) {
                                ChatListViewTopPanel()
                                    .padding(.top, 40)
                            }
                            VStack(spacing: 10) {
                                Text("대화가 없습니다.")
                                    .font(.title)
                                    .fontWeight(.medium)
                                
                                Text("소라와의 대화를 시작해 보세요.")
                                    .font(.caption)
                            }
                        }
                    }
                }
                
            }
            .ignoresSafeArea(.all)
            .onAppear {

            }
        }
        
    }
}

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    return formatter
}()

#Preview {
    ChatListView()
        .modelContainer(for: SoraConversationsDatabase.self, inMemory: true)
}
