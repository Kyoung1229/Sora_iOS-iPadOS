import SwiftUI

struct ChatBubble_Model_Animate: View {
    var baseMessage: String
    var updatedChunk: String
    var animationDuration: Double
    @Environment(\.colorScheme) var colorScheme
    
    @State private var isAnimating: Bool = false
    
    // 애니메이션을 위한 변수들
    private let characterDelay: Double = 0.01
    private let typewriterMaxDelay: Double = 0.5
    
    // 두 텍스트를 결합하여 표시
    private var fullMessage: String {
        return baseMessage + updatedChunk
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 이미 표시된 베이스 메시지와 업데이트된 텍스트 결합
            HStack(alignment: .bottom, spacing: 0) {
                // 메인 텍스트
                Text(fullMessage)
                    .font(.system(size: 15))
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                
                // 타이핑 커서 (깜박임 효과)
                if !updatedChunk.isEmpty {
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: 2, height: 15)
                        .opacity(isAnimating ? 0.5 : 0)
                        .animation(
                            Animation.easeInOut(duration: 0.5)
                                .repeatForever(autoreverses: true),
                            value: isAnimating
                        )
                        .padding(.leading, 2)
                }
            }
            .padding(EdgeInsets(top: 14, leading: 18, bottom: 14, trailing: 18))
            .background(
                ZStack {
                    // 메인 배경 - 블러 효과로 유리 질감
                    RoundedRectangle(cornerRadius: 18)
                        .fill(.ultraThinMaterial)
                    
                    // 미묘한 그라데이션 오버레이로 깊이감 추가
                    RoundedRectangle(cornerRadius: 18)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    colorScheme == .dark ? 
                                        Color.blue.opacity(0.05) : 
                                        Color.blue.opacity(0.03),
                                    colorScheme == .dark ? 
                                        Color.purple.opacity(0.05) : 
                                        Color.purple.opacity(0.03)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .opacity(0.7)
                    
                    // 타이핑 중 미묘한 펄스 효과 (아주 미세하게)
                    if !updatedChunk.isEmpty {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color.accentColor.opacity(0.02))
                            .opacity(isAnimating ? 0.6 : 0.3)
                            .animation(
                                Animation.easeInOut(duration: 1.0)
                                    .repeatForever(autoreverses: true),
                                value: isAnimating
                            )
                    }
                    
                    // 테두리 강화
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    colorScheme == .dark ? 
                                        Color.white.opacity(0.08) : 
                                        Color.black.opacity(0.06),
                                    colorScheme == .dark ? 
                                        Color.white.opacity(0.05) : 
                                        Color.black.opacity(0.03)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                }
            )
            .shadow(color: colorScheme == .dark ? 
                    Color.black.opacity(0.15) : 
                    Color.black.opacity(0.08), 
                   radius: 3, x: 0, y: 1)
        }
        .frame(maxWidth: UIScreen.main.bounds.width * 0.85, alignment: .leading)
        .onAppear {
            // 애니메이션 활성화
            withAnimation {
                isAnimating = true
            }
        }
        .accessibilityLabel("모델 응답 중: \(fullMessage)")
    }
}

// 미리보기
struct ChatBubble_Model_Animate_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            ChatBubble_Model_Animate(
                baseMessage: "안녕하세요, ",
                updatedChunk: "무엇을 도와드릴까요?",
                animationDuration: 0.5
            )
        }
        .padding()
    }
} 