import SwiftUI

struct FolderCanvasView: View {
    // MARK: - 프로퍼티
    var folder: MemoFolder
    @State private var memos: [Memo] = []
    @State private var positions: [String: MemoPosition] = [:]
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var draggedMemoID: String?
    @State private var scale: CGFloat = 1.0
    @State private var lastScaleValue: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var showAddMemoSheet = false
    @State private var availableMemos: [Memo] = []
    @State private var selectedMemoIDs: Set<String> = []
    @State private var isEditMode = false
    @State private var showInfoToast = false
    @State private var infoMessage = ""
    @State private var isLoading = true
    @State private var screenSize: CGSize = .zero
    @State private var showNewMemoSheet = false
    @State private var newMemoTitle = "새 메모"
    @State private var newMemoContent = ""
    @State private var selectedMemo: Memo? = nil
    @State private var showMemoDetailView = false
    
    // MARK: - 계산 프로퍼티
    private var isEmptyCanvas: Bool {
        return positions.isEmpty
    }
    
    // 최대 Z-Index 값
    private var maxZIndex: Double {
        return positions.values.map { $0.zIndex }.max() ?? 0
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 캔버스 배경
                Rectangle()
                    .fill(Color.secondary.opacity(0.05))
                    .ignoresSafeArea()
                    .contentShape(Rectangle()) // 드래그 제스처 인식을 위한 영역 정의
                    .gesture(
                        // 캔버스 이동 제스처 (빈 영역에서 작동)
                        DragGesture()
                            .onChanged { value in
                                guard !isDragging else { return }
                                self.offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                            .onEnded { _ in
                                self.lastOffset = self.offset
                            }
                    )
                    .gesture(
                        // 핀치 줌 제스처
                        MagnificationGesture()
                            .onChanged { value in
                                let delta = value / lastScaleValue
                                scale *= delta
                                lastScaleValue = value
                                
                                // 스케일 제한
                                scale = min(max(scale, 0.3), 3.0)
                            }
                            .onEnded { _ in
                                lastScaleValue = 1.0
                            }
                    )
                
                // 빈 캔버스 상태
                if isEmptyCanvas && !isLoading {
                    VStack(spacing: 12) {
                        Image(systemName: "square.grid.3x3")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("이 폴더는 비어 있습니다")
                            .font(.title3)
                            .fontWeight(.medium)
                        
                        Text("+ 버튼을 눌러 메모를 추가하세요")
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        Button(action: {
                            showAddMemoSheet = true
                        }) {
                            HStack {
                                Image(systemName: "plus")
                                Text("메모 추가하기")
                            }
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                // 메모 카드 캔버스
                if !isEmptyCanvas {
                    ZStack {
                        // 각 메모 카드
                        ForEach(memos, id: \.id) { memo in
                            if let position = positions[memo.id] {
                                SimpleMemoCardView(
                                    memo: memo,
                                    position: position,
                                    onDragChanged: { offset in
                                        handleDragChanged(memo: memo, offset: offset)
                                    },
                                    onDragEnded: { offset in
                                        handleDragEnded(memo: memo, offset: offset)
                                    },
                                    onExpandToggle: {
                                        toggleExpand(memoID: memo.id)
                                    },
                                    onBringToFront: {
                                        bringToFront(memoID: memo.id)
                                    },
                                    isEditMode: isEditMode,
                                    onSelectionChanged: { isSelected in
                                        handleSelection(memoID: memo.id, isSelected: isSelected)
                                    },
                                    isSelected: selectedMemoIDs.contains(memo.id),
                                    onDetailView: {
                                        selectedMemo = memo
                                        showMemoDetailView = true
                                    }
                                )
                                .offset(x: position.x + offset.width, y: position.y + offset.height)
                                .zIndex(position.zIndex)
                                .scaleEffect(scale)
                            }
                        }
                    }
                }
                
                // 로딩 화면
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                }
                
                // 토스트 메시지
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
                // 화면 크기 저장
                screenSize = geometry.size
            }
        }
        .navigationTitle(folder.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if isEditMode {
                    Button(action: {
                        removeSelectedMemos()
                    }) {
                        Image(systemName: "trash")
                    }
                    .disabled(selectedMemoIDs.isEmpty)
                    
                    Button(action: {
                        isEditMode.toggle()
                        selectedMemoIDs.removeAll()
                    }) {
                        Text("완료")
                    }
                } else {
                    Button(action: {
                        resetView()
                    }) {
                        Image(systemName: "arrow.counterclockwise")
                    }
                    
                    Button(action: {
                        showNewMemoSheet = true
                    }) {
                        Image(systemName: "square.and.pencil")
                    }
                    
                    Button(action: {
                        isEditMode.toggle()
                    }) {
                        Text("편집")
                    }
                    
                    Button(action: {
                        showAddMemoSheet = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .onAppear {
            loadFolderData()
        }
        .sheet(isPresented: $showAddMemoSheet) {
            MemoSelectorView(
                availableMemos: availableMemos,
                onMemoSelected: { selectedMemos in
                    addMemosToFolder(selectedMemos)
                }
            )
        }
        .sheet(isPresented: $showNewMemoSheet) {
            createNewMemoView()
        }
        .sheet(isPresented: $showMemoDetailView) {
            if let memo = selectedMemo {
                MemoCardDetailView(
                    memo: memo,
                    onSave: { updatedMemo in
                        updateMemo(updatedMemo)
                    },
                    onDismiss: {
                        showMemoDetailView = false
                    }
                )
            }
        }
    }
    
    // MARK: - 메소드
    
    // 폴더 데이터 로드
    private func loadFolderData() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let folderMemos = FolderManager.getMemosInFolder(folderID: folder.id)
            let folderPositions = Dictionary(uniqueKeysWithValues: 
                folder.memoPositions.map { ($0.id, $0) }
            )
            
            // 사용 가능한 (아직 폴더에 없는) 메모 로드
            let allMemos = MemoProcessor.loadAllMemos()
            let availableMemoList = allMemos.filter { memo in
                !folderPositions.keys.contains(memo.id)
            }
            
            DispatchQueue.main.async {
                memos = folderMemos
                positions = folderPositions
                availableMemos = availableMemoList
                isLoading = false
            }
        }
    }
    
    // 드래그 시작 처리
    private func handleDragChanged(memo: Memo, offset: CGSize) {
        guard !isEditMode else { return }
        
        isDragging = true
        draggedMemoID = memo.id
        dragOffset = offset
        
        // Z-Index 증가시키기
        if let position = positions[memo.id] {
            var updatedPosition = position
            updatedPosition.zIndex = maxZIndex + 1
            positions[memo.id] = updatedPosition
        }
    }
    
    // 드래그 종료 처리
    private func handleDragEnded(memo: Memo, offset: CGSize) {
        guard !isEditMode, let position = positions[memo.id] else { return }
        
        isDragging = false
        
        // 새 위치 계산 및 업데이트
        var updatedPosition = position
        updatedPosition.x += offset.width / scale
        updatedPosition.y += offset.height / scale
        positions[memo.id] = updatedPosition
        
        // 서버에 저장
        FolderManager.updateMemoPosition(
            folderID: folder.id,
            memoID: memo.id,
            newPosition: updatedPosition
        )
        
        draggedMemoID = nil
    }
    
    // 확장/축소 토글
    private func toggleExpand(memoID: String) {
        guard let position = positions[memoID] else { return }
        
        var updatedPosition = position
        updatedPosition.isExpanded.toggle()
        
        // 확장 시 맨 앞으로 가져오기
        if updatedPosition.isExpanded {
            updatedPosition.zIndex = maxZIndex + 1
        }
        
        positions[memoID] = updatedPosition
        
        // 서버에 저장
        FolderManager.updateMemoPosition(
            folderID: folder.id,
            memoID: memoID,
            newPosition: updatedPosition
        )
    }
    
    // 메모를 최상위로 가져오기
    private func bringToFront(memoID: String) {
        guard let position = positions[memoID] else { return }
        
        var updatedPosition = position
        updatedPosition.zIndex = maxZIndex + 1
        positions[memoID] = updatedPosition
        
        // 서버에 저장
        FolderManager.updateMemoPosition(
            folderID: folder.id,
            memoID: memoID,
            newPosition: updatedPosition
        )
    }
    
    // 메모 선택/선택 해제 처리
    private func handleSelection(memoID: String, isSelected: Bool) {
        if isSelected {
            selectedMemoIDs.insert(memoID)
        } else {
            selectedMemoIDs.remove(memoID)
        }
    }
    
    // 선택된 메모 제거
    private func removeSelectedMemos() {
        for memoID in selectedMemoIDs {
            positions.removeValue(forKey: memoID)
            FolderManager.removeMemoFromFolder(folderID: folder.id, memoID: memoID)
        }
        
        // UI 업데이트
        memos.removeAll { memo in
            selectedMemoIDs.contains(memo.id)
        }
        
        showInfoToast(message: "\(selectedMemoIDs.count)개의 메모가 폴더에서 제거되었습니다")
        selectedMemoIDs.removeAll()
    }
    
    // 폴더에 메모 추가
    private func addMemosToFolder(_ selectedMemos: [Memo]) {
        // 중앙에 가까운 위치에 메모를 배치하기 위한 기준점 설정
        let centerX = screenSize.width / 2
        let centerY = screenSize.height / 2
        
        for (index, memo) in selectedMemos.enumerated() {
            // 중앙 주변에 고르게 분포시키기 위해 각도 사용
            let angle = Double(index) * (2 * .pi / Double(selectedMemos.count))
            let distance = CGFloat.random(in: 60...150)
            
            // 원형으로 배치 (중앙 기준)
            let x = centerX + cos(angle) * distance - 150 // 카드 크기 보정
            let y = centerY + sin(angle) * distance - 100
            
            // 폴더에 메모 추가
            FolderManager.addMemoToFolder(
                folderID: folder.id,
                memoID: memo.id,
                at: CGPoint(x: x, y: y)
            )
            
            // UI 업데이트
            memos.append(memo)
            
            let newPosition = MemoPosition(
                id: memo.id,
                x: x,
                y: y,
                zIndex: maxZIndex + Double(index) + 1
            )
            positions[memo.id] = newPosition
        }
        
        // 사용 가능한 메모 목록 업데이트
        availableMemos.removeAll { memo in
            selectedMemos.contains { $0.id == memo.id }
        }
        
        showInfoToast(message: "\(selectedMemos.count)개의 메모가 추가되었습니다")
    }
    
    // 뷰 리셋 (원점 및 확대/축소 초기화)
    private func resetView() {
        withAnimation(.spring()) {
            scale = 1.0
            offset = .zero
            lastOffset = .zero
        }
    }
    
    // 토스트 메시지 표시
    private func showInfoToast(message: String) {
        infoMessage = message
        showInfoToast = true
        
        // 3초 후 자동으로 숨김
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                showInfoToast = false
            }
        }
    }
    
    // 새 메모 생성 뷰
    private func createNewMemoView() -> some View {
        NavigationView {
            Form {
                Section(header: Text("새 메모")) {
                    TextField("제목", text: $newMemoTitle)
                    
                    ZStack(alignment: .topLeading) {
                        if newMemoContent.isEmpty {
                            Text("내용을 입력하세요")
                                .foregroundColor(.gray)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                        }
                        TextEditor(text: $newMemoContent)
                            .frame(minHeight: 150)
                    }
                }
            }
            .navigationTitle("새 메모 만들기")
            .navigationBarItems(
                leading: Button("취소") {
                    showNewMemoSheet = false
                    resetNewMemoFields()
                },
                trailing: Button("생성") {
                    createAndAddNewMemo()
                    showNewMemoSheet = false
                }
                .disabled(newMemoTitle.isEmpty)
            )
        }
    }
    
    // 새 메모 생성 및 폴더에 추가
    private func createAndAddNewMemo() {
        // 새 메모 객체 생성
        let newMemo = Memo(
            id: MemoProcessor.generateID(),
            title: newMemoTitle,
            content: newMemoContent,
            thoughts: "",
            links: ""
        )
        
        // 화면 중앙에 위치 지정
        let centerX = screenSize.width / 2 - 150
        let centerY = screenSize.height / 2 - 100
        
        // 메모 저장 (파일로)
        MemoProcessor.saveImmediately(memo: newMemo)
        
        // 폴더에 메모 추가
        FolderManager.addMemoToFolder(
            folderID: folder.id,
            memoID: newMemo.id,
            at: CGPoint(x: centerX, y: centerY)
        )
        
        // UI 업데이트
        memos.append(newMemo)
        
        let newPosition = MemoPosition(
            id: newMemo.id,
            x: centerX,
            y: centerY,
            zIndex: maxZIndex + 1,
            isExpanded: true // 새 메모는 확장된 상태로 시작
        )
        positions[newMemo.id] = newPosition
        
        // 토스트 메시지 표시
        showInfoToast(message: "새 메모가 생성되었습니다")
        
        // 필드 초기화
        resetNewMemoFields()
    }
    
    // 새 메모 필드 초기화
    private func resetNewMemoFields() {
        newMemoTitle = "새 메모"
        newMemoContent = ""
    }
    
    // 메모 업데이트
    private func updateMemo(_ updatedMemo: Memo) {
        // 메모 저장
        MemoProcessor.saveImmediately(memo: updatedMemo)
        
        // UI 업데이트
        if let index = memos.firstIndex(where: { $0.id == updatedMemo.id }) {
            memos[index] = updatedMemo
            
            // 제목 변경 시 토스트 메시지 표시
            if memos[index].title != updatedMemo.title {
                showInfoToast(message: "파일명 변경: '\(memos[index].title)' → '\(updatedMemo.title)'")
            }
        }
    }
}

// MARK: - 새로운 간단한 메모 카드 뷰
struct SimpleMemoCardView: View {
    // MARK: - 프로퍼티
    var memo: Memo
    var position: MemoPosition
    var onDragChanged: (CGSize) -> Void
    var onDragEnded: (CGSize) -> Void
    var onExpandToggle: () -> Void
    var onBringToFront: () -> Void
    var isEditMode: Bool
    var onSelectionChanged: (Bool) -> Void
    var isSelected: Bool
    var onDetailView: () -> Void
    
    @State private var editedTitle: String
    @State private var editedContent: String
    @State private var isEditingTitle = false
    @State private var isEditingContent = false
    @State private var showFilenameChangeToast = false
    
    // 고정 크기
    private let collapsedSize = CGSize(width: 160, height: 100)
    private let expandedSize = CGSize(width: 350, height: 400)
    
    init(memo: Memo, position: MemoPosition, onDragChanged: @escaping (CGSize) -> Void, onDragEnded: @escaping (CGSize) -> Void, onExpandToggle: @escaping () -> Void, onBringToFront: @escaping () -> Void, isEditMode: Bool, onSelectionChanged: @escaping (Bool) -> Void, isSelected: Bool, onDetailView: @escaping () -> Void) {
        self.memo = memo
        self.position = position
        self.onDragChanged = onDragChanged
        self.onDragEnded = onDragEnded
        self.onExpandToggle = onExpandToggle
        self.onBringToFront = onBringToFront
        self.isEditMode = isEditMode
        self.onSelectionChanged = onSelectionChanged
        self.isSelected = isSelected
        self.onDetailView = onDetailView
        
        _editedTitle = State(initialValue: memo.title)
        _editedContent = State(initialValue: memo.content)
    }
    
    // 햅틱 피드백
    private func generateHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred(intensity: 1.0)
    }
    
    // 변경 사항 저장
    private func saveChanges() {
        if editedTitle != memo.title || editedContent != memo.content {
            let titleChanged = editedTitle != memo.title
            
            var updatedMemo = memo
            updatedMemo.title = editedTitle
            updatedMemo.content = editedContent
            
            if titleChanged {
                MemoProcessor.saveImmediately(memo: updatedMemo)
                showFilenameChangeToast = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    showFilenameChangeToast = false
                }
            } else {
                MemoProcessor.saveToMarkdownFile(memo: updatedMemo)
            }
        }
    }
    
    var body: some View {
        let cardSize = position.isExpanded ? expandedSize : collapsedSize
        
        ZStack {
            // 카드 배경
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                )
                .shadow(color: .black.opacity(0.2), radius: 3)
            
            // 카드 내용
            VStack(alignment: .leading, spacing: 8) {
                // 헤더 영역 (제목 + 버튼)
                HStack {
                    if isEditMode {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(isSelected ? .blue : .gray)
                            .padding(.trailing, 4)
                            .onTapGesture {
                                onSelectionChanged(!isSelected)
                            }
                    }
                    
                    if isEditingTitle && position.isExpanded {
                        TextField("제목", text: $editedTitle, onCommit: {
                            isEditingTitle = false
                            saveChanges()
                        })
                        .font(.headline)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    } else {
                        Text(editedTitle)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .onTapGesture {
                                if position.isExpanded && !isEditMode {
                                    isEditingTitle = true
                                }
                            }
                    }
                    
                    Spacer()
                    
                    if position.isExpanded && !isEditMode {
                        Button(action: {
                            onDetailView()
                        }) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .padding(.trailing, 8)
                        
                        Button(action: saveChanges) {
                            Image(systemName: "square.and.arrow.down")
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                
                Divider()
                    .padding(.horizontal, 8)
                
                // 내용 영역
                if isEditingContent && position.isExpanded {
                    TextEditor(text: $editedContent)
                        .padding(4)
                        .frame(maxHeight: 200)
                        .background(Color(UIColor.tertiarySystemBackground))
                        .cornerRadius(8)
                        .padding(.horizontal, 8)
                } else {
                    ScrollView {
                        Text(editedContent)
                            .font(.body)
                            .foregroundColor(.primary)
                            .lineLimit(position.isExpanded ? nil : 3)
                            .padding(.horizontal, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .onTapGesture {
                                if position.isExpanded && !isEditMode {
                                    isEditingContent = true
                                }
                            }
                    }
                }
                
                // 확장 시 추가 내용
                if position.isExpanded {
                    VStack(alignment: .leading, spacing: 4) {
                        if !memo.thoughts.isEmpty {
                            Divider()
                                .padding(.horizontal, 8)
                            
                            Text("생각")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 12)
                            
                            Text(memo.thoughts)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 12)
                        }
                        
                        if !memo.links.isEmpty {
                            Divider()
                                .padding(.horizontal, 8)
                            
                            Text("링크")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 12)
                            
                            Text(memo.links)
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 12)
                        }
                    }
                }
                
                Spacer()
                
                // 푸터
                HStack {
                    if showFilenameChangeToast {
                        Text("파일명 변경됨")
                            .font(.system(size: 9))
                            .foregroundColor(.green)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(4)
                    }
                    
                    Spacer()
                    
                    Text(memo.id.suffix(7))
                        .font(.system(size: 8))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
            }
            .frame(width: cardSize.width, height: cardSize.height)
        }
        .frame(width: cardSize.width, height: cardSize.height)
        .contentShape(Rectangle())
        // 더블 탭 제스처 - 상세 보기 열기
        .onTapGesture(count: 2) {
            if !isEditMode {
                onDetailView()
            }
        }
        // 탭 제스처 - 축소/확장 처리
        .onTapGesture {
            if isEditMode {
                onSelectionChanged(!isSelected)
            } else if position.isExpanded {
                // 확장 상태에서 키보드가 활성화된 경우
                if isEditingTitle || isEditingContent {
                    // 편집 종료
                    isEditingTitle = false
                    isEditingContent = false
                    saveChanges()
                } else {
                    // 축소
                    onExpandToggle()
                }
            } else {
                // 축소 상태에서 탭하면 확장
                generateHapticFeedback()
                onExpandToggle()
                onBringToFront()
            }
        }
        // 롱프레스 제스처 - 확장만 처리
        .onLongPressGesture(minimumDuration: 0.5) {
            if !isEditMode && !position.isExpanded {
                generateHapticFeedback()
                onExpandToggle()
                onBringToFront()
            }
        }
        // 드래그 제스처
        .gesture(
            DragGesture(minimumDistance: 5)
                .onChanged { value in
                    if !isEditMode && !isEditingContent && !isEditingTitle {
                        onDragChanged(value.translation)
                    }
                }
                .onEnded { value in
                    if !isEditMode && !isEditingContent && !isEditingTitle {
                        onDragEnded(value.translation)
                    }

                }
        )
        .onChange(of: isEditMode) { newValue in
            if !newValue {
                saveChanges()
                isEditingTitle = false
                isEditingContent = false
            }
        }
    }
}

// MARK: - 메모 선택기 뷰
struct MemoSelectorView: View {
    var availableMemos: [Memo]
    var onMemoSelected: ([Memo]) -> Void
    
    @State private var selectedMemos: Set<String> = []
    @State private var searchText = ""
    @Environment(\.presentationMode) var presentationMode
    
    var filteredMemos: [Memo] {
        if searchText.isEmpty {
            return availableMemos
        } else {
            return availableMemos.filter { memo in
                memo.title.localizedCaseInsensitiveContains(searchText) ||
                memo.content.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // 검색 바
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("메모 검색", text: $searchText)
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                
                List {
                    ForEach(filteredMemos) { memo in
                        Button(action: {
                            toggleMemoSelection(memo.id)
                        }) {
                            HStack {
                                Image(systemName: selectedMemos.contains(memo.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedMemos.contains(memo.id) ? .blue : .gray)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(memo.title)
                                        .font(.headline)
                                    
                                    Text(memo.content)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                            }
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                }
                .listStyle(PlainListStyle())
                
                // 하단 툴바
                HStack {
                    Button(action: {
                        selectedMemos.removeAll()
                    }) {
                        Text("선택 취소")
                    }
                    .disabled(selectedMemos.isEmpty)
                    
                    Spacer()
                    
                    Text("\(selectedMemos.count)개 선택됨")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button(action: {
                        completeSelection()
                    }) {
                        Text("추가")
                            .bold()
                    }
                    .disabled(selectedMemos.isEmpty)
                }
                .padding()
                .background(Color(.systemGray6))
            }
            .navigationTitle("메모 추가")
            .navigationBarItems(
                leading: Button("취소") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
    
    private func toggleMemoSelection(_ memoID: String) {
        if selectedMemos.contains(memoID) {
            selectedMemos.remove(memoID)
        } else {
            selectedMemos.insert(memoID)
        }
    }
    
    private func completeSelection() {
        let selectedMemoList = availableMemos.filter { memo in
            selectedMemos.contains(memo.id)
        }
        
        onMemoSelected(selectedMemoList)
        presentationMode.wrappedValue.dismiss()
    }
} 


