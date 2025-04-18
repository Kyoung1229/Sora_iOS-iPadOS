import Foundation

struct Memo: Identifiable {
    let id: String
    var title: String
    var content: String
    var thoughts: String
    var links: String
}

struct MemoProcessor {
    // 메모 캐시 저장소
    private static var memoCache: [String: Memo] = [:]
    private static var saveQueue = DispatchQueue(label: "com.sora.memo.saveQueue", qos: .background)
    private static var pendingSaves: [String: Memo] = [:]
    private static var batchSaveTimer: Timer?
    private static let batchSaveInterval: TimeInterval = 2.0 // 2초 간격으로 일괄 저장
    
    // 앱 문서 디렉토리의 메모 저장 폴더 경로 반환
    static func getMemoDirectory() -> URL? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let memoDirectory = documentsDirectory.appendingPathComponent("Memos", isDirectory: true)
        
        // 디렉토리가 존재하지 않으면 생성
        if !FileManager.default.fileExists(atPath: memoDirectory.path) {
            do {
                try FileManager.default.createDirectory(at: memoDirectory, withIntermediateDirectories: true)
            } catch {
                print("메모 디렉토리 생성 실패: \(error)")
                return nil
            }
        }
        
        return memoDirectory
    }
    
    // 현재 날짜와 밀리초까지 포함한 ID 생성
    static func generateID() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmmss"
        let now = Date()
        let dateString = formatter.string(from: now)
        
        // 밀리초 계산 (두 자리만 사용)
        let calendar = Calendar.current
        let nanoseconds = calendar.component(.nanosecond, from: now)
        let milliseconds = nanoseconds / 1_000_000
        let millisString = String(format: "%02d", min(milliseconds, 99))
        
        // 타입 목록: IA, IN, REF, SUM, REC 중 IN 사용 (필요시 다른 타입 사용 가능)
        return "IN\(dateString)\(millisString)"
    }

    // Memo 객체를 마크다운 문자열로 변환
    static func toMarkdown(memo: Memo) -> String {
        return """
        ID: \(memo.id)

        ---

        \(memo.content)

        ---

        \(memo.thoughts)

        ---

        \(memo.links)
        """
    }
    
    // 파일 이름에서 메모 ID 추출 (파일명: title__ID.md 형식)
    static func extractIDFromFileName(_ fileName: String) -> String? {
        let components = fileName.components(separatedBy: "__")
        guard components.count >= 2 else { return nil }
        
        let lastComponent = components.last!
        if lastComponent.hasSuffix(".md") {
            let idWithoutExtension = String(lastComponent.dropLast(3))
            
            // 기존 형식 처리 ("IN(yyyyMMdd_HHmmssSSS)")
            if let regex = try? NSRegularExpression(pattern: "([A-Z]+)\\((.+)\\)"),
               let match = regex.firstMatch(in: idWithoutExtension, range: NSRange(idWithoutExtension.startIndex..., in: idWithoutExtension)) {
                if let typeRange = Range(match.range(at: 1), in: idWithoutExtension),
                   let contentRange = Range(match.range(at: 2), in: idWithoutExtension) {
                    let type = String(idWithoutExtension[typeRange])
                    let content = String(idWithoutExtension[contentRange])
                        .replacingOccurrences(of: "_", with: "")
                    // 새 형식으로 변환
                    return "\(type)\(content)"
                }
            }
            
            // 새 형식은 그대로 반환
            return idWithoutExtension
        }
        
        // 기존 형식 처리 ("IN(yyyyMMdd_HHmmssSSS)")
        if let regex = try? NSRegularExpression(pattern: "([A-Z]+)\\((.+)\\)"),
           let match = regex.firstMatch(in: lastComponent, range: NSRange(lastComponent.startIndex..., in: lastComponent)) {
            if let typeRange = Range(match.range(at: 1), in: lastComponent),
               let contentRange = Range(match.range(at: 2), in: lastComponent) {
                let type = String(lastComponent[typeRange])
                let content = String(lastComponent[contentRange])
                    .replacingOccurrences(of: "_", with: "")
                // 새 형식으로 변환
                return "\(type)\(content)"
            }
        }
        
        // 새 형식은 그대로 반환
        return lastComponent
    }
    
    // ID로 메모 파일 찾기
    static func findMemoFile(for id: String) -> URL? {
        guard let memoDirectory = getMemoDirectory() else { return nil }
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: memoDirectory, includingPropertiesForKeys: nil)
            
            // 파일 이름에 ID가 포함된 파일 찾기
            for fileURL in files {
                let fileName = fileURL.lastPathComponent
                if let fileID = extractIDFromFileName(fileName), fileID == id {
                    return fileURL
                }
            }
            
            // 예전 형식의 파일을 위한 대안 검색
            for fileURL in files {
                guard let content = try? String(contentsOf: fileURL),
                      let memo = fromMarkdown(content),
                      memo.id == id else {
                    continue
                }
                return fileURL
            }
        } catch {
            print("메모 파일 찾기 실패: \(error)")
        }
        
        return nil
    }

    // 안전한 파일 이름 생성 (ID 기반으로 고유성 보장)
    static func fileName(for memo: Memo) -> String {
        var safeTitle = memo.title.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "[\\\\/:*?\"<>|]", with: "", options: .regularExpression)
            .replacingOccurrences(of: " ", with: "_")
        
        if safeTitle.isEmpty {
            safeTitle = "Untitled"
        }
        
        // ID를 파일명에 포함시켜 고유성 보장 (title__ID.md 형식)
        let fileName = "\(safeTitle)__\(memo.id).md"
        return fileName
    }

    // 메모 캐시에서 조회
    static func getMemoFromCache(id: String) -> Memo? {
        return memoCache[id]
    }
    
    // 메모 캐시에 저장
    static func cacheMemo(_ memo: Memo) {
        memoCache[memo.id] = memo
    }
    
    // 메모 캐시에서 제거
    static func removeMemoFromCache(id: String) {
        memoCache.removeValue(forKey: id)
    }
    
    // 파일 이름 변경 (제목 변경 시)
    static func renameFile(for memo: Memo) -> Bool {
        guard let existingFileURL = findMemoFile(for: memo.id) else {
            print("이름 변경할 파일을 찾을 수 없음: \(memo.id)")
            return false
        }
        
        let newFileName = fileName(for: memo)
        guard let memoDirectory = getMemoDirectory() else { return false }
        let newFileURL = memoDirectory.appendingPathComponent(newFileName)
        
        // 현재 파일명에서 ID 부분 추출
        let currentFileName = existingFileURL.lastPathComponent
        let fileNameWithoutExtension = existingFileURL.deletingPathExtension().lastPathComponent
        
        // 새 파일명과 비교 (변경이 필요없으면 건너뜀)
        if currentFileName == newFileName {
            print("파일명 변경 불필요: 동일한 이름")
            return true
        }
        
        do {
            // 파일명 변경
            try FileManager.default.moveItem(at: existingFileURL, to: newFileURL)
            print("파일명 변경 성공: '\(fileNameWithoutExtension)' -> '\(newFileName)'")
            return true
        } catch {
            print("파일명 변경 실패: \(error)")
            return false
        }
    }
    
    // 메모 저장을 위한 파일 URL 가져오기 (기존 파일 업데이트 또는 새 파일 생성)
    static func getFileURL(for memo: Memo) -> URL? {
        guard let memoDirectory = getMemoDirectory() else { return nil }
        
        // 1. 먼저 기존 파일이 있는지 확인
        if let existingFileURL = findMemoFile(for: memo.id) {
            return existingFileURL
        }
        
        // 2. 없으면 새 파일명으로 URL 생성
        let fileName = fileName(for: memo)
        return memoDirectory.appendingPathComponent(fileName)
    }
    
    // Memo 객체를 마크다운 파일로 저장 (비동기, 배치 저장)
    static func saveToMarkdownFile(memo: Memo) {
        // 캐시 업데이트
        cacheMemo(memo)
        
        // 대기 목록에 추가
        saveQueue.async {
            pendingSaves[memo.id] = memo
            
            // 타이머가 없으면 새로 생성
            if batchSaveTimer == nil {
                DispatchQueue.main.async {
                    batchSaveTimer = Timer.scheduledTimer(withTimeInterval: batchSaveInterval, repeats: false) { _ in
                        processBatchSave()
                    }
                }
            }
        }
    }
    
    // 즉시 저장 (동기식)
    static func saveImmediately(memo: Memo) {
        let markdownText = toMarkdown(memo: memo)
        
        // 타이틀 변경 여부 확인 및 파일명 변경
        if let cachedMemo = getMemoFromCache(id: memo.id), cachedMemo.title != memo.title {
            if renameFile(for: memo) {
                // 파일명 변경에 성공한 경우 내용만 덮어쓰기
                if let fileURL = findMemoFile(for: memo.id) {
                    do {
                        try markdownText.write(to: fileURL, atomically: true, encoding: .utf8)
                        print("제목 변경 후 내용 업데이트 완료: \(fileURL)")
                        cacheMemo(memo)
                        return
                    } catch {
                        print("제목 변경 후 내용 업데이트 실패: \(error)")
                    }
                }
            }
        }
        
        // 파일명 변경에 실패했거나 새 파일인 경우 일반 저장 로직 실행
        guard let fileURL = getFileURL(for: memo) else {
            print("메모 저장 경로 생성 실패")
            return
        }
        
        do {
            // 이전 파일이 있고 파일명이 다르면 삭제 (제목 변경 시)
            if let existingURL = findMemoFile(for: memo.id), existingURL.path != fileURL.path {
                try FileManager.default.removeItem(at: existingURL)
            }
            
            try markdownText.write(to: fileURL, atomically: true, encoding: .utf8)
            print("마크다운 즉시 저장 완료: \(fileURL)")
            
            // 캐시 업데이트
            cacheMemo(memo)
        } catch {
            print("저장 실패: \(error)")
        }
    }
    
    // 배치 저장 처리
    private static func processBatchSave() {
        saveQueue.async {
            // 현재 대기 중인 저장 작업들을 복사하고 목록 초기화
            let savesToProcess = pendingSaves
            pendingSaves.removeAll()
            
            // 타이머 제거
            DispatchQueue.main.async {
                batchSaveTimer?.invalidate()
                batchSaveTimer = nil
            }
            
            // 각 메모 저장
            for (_, memo) in savesToProcess {
                // 타이틀 변경 여부 확인 및 파일명 변경
                if let cachedMemo = getMemoFromCache(id: memo.id), cachedMemo.title != memo.title {
                    let markdownText = toMarkdown(memo: memo)
                    
                    if renameFile(for: memo) {
                        // 파일명 변경에 성공한 경우 내용만 덮어쓰기
                        if let fileURL = findMemoFile(for: memo.id) {
                            do {
                                try markdownText.write(to: fileURL, atomically: true, encoding: .utf8)
                                print("배치: 제목 변경 후 내용 업데이트 완료: \(fileURL)")
                                cacheMemo(memo)
                                continue
                            } catch {
                                print("배치: 제목 변경 후 내용 업데이트 실패: \(error)")
                            }
                        }
                    }
                }
                
                // 파일명 변경에 실패했거나 새 파일인 경우 일반 저장 로직 실행
                let markdownText = toMarkdown(memo: memo)
                
                // 저장할 파일 URL 가져오기 (기존 파일 업데이트 또는 새 파일)
                guard let fileURL = getFileURL(for: memo) else {
                    print("메모 저장 경로 생성 실패")
                    pendingSaves[memo.id] = memo  // 실패 시 재시도를 위해 다시 추가
                    continue
                }
                
                do {
                    // 이전 파일이 있고 파일명이 다르면 삭제 (제목 변경 시)
                    if let existingURL = findMemoFile(for: memo.id), existingURL.path != fileURL.path {
                        try FileManager.default.removeItem(at: existingURL)
                    }
                    
                    try markdownText.write(to: fileURL, atomically: true, encoding: .utf8)
                    print("마크다운 배치 저장 완료: \(fileURL)")
                    
                    // 캐시 업데이트
                    cacheMemo(memo)
                } catch {
                    print("배치 저장 실패: \(error)")
                    // 실패한 경우 다시 대기 목록에 추가
                    pendingSaves[memo.id] = memo
                }
            }
            
            // 실패한 항목이 있으면 타이머 재설정
            if !pendingSaves.isEmpty {
                DispatchQueue.main.async {
                    batchSaveTimer = Timer.scheduledTimer(withTimeInterval: batchSaveInterval, repeats: false) { _ in
                        processBatchSave()
                    }
                }
            }
        }
    }
    
    // 앱 종료 시 호출하여 대기 중인 모든 메모 즉시 저장
    static func saveAllPendingMemos() {
        saveQueue.sync {
            guard !pendingSaves.isEmpty else {
                return
            }
            
            for (_, memo) in pendingSaves {
                // 즉시 저장 로직으로 처리
                saveImmediately(memo: memo)
            }
            
            pendingSaves.removeAll()
        }
    }

    // 마크다운 문자열을 파싱하여 Memo 객체 생성
    static func fromMarkdown(_ markdown: String) -> Memo? {
        let components = markdown.components(separatedBy: "\n---\n")
        guard components.count == 4 else {
            return nil
        }
        
        let idLine = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
        guard idLine.starts(with: "ID: ") else {
            return nil
        }
        let idString = idLine.replacingOccurrences(of: "ID: ", with: "")
        
        // ID 형식 정규화 (이전 형식도 지원)
        var normalizedID = idString
        // 이전 형식: "IN(yyyyMMdd_HHmmssSSS)" 확인 및 변환
        if let regex = try? NSRegularExpression(pattern: "([A-Z]+)\\((.+)\\)"),
           let match = regex.firstMatch(in: idString, range: NSRange(idString.startIndex..., in: idString)) {
            if let typeRange = Range(match.range(at: 1), in: idString),
               let contentRange = Range(match.range(at: 2), in: idString) {
                let type = String(idString[typeRange])
                let content = String(idString[contentRange])
                    .replacingOccurrences(of: "_", with: "")
                // 새 형식으로 변환
                normalizedID = "\(type)\(content)"
            }
        }
        
        // 먼저 캐시에서 확인
        if let cachedMemo = getMemoFromCache(id: normalizedID) {
            return cachedMemo
        }
        
        let content = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
        let thoughts = components[2].trimmingCharacters(in: .whitespacesAndNewlines)
        let links = components[3].trimmingCharacters(in: .whitespacesAndNewlines)
        
        let memo = Memo(id: normalizedID, title: "Untitled", content: content, thoughts: thoughts, links: links)
        
        // 캐시에 저장
        cacheMemo(memo)
        
        return memo
    }
    
    // 메모 삭제
    static func deleteMemo(id: String) -> Bool {
        guard let fileURL = findMemoFile(for: id) else {
            print("삭제할 메모 파일을 찾을 수 없음: \(id)")
            return false
        }
        
        do {
            try FileManager.default.removeItem(at: fileURL)
            
            // 캐시 및 대기 목록에서 제거
            removeMemoFromCache(id: id)
            pendingSaves.removeValue(forKey: id)
            
            print("메모 삭제 완료: \(id)")
            return true
        } catch {
            print("메모 삭제 실패: \(error)")
            return false
        }
    }
    
    // 모든 메모 로드 (캐싱 적용, 중복 제거)
    static func loadAllMemos() -> [Memo] {
        guard let memoDirectory = getMemoDirectory() else {
            return []
        }
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: memoDirectory, includingPropertiesForKeys: nil)
            let markdownFiles = files.filter { $0.pathExtension == "md" }
            
            var memos: [Memo] = []
            var processedIDs = Set<String>() // 중복 방지를 위한 ID 집합
            
            for url in markdownFiles {
                guard let content = try? String(contentsOf: url),
                      var memo = fromMarkdown(content) else {
                    continue
                }
                
                // 파일 이름에서 제목 추출 (파일명: title__ID.md 형식)
                let fileName = url.deletingPathExtension().lastPathComponent
                let fileNameComponents = fileName.components(separatedBy: "__")
                
                if fileNameComponents.count >= 2 {
                    // 새 형식의 파일 이름에서 제목 추출
                    memo.title = fileNameComponents[0].replacingOccurrences(of: "_", with: " ")
                } else {
                    // 기존 형식의 파일 이름 처리
                    memo.title = fileName.replacingOccurrences(of: "_", with: " ")
                }
                
                // ID 중복 체크 (같은 ID의 메모는 하나만 로드)
                if !processedIDs.contains(memo.id) {
                    memos.append(memo)
                    processedIDs.insert(memo.id)
                    
                    // 캐시에 저장
                    cacheMemo(memo)
                }
            }
            
            return memos
        } catch {
            print("메모 로드 실패: \(error)")
            return []
        }
    }
    
    // 메모 ID로 메모 찾기
    static func findMemo(id: String) -> Memo? {
        // 1. 캐시에서 확인
        if let cachedMemo = getMemoFromCache(id: id) {
            return cachedMemo
        }
        
        // 2. 파일에서 로드
        guard let fileURL = findMemoFile(for: id),
              let content = try? String(contentsOf: fileURL),
              var memo = fromMarkdown(content) else {
            return nil
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
        
        // 캐시에 저장
        cacheMemo(memo)
        
        return memo
    }
}
