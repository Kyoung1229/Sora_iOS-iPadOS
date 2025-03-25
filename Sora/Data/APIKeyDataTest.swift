import SwiftUI

struct APIKeyTestView: View {
    @State private var geminiKey: String = ""
    @State private var openaiKey: String = ""
    
    var body: some View {
        VStack(spacing: 20) {
            // Gemini API Key 입력 및 저장
            TextField("Gemini API Key 입력", text: $geminiKey)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            Button("Gemini 키 저장") {
                SoraAPIKeys.shared.save(api: .gemini, key: geminiKey)
                geminiKey = ""
            }
            .buttonStyle(.borderedProminent)

            Button("Gemini 키 불러오기") {
                if let key = SoraAPIKeys.shared.load(api: .gemini) {
                    geminiKey = key
                }
            }

            Button("Gemini 키 삭제") {
                SoraAPIKeys.shared.delete(api: .gemini)
                geminiKey = ""
            }
            .foregroundColor(.red)

            Divider()

            // OpenAI API Key 입력 및 저장
            TextField("OpenAI API Key 입력", text: $openaiKey)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            Button("OpenAI 키 저장") {
                SoraAPIKeys.shared.save(api: .openai, key: openaiKey)
                openaiKey = ""
            }
            .buttonStyle(.borderedProminent)

            Button("OpenAI 키 불러오기") {
                if let key = SoraAPIKeys.shared.load(api: .openai) {
                    openaiKey = key
                }
            }

            Button("OpenAI 키 삭제") {
                SoraAPIKeys.shared.delete(api: .openai)
                openaiKey = ""
            }
            .foregroundColor(.red)

            Spacer()
        }
        .padding()
    }
}

#Preview {
    APIKeyTestView()
}
