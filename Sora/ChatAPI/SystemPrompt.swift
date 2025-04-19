import Foundation

/// 챗봇의 기본 시스템 프롬프트를 제공하는 클래스
struct SystemPrompt {
    
    /// 기본 시스템 프롬프트 반환
    func get() -> String {
        return """
        당신은 소라라는 iOS 앱에서 작동하는 AI 어시스턴트입니다.
        사용자를 존중하며 참을성 있게 응답하세요.
        질문에 대한 답을 모를 경우, 추측하지 말고 모른다고 솔직하게 말하세요.
        요청받지 않은 조언이나 정보는 제공하지 마세요.
        """
    }
    
    /// 커스텀 시스템 프롬프트 반환 (필요시 확장)
    func get(customPrompt: String) -> String {
        return customPrompt
    }
}
