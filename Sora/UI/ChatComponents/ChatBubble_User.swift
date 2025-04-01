import SwiftUI

struct ChatBubble_User: View {
    var message: String
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            // 사용자 메시지 텍스트
            Text(message)
                .font(.system(size: 15))
                .padding(EdgeInsets(top: 14, leading: 18, bottom: 14, trailing: 18))
                .fixedSize(horizontal: false, vertical: true)
                // 다크 모드에서는 더 밝은 텍스트
                .foregroundColor(.white)
                .background(
                    ZStack {
                        // 주요 배경
                        RoundedRectangle(cornerRadius: 18)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.accentColor.opacity(0.9),
                                        Color.accentColor
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: Color.accentColor.opacity(0.3), radius: 2, x: 0, y: 1)
                        
                        // 미묘한 질감 오버레이
                        RoundedRectangle(cornerRadius: 18)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(0.1),
                                        Color.white.opacity(0.05)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .opacity(0.6)
                            .blendMode(.overlay)
                        
                        // 내부 하이라이트
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(0.2),
                                        Color.white.opacity(0.1)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.5
                            )
                    }
                )
                // 애니메이션 추가 (나타날 때)
                .transition(.scale(scale: 0.95).combined(with: .opacity))
        }
        .frame(maxWidth: UIScreen.main.bounds.width * 0.85, alignment: .trailing)
        .accessibilityLabel("사용자: \(message)")
    }
}

// 미리보기
struct ChatBubble_User_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            ChatBubble_User(message: "안녕하세요, 도움이 필요해요.")
        }
        .padding()
    }
} 