import SwiftUI

/// 전체 화면으로 메모를 보여주는 상세 뷰
struct MemoCardDetailView: View {
    var memo: Memo
    var onSave: (Memo) -> Void
    var onDismiss: () -> Void
    
    @State private var editedTitle: String
    @State private var editedContent: String
    @State private var editedThoughts: String
    @State private var editedLinks: String
    @State private var isEditingTitle = false
    @State private var isEditingContent = false
    @State private var isEditingThoughts = false
    @State private var isEditingLinks = false
    @State private var showFilenameChangeToast = false
    @Environment(\.colorScheme) private var colorScheme
    
    init(memo: Memo, onSave: @escaping (Memo) -> Void, onDismiss: @escaping () -> Void) {
        self.memo = memo
        self.onSave = onSave
        self.onDismiss = onDismiss
        
        _editedTitle = State(initialValue: memo.title)
        _editedContent = State(initialValue: memo.content)
        _editedThoughts = State(initialValue: memo.thoughts)
        _editedLinks = State(initialValue: memo.links)
    }
    
    // 변경 사항 저장
    private func saveChanges() {
        var updatedMemo = memo
        updatedMemo.title = editedTitle
        updatedMemo.content = editedContent
        updatedMemo.thoughts = editedThoughts
        updatedMemo.links = editedLinks
        
        // 제목 변경 여부 확인
        let titleChanged = editedTitle != memo.title
        
        if titleChanged {
            // 제목 변경 시 토스트 표시
            showFilenameChangeToast = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                showFilenameChangeToast = false
            }
        }
        
        // 변경사항 저장 및 콜백 호출
        onSave(updatedMemo)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 헤더 영역 (제목 + 버튼)
            HStack {
                if isEditingTitle {
                    TextField("제목", text: $editedTitle, onCommit: {
                        isEditingTitle = false
                        saveChanges()
                    })
                    .font(.title2.bold())
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)
                } else {
                    Text(editedTitle)
                        .font(.title2.bold())
                        .padding(.vertical, 8)
                        .onTapGesture {
                            isEditingTitle = true
                        }
                }
                
                Spacer()
                
                HStack(spacing: 16) {
                    Button(action: saveChanges) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.title3)
                    }
                    
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .background(
                Rectangle()
                    .fill(Color(UIColor.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
            )
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // 내용 섹션
                    VStack(alignment: .leading, spacing: 8) {
                        Text("내용")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        if isEditingContent {
                            TextEditor(text: $editedContent)
                                .frame(minHeight: 200)
                                .padding(8)
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                )
                                .onTapGesture {} // 이벤트 버블링 방지
                            
                            Button("완료") {
                                isEditingContent = false
                                saveChanges()
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        } else {
                            Text(editedContent)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(8)
                                .onTapGesture {
                                    isEditingContent = true
                                }
                        }
                    }
                    
                    // 생각 섹션
                    VStack(alignment: .leading, spacing: 8) {
                        Text("생각")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        if isEditingThoughts {
                            TextEditor(text: $editedThoughts)
                                .frame(minHeight: 120)
                                .padding(8)
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                )
                                .onTapGesture {} // 이벤트 버블링 방지
                            
                            Button("완료") {
                                isEditingThoughts = false
                                saveChanges()
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        } else {
                            Text(editedThoughts.isEmpty ? "생각을 입력하세요" : editedThoughts)
                                .foregroundColor(editedThoughts.isEmpty ? .secondary : .primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(8)
                                .onTapGesture {
                                    isEditingThoughts = true
                                }
                        }
                    }
                    
                    // 링크 섹션
                    VStack(alignment: .leading, spacing: 8) {
                        Text("링크")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        if isEditingLinks {
                            TextEditor(text: $editedLinks)
                                .frame(minHeight: 120)
                                .padding(8)
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                )
                                .onTapGesture {} // 이벤트 버블링 방지
                            
                            Button("완료") {
                                isEditingLinks = false
                                saveChanges()
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        } else {
                            Text(editedLinks.isEmpty ? "링크를 입력하세요" : editedLinks)
                                .foregroundColor(editedLinks.isEmpty ? .secondary : .blue)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(8)
                                .onTapGesture {
                                    isEditingLinks = true
                                }
                        }
                    }
                    
                    // 메모 정보
                    VStack(alignment: .leading, spacing: 4) {
                        Text("메모 ID: \(memo.id)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical)
                }
                .padding()
            }
            
            // 토스트 메시지
            if showFilenameChangeToast {
                HStack {
                    Spacer()
                    Text("파일명 변경됨")
                        .font(.subheadline)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color.green.opacity(0.9))
                        .foregroundColor(.white)
                        .cornerRadius(20)
                    Spacer()
                }
                .padding(.bottom, 8)
            }
        }
        .background(Color(UIColor.systemBackground))
        .onAppear {
            // 메모 세부 정보를 로드한 후 현재 값으로 상태 업데이트
            if let updatedMemo = MemoProcessor.findMemo(id: memo.id) {
                editedTitle = updatedMemo.title
                editedContent = updatedMemo.content
                editedThoughts = updatedMemo.thoughts
                editedLinks = updatedMemo.links
            }
        }
        .onDisappear {
            // 뷰가 사라질 때 변경 사항 저장
            saveChanges()
        }
    }
}

// MARK: - 미리보기
struct MemoCardDetailView_Previews: PreviewProvider {
    static var previews: some View {
        MemoCardDetailView(
            memo: Memo(
                id: "IN20230101120000",
                title: "샘플 메모",
                content: "이것은 샘플 메모 내용입니다.",
                thoughts: "이 메모에 대한 생각을 적어보세요.",
                links: "관련 링크를 추가해보세요."
            ),
            onSave: { _ in },
            onDismiss: {}
        )
    }
} 