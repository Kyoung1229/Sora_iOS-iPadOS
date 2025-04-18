import Foundation

struct GeminiAPI {
    /// 스트리밍 API 호출 – 응답을 JSON Dictionary로 파싱하여 onChunk 클로저에 전달
    func callWithStreaming(model: String,
                           apiKey: String,
                           messages: [[String: Any]],
                           onChunk: @escaping @Sendable ([String: Any]) -> Void,
                           onComplete: @escaping @Sendable (String?) -> Void = { _ in }) {
        guard let endpoint = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):streamGenerateContent?alt=sse&key=\(apiKey)") else {
            return
        }
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "contents": messages,
            "system_instruction": [
                "parts": [
                    ["text": SystemPrompt().get()]
                ]
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody, options: [])
        } catch {
            return
        }
        
        let delegate = StreamingDataHandler(onChunk: onChunk, onComplete: onComplete)
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        let task = session.dataTask(with: request)
        task.resume()
    }
}

/// 스트리밍 응답 Data를 처리하여 JSON Dictionary로 파싱 후 onChunk 클로저에 전달하는 delegate 클래스
final class StreamingDataHandler: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let onChunk: @Sendable ([String: Any]) -> Void
    private let onComplete: @Sendable (String?) -> Void
    private var finishReason: String?
    private var buffer: String = ""  // 불완전한 JSON 데이터를 보관하는 버퍼 추가
    
    init(onChunk: @escaping @Sendable ([String: Any]) -> Void,
         onComplete: @escaping @Sendable (String?) -> Void) {
        self.onChunk = onChunk
        self.onComplete = onComplete
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        processChunkData(data)
    }
    
    private func processChunkData(_ chunk: Data) {
        // 1. 직접 JSON Dictionary로 파싱 시도
        if let dict = try? JSONSerialization.jsonObject(with: chunk, options: []) as? [String: Any] {
            checkFinishReason(dict)
            onChunk(dict)
            return
        } else if let array = try? JSONSerialization.jsonObject(with: chunk, options: []) as? [[String: Any]] {
            array.forEach { 
                checkFinishReason($0)
                onChunk($0) 
            }
            return
        }
        
        // 2. 문자열로 변환 후 SSE 형식 처리
        guard let chunkString = String(data: chunk, encoding: .utf8) else {
            print("⚠️ 청크를 문자열로 변환할 수 없음")
            return
        }
        
        // SSE 형식 처리 ("data:" 접두사 처리)
        var jsonLines = [String]()
        let ssePrefix = "data:"
        
        if chunkString.contains(ssePrefix) {
            // 여러 줄로 분리
            let lines = chunkString.components(separatedBy: .newlines)
            
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty { continue }
                
                // "data:" 접두사가 있는 라인 처리
                if trimmed.hasPrefix(ssePrefix) {
                    let jsonLine = trimmed.dropFirst(ssePrefix.count)
                                         .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !jsonLine.isEmpty {
                        jsonLines.append(jsonLine)
                    }
                } else {
                    // 접두사 없는 라인은 버퍼에 추가
                    buffer += trimmed
                    if isValidJson(buffer) {
                        jsonLines.append(buffer)
                        buffer = ""
                    }
                }
            }
        } else {
            // SSE 형식이 아닌 경우
            let trimmed = chunkString.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                jsonLines.append(trimmed)
            }
        }
        
        // 개별 JSON 라인 처리
        for jsonString in jsonLines {
            if let jsonData = jsonString.data(using: .utf8) {
                if let dict = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
                    checkFinishReason(dict)
                    onChunk(dict)
                } else if let array = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [[String: Any]] {
                    array.forEach {
                        checkFinishReason($0)
                        onChunk($0)
                    }
                } else {
                    // 파싱 실패 시 콘텐츠만 추출 시도
                    extractContentFromPartialJson(jsonString)
                }
            }
        }
    }
    
    // 부분적인 JSON에서 텍스트 내용 추출 시도
    private func extractContentFromPartialJson(_ jsonString: String) {
        // 단순화된 정규식 패턴으로 텍스트 추출 시도
        let textPattern = "\"text\"\\s*:\\s*\"([^\"]+)\""
        if let regex = try? NSRegularExpression(pattern: textPattern),
           let match = regex.firstMatch(in: jsonString, options: [], range: NSRange(jsonString.startIndex..., in: jsonString)) {
            
            if let textRange = Range(match.range(at: 1), in: jsonString) {
                let extractedText = String(jsonString[textRange])
                print("🔍 부분 JSON에서 텍스트 추출: \(extractedText.prefix(20))...")
                
                // 추출된 텍스트로 가상 JSON 구성
                let artificialJson: [String: Any] = [
                    "candidates": [
                        [
                            "content": [
                                "parts": [
                                    ["text": extractedText]
                                ]
                            ]
                        ]
                    ]
                ]
                
                onChunk(artificialJson)
                return
            }
        }
        
        // 정규식으로 실패하면 로그만 출력
        if jsonString.count < 500 {
            print("⚠️ JSON 파싱 실패: \(jsonString)")
        } else {
            print("⚠️ JSON 파싱 실패: \(jsonString.prefix(200))...")
        }
    }
    
    // JSON 문자열이 유효한지 검사
    private func isValidJson(_ string: String) -> Bool {
        guard let data = string.data(using: .utf8) else { return false }
        return (try? JSONSerialization.jsonObject(with: data)) != nil
    }
    
    // finishReason 필드 확인 및 추출
    private func checkFinishReason(_ dict: [String: Any]) {
        // Gemini API 응답 구조에서 finishReason 필드 추출
        if let candidates = dict["candidates"] as? [[String: Any]],
           let firstCandidate = candidates.first,
           let finishReason = firstCandidate["finishReason"] as? String {
            self.finishReason = finishReason
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            print("스트리밍 호출 에러: \(error.localizedDescription)")
            onComplete(nil)
        } else {
            print("스트리밍 완료. finishReason: \(finishReason ?? "없음")")
            onComplete(finishReason)
        }
    }
}
