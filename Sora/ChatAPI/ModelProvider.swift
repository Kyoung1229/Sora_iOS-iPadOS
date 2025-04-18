enum ModelProvider { case openai, gemini }
extension ModelProvider {
    static func detect(from model: String) -> ModelProvider {
        let l = model.lowercased()
        return (l.contains("gpt") || l.contains("openai")) ? .openai : .gemini
    }
}
