import SwiftUI
import SwiftData

struct ChatListView: View {
    @Environment(\.modelContext) private var modelContext
    // 생성일(createdAt) 기준 내림차순 정렬하여 채팅 목록 자동 로드
    @Query private var conversations: [SoraConversationsDatabase]
    var sortedConversations: [SoraConversationsDatabase] {
        conversations.sorted { $0.createdAt > $1.createdAt }
    }
    
    @State private var showNewChat = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color("BackgroundColor")
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 채팅 목록 또는 빈 상태 메시지
                    if conversations.isEmpty {
                        Spacer()
                        
                        VStack(spacing: 20) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            
                            Text("대화가 없습니다")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text("아래 버튼을 눌러 새 대화를 시작하세요")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                            
                            Button {
                                showNewChat = true
                            } label: {
                                HStack {
                                    Image(systemName: "plus")
                                    Text("새 대화 시작")
                                        .fontWeight(.medium)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.accentColor)
                                )
                                .foregroundColor(.white)
                            }
                            .padding(.top, 10)
                        }
                        
                        Spacer()
                    } else {
                        List {
                            ForEach(sortedConversations) { conversation in
                                NavigationLink(destination: NewChatView(conversationId: conversation.id)) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text(conversation.title)
                                                .font(.headline)
                                                .lineLimit(1)
                                            
                                            Spacer()
                                            
                                            // 날짜 표시
                                            Text(formattedDate(conversation.createdAt))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        // 채팅 모델 표시
                                        Text(conversation.model)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.vertical, 4)
                                }
                                .swipeActions {
                                    Button(role: .destructive) {
                                        // 대화 삭제
                                        deleteConversation(conversation)
                                    } label: {
                                        Label("삭제", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .listStyle(PlainListStyle())
                        
                        // 하단에 새 대화 시작 버튼
                        Button {
                            showNewChat = true
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                Text("새 대화 시작")
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.accentColor)
                            )
                            .foregroundColor(.white)
                            .shadow(color: Color.accentColor.opacity(0.3), radius: 4, x: 0, y: 2)
                        }
                        .padding()
                    }
                }
                .navigationTitle("대화 목록")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showNewChat = true
                        } label: {
                            Image(systemName: "square.and.pencil")
                                .font(.title3)
                        }
                    }
                }
            }
            .navigationDestination(isPresented: $showNewChat) {
                NewChatView(conversationId: UUID())
            }
        }
    }
    
    // 대화 삭제 함수
    private func deleteConversation(_ conversation: SoraConversationsDatabase) {
        modelContext.delete(conversation)
    }
    
    // 날짜 포맷팅 함수
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    ChatListView()
        .modelContainer(for: SoraConversationsDatabase.self, inMemory: true)
}
