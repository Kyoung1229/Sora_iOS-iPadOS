import Foundation

struct SystemPrompt {
    func loadFileContent(resourceName: String, fileExtension: String) -> String? {
        guard let fileURL = Bundle.main.url(forResource: resourceName, withExtension: fileExtension) else {
            print("파일을 찾을 수 없습니다: \(resourceName).\(fileExtension)")
            return nil
        }
        
        do {
            let fileContent = try String(contentsOf: fileURL, encoding: .utf8)
            return fileContent
        } catch {
            print("파일 읽기 실패: \(error.localizedDescription)")
            return nil
        }
    }
    
    func get() -> String {
        if let content = loadFileContent(resourceName: "BasicSystemPrompt", fileExtension: "txt") {
            return content
        } else {
            return "{SORAERROR: Failed to load system prompt contentSORAERROR}"
        }
    }
}

