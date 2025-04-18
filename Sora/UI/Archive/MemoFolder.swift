import Foundation
import SwiftUI

// 폴더 정보 모델
struct MemoFolder: Codable, Identifiable {
    var id: String
    var name: String
    var description: String
    var memoPositions: [MemoPosition]
    var creationDate: Date
    var lastModified: Date
    
    init(id: String = UUID().uuidString, 
         name: String, 
         description: String = "", 
         memoPositions: [MemoPosition] = [], 
         creationDate: Date = Date(), 
         lastModified: Date = Date()) {
        self.id = id
        self.name = name
        self.description = description
        self.memoPositions = memoPositions
        self.creationDate = creationDate
        self.lastModified = lastModified
    }
}

// 메모 위치 정보 모델
struct MemoPosition: Codable, Identifiable, Equatable {
    var id: String // 메모 ID
    var x: CGFloat
    var y: CGFloat
    var zIndex: Double
    var scale: CGFloat
    var isExpanded: Bool
    
    init(id: String, x: CGFloat = 0, y: CGFloat = 0, zIndex: Double = 0, scale: CGFloat = 1.0, isExpanded: Bool = false) {
        self.id = id
        self.x = x
        self.y = y
        self.zIndex = zIndex
        self.scale = scale
        self.isExpanded = isExpanded
    }
    
    static func == (lhs: MemoPosition, rhs: MemoPosition) -> Bool {
        return lhs.id == rhs.id
    }
}

// 폴더 관리 클래스
class FolderManager {
    private static let folderFileName = "folders.json"
    private static var folders: [MemoFolder] = []
    private static var folderCache: [String: MemoFolder] = [:]
    private static var isInitialized = false
    
    // 폴더 저장 경로
    private static func getFolderFilePath() -> URL? {
        guard let docDirectory = MemoProcessor.getMemoDirectory()?.deletingLastPathComponent() else {
            return nil
        }
        return docDirectory.appendingPathComponent(folderFileName)
    }
    
    // 폴더 목록 불러오기
    static func loadFolders() -> [MemoFolder] {
        if isInitialized {
            return folders
        }
        
        guard let fileURL = getFolderFilePath() else {
            return []
        }
        
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                let data = try Data(contentsOf: fileURL)
                folders = try JSONDecoder().decode([MemoFolder].self, from: data)
                
                // 캐시에 저장
                folderCache = Dictionary(uniqueKeysWithValues: folders.map { ($0.id, $0) })
                isInitialized = true
                return folders
            }
        } catch {
            print("폴더 로드 실패: \(error)")
        }
        
        // 기본 폴더 생성
        if folders.isEmpty {
            let defaultFolder = MemoFolder(name: "기본 폴더", description: "기본 메모 폴더")
            folders = [defaultFolder]
            folderCache[defaultFolder.id] = defaultFolder
            saveAllFolders()
        }
        
        isInitialized = true
        return folders
    }
    
    // 폴더 저장하기
    static func saveAllFolders() {
        guard let fileURL = getFolderFilePath() else {
            return
        }
        
        do {
            let data = try JSONEncoder().encode(folders)
            try data.write(to: fileURL)
            
            // 캐시 업데이트
            folderCache = Dictionary(uniqueKeysWithValues: folders.map { ($0.id, $0) })
        } catch {
            print("폴더 저장 실패: \(error)")
        }
    }
    
    // 폴더 추가
    static func addFolder(_ folder: MemoFolder) {
        loadFolders() // 초기화 확인
        folders.append(folder)
        folderCache[folder.id] = folder
        saveAllFolders()
    }
    
    // 폴더 삭제
    static func deleteFolder(id: String) {
        loadFolders() // 초기화 확인
        folders.removeAll { $0.id == id }
        folderCache.removeValue(forKey: id)
        saveAllFolders()
    }
    
    // 폴더 업데이트
    static func updateFolder(_ folder: MemoFolder) {
        if let index = folders.firstIndex(where: { $0.id == folder.id }) {
            folders[index] = folder
            folderCache[folder.id] = folder
            saveAllFolders()
        }
    }
    
    // 폴더에 메모 추가
    static func addMemoToFolder(folderID: String, memoID: String, at position: CGPoint? = nil) {
        guard let folder = folderCache[folderID] ?? folders.first(where: { $0.id == folderID }) else {
            return
        }
        
        var updatedFolder = folder
        
        // 이미 존재하는지 확인
        if !updatedFolder.memoPositions.contains(where: { $0.id == memoID }) {
            // 위치 지정이 없으면 자동 배치
            let pos = position ?? CGPoint(
                x: CGFloat.random(in: 50...300),
                y: CGFloat.random(in: 50...300)
            )
            
            let newPosition = MemoPosition(
                id: memoID,
                x: pos.x,
                y: pos.y,
                zIndex: Double(updatedFolder.memoPositions.count)
            )
            
            updatedFolder.memoPositions.append(newPosition)
            updatedFolder.lastModified = Date()
            
            updateFolder(updatedFolder)
        }
    }
    
    // 폴더에서 메모 제거
    static func removeMemoFromFolder(folderID: String, memoID: String) {
        guard let folder = folderCache[folderID] ?? folders.first(where: { $0.id == folderID }) else {
            return
        }
        
        var updatedFolder = folder
        updatedFolder.memoPositions.removeAll { $0.id == memoID }
        updatedFolder.lastModified = Date()
        
        updateFolder(updatedFolder)
    }
    
    // 메모 위치 업데이트
    static func updateMemoPosition(folderID: String, memoID: String, newPosition: MemoPosition) {
        guard let folder = folderCache[folderID] ?? folders.first(where: { $0.id == folderID }) else {
            return
        }
        
        var updatedFolder = folder
        
        if let index = updatedFolder.memoPositions.firstIndex(where: { $0.id == memoID }) {
            updatedFolder.memoPositions[index] = newPosition
            updatedFolder.lastModified = Date()
            updateFolder(updatedFolder)
        } else {
            // 메모가 없으면 추가
            addMemoToFolder(folderID: folderID, memoID: memoID, at: CGPoint(x: newPosition.x, y: newPosition.y))
        }
    }
    
    // 폴더 내 모든 메모 가져오기
    static func getMemosInFolder(folderID: String) -> [Memo] {
        guard let folder = folderCache[folderID] ?? folders.first(where: { $0.id == folderID }) else {
            return []
        }
        
        var memos: [Memo] = []
        
        for position in folder.memoPositions {
            if let memo = MemoProcessor.findMemo(id: position.id) {
                memos.append(memo)
            }
        }
        
        return memos
    }
} 