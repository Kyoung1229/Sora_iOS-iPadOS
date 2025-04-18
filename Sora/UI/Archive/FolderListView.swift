import SwiftUI

struct FolderListView: View {
    @State private var folders: [MemoFolder] = []
    @State private var isShowingNewFolderSheet = false
    @State private var newFolderName = ""
    @State private var newFolderDescription = ""
    @State private var isLoading = true
    @State private var showDeleteAlert = false
    @State private var folderToDelete: MemoFolder?
    
    var body: some View {
        NavigationView {
            ZStack {
                List {
                    ForEach(folders) { folder in
                        NavigationLink(destination: FolderCanvasView(folder: folder)) {
                            VStack(alignment: .leading) {
                                Text(folder.name)
                                    .font(.headline)
                                
                                Text("\(FolderManager.getMemosInFolder(folderID: folder.id).count) 메모")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                if !folder.description.isEmpty {
                                    Text(folder.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Text("마지막 수정: \(formattedDate(folder.lastModified))")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 4)
                        }
                        .contextMenu {
                            Button(action: {
                                folderToDelete = folder
                                showDeleteAlert = true
                            }) {
                                Label("삭제", systemImage: "trash")
                            }
                        }
                    }
                }
                .refreshable {
                    loadFolders()
                }
                .overlay(Group {
                    if folders.isEmpty && !isLoading {
                        ContentUnavailableView(
                            "폴더가 없습니다",
                            systemImage: "folder.badge.plus",
                            description: Text("+ 버튼을 눌러 새 폴더를 만들어 보세요")
                        )
                    }
                })
                
                if isLoading {
                    ProgressView()
                }
            }
            .navigationTitle("폴더")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        isShowingNewFolderSheet = true
                    }) {
                        Image(systemName: "folder.badge.plus")
                    }
                }
            }
            .sheet(isPresented: $isShowingNewFolderSheet) {
                NavigationView {
                    Form {
                        Section(header: Text("새 폴더")) {
                            TextField("폴더 이름", text: $newFolderName)
                            TextField("설명 (선택사항)", text: $newFolderDescription)
                        }
                    }
                    .navigationTitle("새 폴더 만들기")
                    .navigationBarItems(
                        leading: Button("취소") {
                            isShowingNewFolderSheet = false
                            resetNewFolderFields()
                        },
                        trailing: Button("저장") {
                            addNewFolder()
                            isShowingNewFolderSheet = false
                        }
                        .disabled(newFolderName.isEmpty)
                    )
                }
            }
            .alert(isPresented: $showDeleteAlert) {
                Alert(
                    title: Text("폴더 삭제"),
                    message: Text("'\(folderToDelete?.name ?? "")'을(를) 삭제하시겠습니까? 폴더 내 메모는 삭제되지 않습니다."),
                    primaryButton: .destructive(Text("삭제")) {
                        if let folder = folderToDelete {
                            deleteFolder(folder)
                        }
                    },
                    secondaryButton: .cancel()
                )
            }
        }
        .onAppear {
            loadFolders()
        }
    }
    
    private func loadFolders() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let loadedFolders = FolderManager.loadFolders()
            
            DispatchQueue.main.async {
                folders = loadedFolders.sorted { $0.lastModified > $1.lastModified }
                isLoading = false
            }
        }
    }
    
    private func addNewFolder() {
        let newFolder = MemoFolder(
            name: newFolderName,
            description: newFolderDescription
        )
        
        FolderManager.addFolder(newFolder)
        folders.append(newFolder)
        folders.sort { $0.lastModified > $1.lastModified }
        resetNewFolderFields()
    }
    
    private func resetNewFolderFields() {
        newFolderName = ""
        newFolderDescription = ""
    }
    
    private func deleteFolder(_ folder: MemoFolder) {
        FolderManager.deleteFolder(id: folder.id)
        folders.removeAll { $0.id == folder.id }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct FolderListView_Previews: PreviewProvider {
    static var previews: some View {
        FolderListView()
    }
} 