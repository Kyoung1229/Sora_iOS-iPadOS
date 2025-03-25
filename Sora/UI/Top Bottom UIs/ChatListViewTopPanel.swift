import SwiftUI
import SwiftData

struct ChatListViewTopPanel: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var conversations: [SoraConversationsDatabase]
    @State var showChatView: Bool = false
    @State var chatid: UUID = UUID()
    var body: some View {
        ZStack {
            HStack(alignment: .center) {
                Button("이전") {
                    
                }
                .padding()
                Spacer()
                NavigationLink("", destination: ChatView_Legacy(CVUUID: chatid), isActive: $showChatView)
                Button("+") {
                    let newChat = SoraConversationsDatabase(chatType: "assistant", model: "gemini-2.0-flash")
                    modelContext.insert(newChat)
                    chatid = newChat.id
                    showChatView.toggle()
                    print(showChatView)
                }
                .font(.title)
                .padding()
                
          }
            .padding(.bottom, 4.0)
          .background(.ultraThickMaterial)
            VStack(alignment: .center) {
                Text("대화 목록")
                    .font(.title)
                    .fontWeight(.semibold)
                    .bold()
            }
        }
  }
}

struct ChatListViewTopPanel_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ScrollView {
                        VStack(spacing: 20) {
                            ForEach(0..<50) { i in
                                Text("내용 \(i)")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.gray.opacity(0.2))
                            }
                        }
                        .padding()
                    }
            .safeAreaInset(edge: .top) {
                ChatListViewTopPanel()
            }
        }
        
    }
}
