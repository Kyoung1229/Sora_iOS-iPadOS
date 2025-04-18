import SwiftUI

struct CollapsibleMemoViewTestScreen: View {
    @State private var memos: [Memo] = []
    
    var body: some View {
        NavigationView {
            ZStack {
                // 배경 그라디언트
                LinearGradient(
                    gradient: Gradient(colors: [.blue.opacity(0.3), .purple.opacity(0.2)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Text("접을 수 있는 메모 테스트")
                        .font(.headline)
                        .padding(.top, 20)
                    
                    ScrollView {
                        VStack(spacing: 20) {
                            ForEach(memos) { memo in
                                CollapsibleMemoView(memo: memo, onSave: { updatedMemo in
                                    updateMemo(updatedMemo)
                                })
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    Button(action: addMemo) {
                        Label("새 메모 추가", systemImage: "plus")
                            .padding()
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(10)
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("접을 수 있는 메모")
            .onAppear {
                loadSampleMemos()
            }
        }
    }
    
    private func loadSampleMemos() {
        // 샘플 메모 로드
        if memos.isEmpty {
            memos = [
                Memo(id: MemoProcessor.generateID(), title: "첫 번째 메모", content: "이 메모는 접을 수 있습니다. 오른쪽 상단의 버튼을 누르면 메모가 접히고 펼쳐집니다.", thoughts: "", links: ""),
                Memo(id: MemoProcessor.generateID(), title: "두 번째 메모", content: "메모가 접히면 제목만 표시됩니다. 펼치면 전체 내용이 표시됩니다.", thoughts: "", links: ""),
                Memo(id: MemoProcessor.generateID(), title: "세 번째 메모", content: "이 메모도 접을 수 있습니다. 접었다 펼쳤다 해보세요!", thoughts: "", links: "")
            ]
        }
    }
    
    private func addMemo() {
        let newMemo = Memo(
            id: MemoProcessor.generateID(),
            title: "새 메모",
            content: "내용을 입력하세요.",
            thoughts: "",
            links: ""
        )
        
        memos.insert(newMemo, at: 0)
    }
    
    private func updateMemo(_ memo: Memo) {
        if let index = memos.firstIndex(where: { $0.id == memo.id }) {
            memos[index] = memo
        }
    }
}

#Preview {
    CollapsibleMemoViewTestScreen()
} 