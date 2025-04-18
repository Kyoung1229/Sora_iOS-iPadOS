import Foundation

// 로컬 파일에서 ModelProvider 정의를 가져옵니다.
// import ModelProvider

struct GeminiAPI {
    private var customApiKey: String?
    
    // API 키 설정 메소드 추가
    mutating func setApiKey(_ key: String) {
        self.customApiKey = key
    }
    
    // API 키 획득 헬퍼 함수
    private func getApiKey() -> String {
        // 커스텀 API 키가 설정되어 있으면 사용, 그렇지 않으면 전역 getAPI 함수 사용
        return customApiKey ?? getAPI(for: ModelProvider.gemini)
    }
    
    // 비‑스트리밍
    func generate(model: String,
                  messages:[[String:Any]],
                  systemPrompt: String = "",
                  generationCfg: [String:Any] = [:],
                  completion: @escaping(Result<[String:Any],Error>)->Void)
    {
        let url = URL(string:
                        "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(getApiKey())")!
        var req = URLRequest(url:url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField:"Content-Type")
        
        var body: [String:Any] = ["contents":messages]
        if !systemPrompt.isEmpty {
            body["system_instruction"] = ["parts":[["text":systemPrompt]]]
        }
        if !generationCfg.isEmpty { body["generationConfig"] = generationCfg }
        req.httpBody = try! JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: req) { d,_,e in
            if let e=e { completion(.failure(e)); return }
            guard let d=d,
                  let j=try? JSONSerialization.jsonObject(with:d) as? [String:Any]
            else { completion(.failure(NSError())); return }
            completion(.success(j))
        }.resume()
    }
    
    // 스트리밍
    func stream(model:String,
                messageDicts:[[String:Any]],
                tools:[[String:Any]] = [],
                systemPrompt:String = "",
                onText:@escaping(String)->Void,
                onFunc:@escaping(ToolCall)->Void,
                onDone:@escaping(String?,Error?)->Void)
    {
        let url = URL(string:
                        "https://generativelanguage.googleapis.com/v1beta/models/\(model):streamGenerateContent?alt=sse&key=\(getApiKey())")!
        var req = URLRequest(url:url)
        req.httpMethod="POST"
        req.setValue("application/json", forHTTPHeaderField:"Content-Type")
        
        var body:[String:Any] = ["contents":messageDicts]
        if !systemPrompt.isEmpty {
            body["system_instruction"] = ["parts":[["text":systemPrompt]]]
        }
        if !tools.isEmpty { body["tools"] = tools }
        req.httpBody = try! JSONSerialization.data(withJSONObject:body)
        
        let handler = EventStreamingHandler(
            provider: EventStreamingHandler.Provider.gemini,
            onText:onText,
            onFunc:onFunc,
            onDone:onDone)
        URLSession(configuration:.default,
                   delegate:handler,
                   delegateQueue:nil)
        .dataTask(with:req).resume()
    }
}

struct OpenAIAPI {
    private var customApiKey: String?
    
    // API 키 설정 메소드 추가
    mutating func setApiKey(_ key: String) {
        self.customApiKey = key
    }
    
    // API 키 획득 헬퍼 함수
    private func getApiKey() -> String {
        // 커스텀 API 키가 설정되어 있으면 사용, 그렇지 않으면 전역 getAPI 함수 사용
        return customApiKey ?? getAPI(for: ModelProvider.openai)
    }
    
    // 비‑스트리밍
    func generate(model:String,
                  input:Any,
                  instructions:String = "",
                  completion:@escaping(Result<[String:Any],Error>)->Void)
    {
        let url = URL(string:"https://api.openai.com/v1/responses")!
        var req = URLRequest(url:url)
        req.httpMethod="POST"
        req.setValue("application/json",forHTTPHeaderField:"Content-Type")
        req.setValue("Bearer \(getApiKey())",forHTTPHeaderField:"Authorization")
        
        var body:[String:Any] = ["model":model,"input":input]
        if !instructions.isEmpty { body["instructions"] = instructions }
        req.httpBody = try! JSONSerialization.data(withJSONObject:body)
        
        URLSession.shared.dataTask(with:req){d,_,e in
            if let e=e { completion(.failure(e)); return }
            guard let d=d,
                  let j=try? JSONSerialization.jsonObject(with:d) as? [String:Any]
            else { completion(.failure(NSError())); return }
            completion(.success(j))
        }.resume()
    }
    
    // 스트리밍
    func stream(model:String,
                input:Any,
                tools:[[String:Any]] = [],
                instructions:String = "",
                onText:@escaping(String)->Void,
                onFunc:@escaping(ToolCall)->Void,
                onDone:@escaping(String?,Error?)->Void)
    {
        let url = URL(string:"https://api.openai.com/v1/responses")!
        var req = URLRequest(url:url)
        req.httpMethod="POST"
        req.setValue("application/json",forHTTPHeaderField:"Content-Type")
        req.setValue("Bearer \(getApiKey())",forHTTPHeaderField:"Authorization")
        
        var body:[String:Any] = ["model":model,"input":input,"stream":true]
        if !tools.isEmpty     { body["tools"] = tools }
        if !instructions.isEmpty { body["instructions"] = instructions }
        req.httpBody = try! JSONSerialization.data(withJSONObject:body)
        
        let handler = EventStreamingHandler(
            provider: EventStreamingHandler.Provider.openai,
            onText:onText,
            onFunc:onFunc,
            onDone:onDone)
        URLSession(configuration:.default,
                   delegate:handler,
                   delegateQueue:nil)
        .dataTask(with:req).resume()
    }
}
