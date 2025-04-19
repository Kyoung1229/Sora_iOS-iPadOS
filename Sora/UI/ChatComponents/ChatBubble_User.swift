import SwiftUI
import UIKit

struct ChatBubble_User: View {
    var messageItem: MessageItem
    @Environment(\.colorScheme) var colorScheme
    
    // 줄바꿈 문자를 실제 줄바꿈으로 변환하는 계산 속성
    private var formattedMessage: String {
        return messageItem.content.replacingOccurrences(of: "\\n", with: "\n")
    }
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            // 이미지 표시
            if let data = messageItem.imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.6)
                    .cornerRadius(15)
            }
            // 사용자 메시지 텍스트
            if !formattedMessage.isEmpty {
                Text(formattedMessage)
                    .font(.system(size: 15, weight: .medium))
                    .padding(EdgeInsets(top: 14, leading: 18, bottom: 14, trailing: 18))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(4)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(Color("ChatBubbleTextColor_User"))
                    .shadow(color: Color("ChatBubbleShadowColor_Model"), radius: 0)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color("ChatBubbleBackgroundColor_User"))
                        }
                    )
                    .shadow(color: Color("ChatBubbleShadowColor_User").opacity(1), radius: 7, x: 0, y: 2)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(maxWidth: UIScreen.main.bounds.width * 0.85, alignment: .trailing)
        .accessibilityLabel("사용자: \(messageItem.content)")
    }
}

// 미리보기
struct ChatBubble_User_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            VStack(spacing: 16) {
                ChatBubble_User(
                    messageItem: MessageItem(role: .user,
                                             content: "안녕하세요, 도움이 필요해요.",
                                             imageData: nil,
                                             timestamp: Date())
                )
                ChatBubble_User(
                    messageItem: MessageItem(role: .user,
                                             content: "",
                                             imageData: UIImage(named: "SampleImage")?.pngData(),
                                             timestamp: Date())
                )
                ChatBubble_User(
                    messageItem: MessageItem(role: .user,
                                             content: "텍스트와 함께 이미지\n테스트.",
                                             imageData: UIImage(named: "SampleImage")?.pngData(),
                                             timestamp: Date())
                )
            }
            .padding()
        }
    }
} 
