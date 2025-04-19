import SwiftUI

struct ChatBubble_Model_Animate: View {
    var baseMessage: String
    var updatedChunk: String
    var animationDuration: Double
    @Environment(\.colorScheme) var colorScheme
    
    // 애니메이션 상태 관리
    @State private var isAnimating: Bool = false
    @State private var isCompleted: Bool = false
    @State private var currentTextLength: Int = 0
    
    // 두 텍스트를 결합하여 표시 (줄바꿈 처리 추가)
    private var fullMessage: String {
        let combined = baseMessage + updatedChunk
        return combined.replacingOccurrences(of: "\\n", with: "\n")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 텍스트 컨테이너 - 더 단순한 구조로 변경
            ZStack(alignment: .topLeading) {
                if let attributed = try? AttributedString(markdown: fullMessage, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                    Text(attributed)
                        .font(.system(size: 15, weight: .regular))
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundColor(Color("ChatBubbleTextColor_Model"))
                        .lineSpacing(4) // 줄 간격 추가
                        .multilineTextAlignment(.leading) // 왼쪽 정렬 명시
                        .padding(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
                        // 애니메이션 제거하여 텍스트 렌더링 안정화
                        .animation(.smooth(duration: 0.3), value: fullMessage)
                        .animation(nil, value: baseMessage)
                        .animation(.smooth(duration: 0.3), value: updatedChunk)
                        .allowsHitTesting(false) // 터치 이벤트 방지
                }
                // 더 안정적인 배경
                
                // 텍스트 내용
                
            }
            
            // 타이핑 인디케이터 (더 단순하게 구현)
            if !isCompleted {
                HStack(spacing: 3) {
                    ForEach(0..<3) { i in
                        Circle()
                            .fill(Color.accentColor.opacity(0.6))
                            .frame(width: 4, height: 4)
                            .opacity(isAnimating ? 0.8 : 0.3)
                            .animation(
                                Animation.easeInOut(duration: 0.3) // 애니메이션 기간 단축
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(i) * 0.1),
                                value: isAnimating
                            )
                    }
                }
                .padding(.leading, 16)
                .padding(.top, 4)
                .transition(.opacity)
            }
        }
        .frame(maxWidth: UIScreen.main.bounds.width * 0.85, alignment: .leading)
        .onAppear {
            // 애니메이션 즉시 활성화
            withAnimation(.easeIn(duration: 0.2)) {
                isAnimating = true
            }
            
            // 애니메이션 완료 표시 - 지연시간 축소
            DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
                isCompleted = true
                withAnimation(.easeOut(duration: 0.2)) {
                    isCompleted = true
                }
            }
        }
        // 더 안정적인 ID 시스템 (길이 기반 + 해시 조합)
        .id("bubble-\(baseMessage.count)-\(updatedChunk.count)-\(isCompleted ? "done" : "typing")")
        .transition(.opacity) // 단순한 투명도 트랜지션
        .accessibilityLabel("모델 응답 중: \(fullMessage)")
    }
}

// 미리보기
struct ChatBubble_Model_Animate_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            ChatBubble_Model_Animate(
                baseMessage: "안녕하세요, ",
                updatedChunk: "무엇을 도와드릴까요?\n더 필요한 것이 있으신가요?",
                animationDuration: 0.3
            )
            
            ChatBubble_Model_Animate(
                baseMessage: "줄바꿈 테스트:",
                updatedChunk: "\\n1. 첫 번째 항목\\n2. 두 번째 항목",
                animationDuration: 0.3
            )
        }
        .padding()
    }
} 
