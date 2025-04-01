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
                    "text": SystemPrompt().get()
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
    
    /// 이미지를 포함한 메시지로 스트리밍 API 호출
    func callWithStreamingAndImage(model: String,
                                  apiKey: String,
                                  textMessage: String,
                                  imageBase64: String,
                                  mimeType: String = "image/jpeg",
                                  previousMessages: [[String: Any]] = [],
                                  onChunk: @escaping @Sendable ([String: Any]) -> Void,
                                  onComplete: @escaping @Sendable (String?) -> Void = { _ in }) {
        // Gemini Pro Vision 모델 사용
        let visionModel = model.contains("vision") ? model : "gemini-pro-vision"
        
        guard let endpoint = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(visionModel):streamGenerateContent?alt=sse&key=\(apiKey)") else {
            return
        }
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 이미지를 포함한 새 사용자 메시지 생성
        let newUserMessage: [String: Any] = [
            "role": "user",
            "parts": [
                [
                    "text": textMessage
                ],
                [
                    "inline_data": [
                        "mime_type": mimeType,
                        "data": imageBase64
                    ]
                ]
            ]
        ]
        
        // 이전 메시지에 새 메시지 추가
        var allMessages = previousMessages
        allMessages.append(newUserMessage)
        
        let requestBody: [String: Any] = [
            "contents": allMessages,
            "system_instruction": [
                "parts": [
                    "text": SystemPrompt().get()
                ]
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody, options: [])
        } catch {
            onComplete("JSON 직렬화 오류: \(error.localizedDescription)")
            return
        }
        
        let delegate = StreamingDataHandler(onChunk: onChunk, onComplete: onComplete)
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        let task = session.dataTask(with: request)
        task.resume()
    }
    
    /// 로컬 이미지 파일을 Base64로 인코딩
    func encodeImageToBase64(imageURL: URL) -> String? {
        do {
            let imageData = try Data(contentsOf: imageURL)
            return imageData.base64EncodedString()
        } catch {
            print("이미지 인코딩 오류: \(error.localizedDescription)")
            return nil
        }
    }
}

/// 스트리밍 응답 Data를 처리하여 JSON Dictionary로 파싱 후 onChunk 클로저에 전달하는 delegate 클래스
final class StreamingDataHandler: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let onChunk: @Sendable ([String: Any]) -> Void
    private let onComplete: @Sendable (String?) -> Void
    private var finishReason: String?
    
    init(onChunk: @escaping @Sendable ([String: Any]) -> Void,
         onComplete: @escaping @Sendable (String?) -> Void) {
        self.onChunk = onChunk
        self.onComplete = onComplete
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        processChunkData(data)
    }
    
    private func processChunkData(_ chunk: Data) {
        // 직접 JSON Dictionary로 파싱 시도
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
        
        // 문자열로 변환 후 "data:" 접두사 제거 및 재파싱
        guard let str = String(data: chunk, encoding: .utf8) else { return }
        let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = "data:"
        let jsonString = trimmed.hasPrefix(prefix)
            ? String(trimmed.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            : trimmed
        
        guard let jsonData = jsonString.data(using: .utf8) else { return }
        if let dict = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
            checkFinishReason(dict)
            onChunk(dict)
        } else if let array = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [[String: Any]] {
            array.forEach { 
                checkFinishReason($0)
                onChunk($0) 
            }
        }
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
