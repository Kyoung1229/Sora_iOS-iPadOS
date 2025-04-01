import SwiftUI

struct ChatBubble_Model: View {
    var message: String
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 모델 답변 내용
            Text(message)
                .font(.system(size: 15))
                .padding(EdgeInsets(top: 14, leading: 18, bottom: 14, trailing: 18))
                .fixedSize(horizontal: false, vertical: true)
                .foregroundColor(colorScheme == .dark ? .white : .black)
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
                // 애니메이션 추가 (나타날 때)
                .transition(.scale(scale: 0.95).combined(with: .opacity))
        }
        .frame(maxWidth: UIScreen.main.bounds.width * 0.85, alignment: .leading)
        .accessibilityLabel("모델: \(message)")
    }
}

// 미리보기
struct ChatBubble_Model_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            ChatBubble_Model(message: "안녕하세요, 무엇을 도와드릴까요? 저는 Gemini AI 어시스턴트입니다.")
        }
        .padding()
    }
} 