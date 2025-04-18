import SwiftUI

struct ChatBubble_Model: View {
    var message: String
    @Environment(\.colorScheme) var colorScheme
    
    // 줄바꿈 문자를 실제 줄바꿈으로 변환하는 계산 속성
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            if let attributed = try? AttributedString(markdown: message, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                Text(attributed)
                    .font(.system(size: 15, weight: .regular))
                    .padding(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundColor(Color("ChatBubbleTextColor_Model"))
                    // 텍스트 렌더링 옵션 설정
                    .lineSpacing(4) // 줄 간격 추가
                    .multilineTextAlignment(.leading) // 왼쪽 정렬 명시
                    // 가벼운 그림자만 추가
                    .shadow(color: colorScheme == .dark ?
                            Color.black.opacity(0.1) :
                            Color.black.opacity(0.05),
                           radius: 2, x: 0, y: 1)
                    // 애니메이션 추가 (나타날 때)
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
            }
            // 모델 답변 내용
            
        }
        .frame(maxWidth: UIScreen.main.bounds.width * 0.85, alignment: .leading)
        .accessibilityLabel("모델: \(message)")
    }
}

// 미리보기
struct ChatBubble_Model_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            ChatBubble_Model(message: "안녕하세요, 무엇을 도와드릴까요?\n저는 Gemini AI 어시스턴트입니다.")
            ChatBubble_Model(message: """
                             줄바꿈 테스트:
                             . 첫 번째 항목\\n2. 두 번째 항목
                             """)
        }
        .padding()
    }
} 
