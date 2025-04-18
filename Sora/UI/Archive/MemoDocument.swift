import Foundation
import UIKit

class MemoDocument: UIDocument {
    var memo: Memo
    
    init(fileURL: URL, memo: Memo) {
        self.memo = memo
        super.init(fileURL: fileURL)
    }
    
    // 문서 컨텐츠 로드
    override func load(fromContents contents: Any, ofType typeName: String?) throws {
        guard let data = contents as? Data,
              let content = String(data: data, encoding: .utf8),
              var loadedMemo = MemoProcessor.fromMarkdown(content) else {
            throw NSError(domain: "MemoDocumentDomain", code: 100, userInfo: nil)
        }
        
        // 파일 이름에서 제목 추출
        let fileName = self.fileURL.deletingPathExtension().lastPathComponent
        
        // 새 형식 파일명: title__ID.md
        let fileNameComponents = fileName.components(separatedBy: "__")
        if fileNameComponents.count >= 2 {
            // 새 형식의 파일 이름에서 제목 추출
            loadedMemo.title = fileNameComponents[0].replacingOccurrences(of: "_", with: " ")
        } else {
            // 기존 형식의 파일 이름 처리
            loadedMemo.title = fileName.replacingOccurrences(of: "_", with: " ")
        }
        
        self.memo = loadedMemo
    }
    
    // 문서 컨텐츠 저장
    override func contents(forType typeName: String) throws -> Any {
        let markdownContent = MemoProcessor.toMarkdown(memo: memo)
        guard let data = markdownContent.data(using: .utf8) else {
            throw NSError(domain: "MemoDocumentDomain", code: 101, userInfo: nil)
        }
        return data
    }
    
    // 파일 이름 변경 시 호출
    override func updateChangeCount(_ changeKind: UIDocument.ChangeKind) {
        super.updateChangeCount(changeKind)
    }
}

// MemoDocument 관리를 위한 헬퍼 클래스
class MemoDocumentManager {
    // 문서 디렉토리에서 특정 메모 ID에 대한 문서 로드
    static func loadDocument(for memoID: String, completion: @escaping (MemoDocument?) -> Void) {
        // 메모 ID로 파일 찾기
        guard let fileURL = MemoProcessor.findMemoFile(for: memoID) else {
            completion(nil)
            return
        }
        
        // 파일 내용 로드
        guard let content = try? String(contentsOf: fileURL),
              var memo = MemoProcessor.fromMarkdown(content),
              memo.id == memoID else {
            completion(nil)
            return
        }
        
        // 파일 이름에서 제목 추출
        let fileName = fileURL.deletingPathExtension().lastPathComponent
        let fileNameComponents = fileName.components(separatedBy: "__")
        
        if fileNameComponents.count >= 2 {
            // 새 형식의 파일 이름에서 제목 추출
            memo.title = fileNameComponents[0].replacingOccurrences(of: "_", with: " ")
        } else {
            // 기존 형식의 파일 이름 처리
            memo.title = fileName.replacingOccurrences(of: "_", with: " ")
        }
        
        let document = MemoDocument(fileURL: fileURL, memo: memo)
        completion(document)
    }
    
    // 새 메모를 문서로 생성
    static func createDocument(for memo: Memo, completion: @escaping (MemoDocument?) -> Void) {
        guard let fileURL = MemoProcessor.getFileURL(for: memo) else {
            completion(nil)
            return
        }
        
        let document = MemoDocument(fileURL: fileURL, memo: memo)
        document.save(to: fileURL, for: .forCreating) { success in
            if success {
                completion(document)
            } else {
                completion(nil)
            }
        }
    }
} 