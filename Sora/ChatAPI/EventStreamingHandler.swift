import Foundation

final class EventStreamingHandler: NSObject, URLSessionDataDelegate {
    enum Provider { case gemini, openai }
    private let provider: Provider
    private let onText: (String)->Void
    private let onFunc: (ToolCall)->Void
    private let onDone: (String?,Error?)->Void
    private var bufferText = ""
    private var finishReason: String?
    
    init(provider: Provider,
         onText: @escaping (String)->Void,
         onFunc: @escaping (ToolCall)->Void,
         onDone: @escaping (String?,Error?)->Void)
    {
        self.provider = provider; self.onText = onText
        self.onFunc = onFunc; self.onDone = onDone
    }
    
    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive data: Data)
    {
        guard let raw = String(data: data, encoding: .utf8) else { return }
        print(raw)
        raw.split(separator: "\n").forEach { line in
            guard line.hasPrefix("data:") else { return }
            let jsonStr = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            guard jsonStr != "[DONE]",
                  let jData = jsonStr.data(using: .utf8),
                  let obj   = try? JSONSerialization.jsonObject(with: jData) as? [String:Any]
            else { return }
            process(obj)
        }
    }
    
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didCompleteWithError error: Error?)
    { onDone(finishReason, error) }
    

    
    private func process(_ obj:[String:Any]) {
        switch provider {
        case .gemini:
            if let delta = LLMResponseParser.textDelta(obj, provider: ModelProvider.gemini) {
                bufferText += delta; onText(bufferText)
            }
            if let call = LLMResponseParser.toolCall(obj, provider: ModelProvider.gemini) {
                onFunc(call)
            }
            finishReason = ((obj["candidates"] as? [[String:Any]])?
                .first?["finishReason"] as? String) ?? finishReason
            
        case .openai:
            if let delta = LLMResponseParser.textDelta(obj, provider: ModelProvider.openai) {
                bufferText += delta; onText(bufferText)
            }
            if let call = LLMResponseParser.toolCall(obj, provider: ModelProvider.openai) {
                onFunc(call)
            }
            if obj["type"] as? String == "response.completed" {
                finishReason = "stop"
            }
        }
    }
}
