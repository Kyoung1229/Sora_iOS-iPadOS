import SwiftUI

struct ChatScrollView: View {
    // messages 배열: 각 요소는 딕셔너리 타입이며,
    // "role" 키와 "parts" 키(여기서 parts는 딕셔너리 배열, 첫 요소의 "text"가 메시지 내용)를 포함함.
    let messages: [[String: Any]]
    
    var body: some View {
        VStack {
            Spacer(minLength: 50)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(0..<messages.count, id: \.self) { index in
                        if let role = messages[index]["role"] as? String,
                           let parts = messages[index]["parts"] as? [[String: Any]],
                           let firstPart = parts.first,
                           let text = firstPart["text"] as? String {
                            
                            // role에 따라 다른 채팅 말풍선 사용
                            if role.lowercased() == "user" {
                                ChatBubble_User(message: text)
                            } else if role.lowercased() == "model" {
                                ChatBubble_Model(message: text)
                            } else {
                                // role 값이 예상과 다를 경우 기본 텍스트 표시
                                Text(text)
                            }
                        }
                    }
                }
                .padding()
            }
            
        }
    }
}


struct ChatScrollView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleMessages: [[String: Any]] = [
                    [
                        "role": "user",
                        "parts": [
                            ["text": "안녕하세요!"]
                        ]
                    ],
                    [
                        "role": "model",
                        "parts": [
                            ["text": "안녕하세요, 무엇을 도와드릴까요?"]
                        ]
                    ],
                    [
                        "role": "user",
                        "parts": [
                            ["text": "채팅 말풍선이 어떻게 작동하는지 궁금합니다."]
                        ]
                    ],
                    [
                        "role": "model",
                        "parts": [
                            ["text": "저는 다양한 작업을 도와드릴 수 있습니다."]
                        ]
                    ]
                ]
        ChatScrollView(messages: sampleMessages)
    }
}
