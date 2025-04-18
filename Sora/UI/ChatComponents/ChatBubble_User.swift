import SwiftUI

struct ChatBubble_User: View {
    var message: String
    @Environment(\.colorScheme) var colorScheme
    
    // 줄바꿈 문자를 실제 줄바꿈으로 변환하는 계산 속성
    private var formattedMessage: String {
        return message.replacingOccurrences(of: "\\n", with: "\n")
    }
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            // 사용자 메시지 텍스트
            Text(formattedMessage)
                .font(.system(size: 15, weight: .medium))
                .padding(EdgeInsets(top: 14, leading: 18, bottom: 14, trailing: 18))
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(4) // 줄 간격 추가
                .multilineTextAlignment(.leading) // 왼쪽 정렬 명시
                // 다크 모드에서는 더 밝은 텍스트
                .foregroundColor(Color("ChatBubbleTextColor_User"))
                .shadow(color: Color("ChatBubbleShadowColor_Model"), radius: 0)
                .background(
                    ZStack {
                        // 주요 배경 (귀여운 버블 형태)
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color("ChatBubbleBackgroundColor_User"))
                    }
                )
                .shadow(color: Color("ChatBubbleShadowColor_User").opacity(1), radius: 7, x: 0, y: 2)
                // 애니메이션 추가 (밑에서 위로 올라가는 효과)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .frame(maxWidth: UIScreen.main.bounds.width * 0.85, alignment: .trailing)
        .accessibilityLabel("사용자: \(message)")
    }
}

// 미리보기
struct ChatBubble_User_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            VStack {
                ChatBubble_User(message: "안녕하세요, 도움이 필요해요.")
                ChatBubble_User(message: "줄바꿈 테스트:\\n1. 첫 번째 항목\\n2. 두 번째 항목")
            }
            .padding()
        }
    }
} 
