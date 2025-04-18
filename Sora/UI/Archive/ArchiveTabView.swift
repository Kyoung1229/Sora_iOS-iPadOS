import SwiftUI

struct ArchiveTabView: View {
    enum Tab {
        case memoList
        case folderView
    }
    
    @State private var selectedTab: Tab = .memoList
    
    var body: some View {
        TabView(selection: $selectedTab) {
            MemoListView()
                .tabItem {
                    Label("메모", systemImage: "doc.text")
                }
                .tag(Tab.memoList)
            
            FolderListView()
                .tabItem {
                    Label("폴더", systemImage: "folder")
                }
                .tag(Tab.folderView)
        }
    }
}

struct ArchiveTabView_Previews: PreviewProvider {
    static var previews: some View {
        ArchiveTabView()
    }
} 