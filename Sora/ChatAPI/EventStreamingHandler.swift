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
        let rawString = String(data: data, encoding: .utf8)
        var processedString: String = ""
        

        if rawString!.components(separatedBy: "\n").count != 1 && rawString!.contains("""
"status":"
""")  && rawString!.contains("""
response.
"""){
            for str in rawString!.components(separatedBy: "\n") {
                var added: Bool = false
                if str.hasPrefix("data: {") {
                    processedString = str.components(separatedBy: "data: ")[1]
                    var dict = try? JSONSerialization.jsonObject(with: processedString.data(using: .utf8)!, options: []) as? [String: Any]
                    if added == false {
                        process(dict ?? [:])
                        added = true
                    }
                }
            }
        } else {
            processedString = String(rawString!.dropFirst(5))
            if processedString.hasPrefix("data: ") {
                if processedString.components(separatedBy: "data: ").count > 1 {
                    processedString = processedString.components(separatedBy: "data: ")[1]
                }
            }
            if processedString.hasPrefix("data: ") {
                if processedString.components(separatedBy: "data: ").count > 1 {
                    processedString = processedString.components(separatedBy: "data: ")[1]
                }
            }
            if processedString.hasPrefix("data: ") {
                if processedString.components(separatedBy: "data: ").count > 1 {
                    processedString = processedString.components(separatedBy: "data: ")[1]
                }
            }
            var dict = try? JSONSerialization.jsonObject(with: processedString.data(using: .utf8)!, options: []) as? [String: Any]
            if ((dict?.isEmpty) != nil) {
                print(rawString)
            }
            process(dict ?? [:])
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

                bufferText += delta; onText(delta)
            }
            if let call = LLMResponseParser.toolCall(obj, provider: ModelProvider.gemini) {
                onFunc(call)
            }
            finishReason = ((obj["candidates"] as? [[String:Any]])?
                .first?["finishReason"] as? String) ?? finishReason
            
        case .openai:
            if let delta = LLMResponseParser.textDelta(obj, provider: ModelProvider.openai) {
                bufferText += delta; onText(delta)
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
