import SwiftUI

struct MemoListView: View {
    @State private var memos: [Memo] = []
    @State private var isLoading: Bool = false
    @State private var showDeleteAlert: Bool = false
    @State private var memoToDelete: Memo?
    @State private var searchText: String = ""
    @State private var showInfoToast: Bool = false
    @State private var infoMessage: String = ""

    var filteredMemos: [Memo] {
        if searchText.isEmpty {
            return memos
        } else {
            return memos.filter { memo in
                memo.title.localizedCaseInsensitiveContains(searchText) ||
                memo.content.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                VStack {
                    HStack {
                        Spacer()
                        Button(action: addMemo) {
                            Image(systemName: "plus")
                                .font(.title2)
                                .padding(8)
                        }
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Circle())
                        .padding(.trailing)
                    }
                    
                    // 검색 바
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("메모 검색", text: $searchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(filteredMemos, id: \.id) { memo in
                                NavigationLink(destination: MemoView(memo: memo, onSave: { updatedMemo in
                                    // 메모 업데이트 시 리스트 갱신 및 파일명 변경 확인
                                    if let index = memos.firstIndex(where: { $0.id == updatedMemo.id }),
                                       memos[index].title != updatedMemo.title {
                                        // 제목 변경 발생
                                        showInfoToast(message: "파일명 변경: '\(memos[index].title)' → '\(updatedMemo.title)'")
                                    }
                                    updateMemo(updatedMemo)
                                })) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text(memo.title)
                                                .font(.headline)
                                            Text(memo.content)
                                                .font(.body)
                                                .lineLimit(3)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding()
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        
                                        // 파일 정보 표시
                                        VStack(alignment: .trailing, spacing: 4) {
                                            // 메모 ID를 작은 텍스트로 표시 (디버깅용)
                                            Text(memo.id.suffix(7))
                                                .font(.system(size: 8))
                                                .foregroundColor(.gray)
                                            
                                            // 파일 이름 힌트 (터치 시 파일명 표시)
                                            Button(action: {
                                                let fileName = MemoProcessor.fileName(for: memo)
                                                showInfoToast(message: "파일명: \(fileName)")
                                            }) {
                                                Image(systemName: "doc.text")
                                                    .font(.system(size: 10))
                                                    .foregroundColor(.gray)
                                            }
                                            .buttonStyle(BorderlessButtonStyle())
                                            
                                            Spacer()
                                        }
                                        .padding(.top, 4)
                                        .padding(.trailing, 4)
                                    }
                                    .soraAcrylicBackground(style: .subtle)
                                    .contextMenu {
                                        Button(action: {
                                            memoToDelete = memo
                                            showDeleteAlert = true
                                        }) {
                                            Label("삭제", systemImage: "trash")
                                        }
                                        
                                        // 파일명 정보 보기
                                        Button(action: {
                                            let fileName = MemoProcessor.fileName(for: memo)
                                            showInfoToast(message: "파일명: \(fileName)")
                                        }) {
                                            Label("파일명 보기", systemImage: "doc.text")
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
                .opacity(isLoading ? 0.5 : 1)
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                }
                
                // 정보 표시 토스트
                if showInfoToast {
                    VStack {
                        Spacer()
                        Text(infoMessage)
                            .padding(10)
                            .background(Color.black.opacity(0.7))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .padding(.bottom, 30)
                    }
                    .transition(.opacity)
                    .animation(.easeInOut, value: showInfoToast)
                }
            }
            .onAppear {
                loadMemos()
            }
            .refreshable {
                loadMemos(forceRefresh: true)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenMemoFromFileApp"))) { notification in
                if let memo = notification.object as? Memo {
                    // 새 메모 추가 또는 업데이트
                    updateMemo(memo)
                }
            }
            .alert(isPresented: $showDeleteAlert) {
                Alert(
                    title: Text("메모 삭제"),
                    message: Text("'\(memoToDelete?.title ?? "")'을(를) 삭제하시겠습니까?"),
                    primaryButton: .destructive(Text("삭제")) {
                        if let memo = memoToDelete {
                            deleteMemo(memo)
                        }
                    },
                    secondaryButton: .cancel(Text("취소"))
                )
            }
            .navigationTitle("메모")
        }
    }
    
    // 정보 토스트 표시
    private func showInfoToast(message: String) {
        self.infoMessage = message
        self.showInfoToast = true
        
        // 3초 후 자동으로 숨김
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                self.showInfoToast = false
            }
        }
    }
    
    // 메모 업데이트
    private func updateMemo(_ memo: Memo) {
        // UI 업데이트 (중복 방지)
        if let index = memos.firstIndex(where: { $0.id == memo.id }) {
            memos[index] = memo
        } else {
            memos.append(memo)
        }
    }
    
    // 메모 삭제
    private func deleteMemo(_ memo: Memo) {
        // 먼저 UI에서 제거
        memos.removeAll { $0.id == memo.id }
        
        // 백그라운드에서 파일 삭제
        DispatchQueue.global(qos: .background).async {
            if MemoProcessor.deleteMemo(id: memo.id) {
                DispatchQueue.main.async {
                    showInfoToast(message: "메모 '\(memo.title)' 삭제 완료")
                }
            }
        }
    }
    
    private func loadMemos(forceRefresh: Bool = false) {
        isLoading = true
        
        // 백그라운드 스레드에서 실행
        DispatchQueue.global(qos: .userInitiated).async {
            let loadedMemos = forceRefresh ? 
                loadMemosFromDisk() : 
                MemoProcessor.loadAllMemos()
            
            // 메인 스레드에서 UI 업데이트
            DispatchQueue.main.async {
                self.memos = loadedMemos.sorted { first, second in
                    // ID에서 날짜 부분 추출하여 최신순 정렬
                    let firstID = first.id
                    let secondID = second.id
                    return firstID > secondID
                }
                self.isLoading = false
            }
        }
    }
    
    private func loadMemosFromDisk() -> [Memo] {
        return MemoProcessor.loadAllMemos()
    }
    
    private func addMemo() {
        let newMemo = Memo(
            id: MemoProcessor.generateID(),
            title: "새 메모",
            content: "내용을 입력하세요.",
            thoughts: "",
            links: ""
        )
        
        // 즉시 UI에 반영 (맨 앞에 추가)
        memos.insert(newMemo, at: 0)
        
        // 백그라운드에서 저장
        MemoProcessor.saveToMarkdownFile(memo: newMemo)
        
        // 파일 생성 정보 표시
        let fileName = MemoProcessor.fileName(for: newMemo)
        showInfoToast(message: "새 메모 파일 생성: \(fileName)")
    }
}

#Preview {
    MemoListViewPreviewContainer()
}

struct MemoListViewPreviewContainer: View {
    var body: some View {
        MemoListView()
    }
    
    // 샘플 메모 배열
    var sampleMemos: [Memo] {
        [
            Memo(
                id: MemoProcessor.generateID(),
                title: "아이디어 정리",
                content: "새로운 앱 기능에 대한 아이디어를 기록합니다.",
                thoughts: "이 기능은 사용자 만족도를 높일 수 있습니다.",
                links: "- 다른 메모: IN(20250408_103023123)"
            ),
            Memo(
                id: MemoProcessor.generateID(),
                title: "회의 기록",
                content: "오늘 회의에서 논의한 주요 사항들입니다.",
                thoughts: "결정사항을 요약하여 공유해야 합니다.",
                links: ""
            )
        ]
    }
}
