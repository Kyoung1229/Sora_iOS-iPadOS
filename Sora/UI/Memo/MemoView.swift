import SwiftUI

struct MemoView: View {
    @StateObject private var gyro = GyroManager()
    let memo: Memo
    @State private var title: String
    @State private var content: String
    @State private var document: MemoDocument?
    @State private var isSaving: Bool = false
    @State private var lastSaveTime: Date = Date()
    @State private var memoID: String
    @State private var showTitleChangeToast: Bool = false
    @State private var originalTitle: String
    
    // 메모가 저장될 때 호출되는 콜백
    var onSave: ((Memo) -> Void)?
    
    init(memo: Memo, onSave: ((Memo) -> Void)? = nil) {
        self.memo = memo
        self.onSave = onSave
        self.memoID = memo.id
        self.originalTitle = memo.title
        _title = State(initialValue: memo.title)
        _content = State(initialValue: memo.content)
    }

    let screen_height = UIScreen.main.bounds.height
    let screen_width = UIScreen.main.bounds.width
    @State private var memo_maxHeight: CGFloat = UIScreen.main.bounds.height * 0.4
    @State private var memo_textField_maxHeight = UIScreen.main.bounds.height * 0.3
    
    // 타이머를 통한 지연 저장 제어
    @State private var saveDebounceTimer: Timer?
    private let saveDebounceDelay: TimeInterval = 0.5 // 0.5초 동안 입력이 없으면 저장

    private func updateAndSaveMemo() {
        // 기존 타이머 취소
        saveDebounceTimer?.invalidate()
        
        // 제목 변경 확인
        if title != originalTitle {
            showTitleChangeToast = true
            // 토스트 메시지 3초 후 자동 숨김
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                showTitleChangeToast = false
            }
            originalTitle = title
        }
        
        // 0.5초 지연 후 저장 실행
        saveDebounceTimer = Timer.scheduledTimer(withTimeInterval: saveDebounceDelay, repeats: false) { _ in
            executeSave()
        }
    }
    
    private func executeSave() {
        isSaving = true
        
        let updatedMemo = Memo(
            id: memoID,
            title: title,
            content: content,
            thoughts: memo.thoughts,
            links: memo.links
        )
        
        // 배치 처리로 저장 요청
        MemoProcessor.saveToMarkdownFile(memo: updatedMemo)
        
        // 콜백 호출 (UI 업데이트)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isSaving = false
            onSave?(updatedMemo)
        }
        
        // UIDocument를 사용하여 문서 업데이트
        if let existingDocument = document {
            existingDocument.memo = updatedMemo
            existingDocument.updateChangeCount(.done)
        } else {
            // 처음 저장 시 문서 객체 생성
            MemoDocumentManager.loadDocument(for: memoID) { loadedDocument in
                if let loadedDocument = loadedDocument {
                    self.document = loadedDocument
                    loadedDocument.memo = updatedMemo
                    loadedDocument.updateChangeCount(.done)
                } else {
                    MemoDocumentManager.createDocument(for: updatedMemo) { createdDocument in
                        self.document = createdDocument
                    }
                }
            }
        }
    }

    var body: some View {
        ZStack {
            GlassRectangle(gyro: gyro, cornerRadius: 30, width: screen_width * 0.9, height: screen_height * 0.4)
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    TextField("제목 입력", text: $title)
                        .onChange(of: title) { _ in
                            updateAndSaveMemo()
                        }
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                        .padding(.leading, 25)
                        .font(.title2)
                        .frame(minWidth: 20, idealWidth: screen_width * 0.5)
                }
                .padding(.top, 15)
                .frame(alignment: .leading)
                Capsule()
                    .frame(width: (screen_width * 0.9) - 20, height: 1)
                    .foregroundStyle(Color("UniversalGray"))
                    .padding(.horizontal, 10)
                    .padding(.top, 5)
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .padding(15)
                        .foregroundStyle(Color("ChatBubbleBackgroundColor_User").opacity(0.8))
                        .shadow(color: Color("UniversalShadow"), radius: 10, y: 5)
                        .allowsHitTesting(false)
                    VStack {
                        TextEditor(text: $content)
                            .onChange(of: content) { _ in
                                updateAndSaveMemo()
                            }
                            .font(.system(size: 18, weight: .medium, design: .default))
                            .multilineTextAlignment(.leading)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 18)
                            .background(Color.clear)
                            .scrollContentBackground(.hidden)
                            .frame(maxWidth: screen_width * 0.9, idealHeight: memo_textField_maxHeight, alignment: .leading)
                    }
                    .frame(maxWidth: (screen_width * 0.9))
                }
            }
            .frame(width: screen_width * 0.9, height: memo_maxHeight, alignment: .top)
            .contentShape(Rectangle())
            .onTapGesture {
                saveDebounceTimer?.invalidate()
                executeSave() // 즉시 저장 실행
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            .onAppear {
                // 메모를 위한 문서 불러오기
                MemoDocumentManager.loadDocument(for: memoID) { loadedDocument in
                    self.document = loadedDocument
                }
            }
            .onDisappear {
                // 뷰를 떠날 때 변경사항 즉시 저장
                saveDebounceTimer?.invalidate()
                executeSave()
            }
            
            // 저장 중 표시
            if isSaving {
                HStack {
                    Spacer()
                    VStack {
                        Text("저장 중...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.top, 5)
                    .padding(.trailing, 10)
                }
            }
            
            // 제목 변경 토스트 메시지
            if showTitleChangeToast {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("파일명이 '\(title)'(으)로 변경됩니다")
                            .font(.caption)
                            .padding(8)
                            .background(Color.black.opacity(0.6))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        Spacer()
                    }
                    .padding(.bottom, 20)
                }
                .transition(.move(edge: .bottom))
                .animation(.easeInOut, value: showTitleChangeToast)
            }
            
        }
    }
}

struct MemoView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ZStack {
                // 배경 그라디언트 (예시용)
                LinearGradient(
                    gradient: Gradient(colors: [.blue.opacity(0.3), .purple.opacity(0.2)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                MemoView(memo: Memo(id: MemoProcessor.generateID(), title: "Sample Title", content: "Sample Content", thoughts: "", links: ""))
            }
        }
    }
}
