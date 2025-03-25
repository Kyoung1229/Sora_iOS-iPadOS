import SwiftUI

struct ChatBubble_User: View {
    var message: String
    var body: some View {
        VStack {
            MarkdownText(text: message)
                .fontWeight(.medium)
                .foregroundColor(Color("ChatbubbleTextColor_User"))
                .multilineTextAlignment(.trailing)
                .padding(12)
                .background(Color("ChatBubbleBackgroundColor_User"))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .frame(maxWidth: 300, alignment: .trailing)  // 최대 너비 제한 (필요에 따라 조절)
            
                .shadow(color: Color("ChatBubbleShadowColor_User"), radius: 10)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.trailing, 10)
        }
}

struct ChatBubble_User_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            ChatBubble_User(message: "안녕하세요!")
            ChatBubble_User(message: "안녕하세요! 이 메시지는 좀 더 긴 텍스트를 포함하고 있어서 여러 줄로 늘어납니다. 텍스트 길이에 따라 말풍선의 크기가 자동으로 조절됩니다.")
        }
        .padding()
    }
}
