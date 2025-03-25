import SwiftUI
import MarkdownKit
import UIKit

extension UIColor {
    func toHex() -> String {
        guard let components = cgColor.components, components.count >= 3 else { return "#000000" }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

struct MarkdownView: View {
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    var markdown: String
    
    var fontC: Color {
        colorScheme == .light ? Color.black : Color.white
    }
    
    var fontHex: String {
        colorScheme == .light ? "#0F0D0A" : "#FFFEF3"
    }
    
    var body: some View {
        let document = MarkdownParser.standard.parse(markdown)
        let generator = AttributedStringGenerator(
            fontSize: 16,
            fontFamily: "Helvetica",
            fontColor: fontHex
        )
        if let attributedString = generator.generate(doc: document) {
            return Text(AttributedString(attributedString))
        } else {
            return Text(markdown)
        }
    }
}

struct ChatBubble_Model: View {
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    @State var message: String
    var body: some View {
        VStack(spacing: -10) {
            VStack {
                var fontC: Color {
                    colorScheme == .light ? Color.black : Color.white
                }
                
                var fontHex: String {
                    colorScheme == .light ? "#0F0D0A" : "#FFFEF3"
                }
                let document = MarkdownParser.standard.parse(message)
                let generator = AttributedStringGenerator(
                    fontSize: 16,
                    fontFamily: "Helvetica",
                    fontColor: fontHex
                )
                let attributedString = generator.generate(doc: document)
                withAnimation {
                    Text(AttributedString(attributedString!))
                }
                
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        
    }
}
struct ChatBubble_Model_Animate: View {
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    // The unchanged base part of the message
    let baseMessage: String
    // The chunk that will be updated; input remains constant
    let updatedChunk: String
    
    // Animation settings
    var animationDuration: Double
    
    // Initializer with default values
    init(baseMessage: String, updatedChunk: String, animationDuration: Double = 0.8) {
        self.baseMessage = baseMessage
        self.updatedChunk = updatedChunk
        self.animationDuration = animationDuration
    }
    
    // State for animation
    @State private var opacity: Double = 0
    
    var body: some View {
        let fontHex = colorScheme == .light ? "#0F0D0A" : "#FFFEF3"
        let generator = AttributedStringGenerator(
            fontSize: 16,
            fontFamily: "Helvetica",
            fontColor: fontHex
        )
        
        // Generate attributed string for the base message
        let baseDocument = MarkdownParser.standard.parse(baseMessage)
        let baseAttributed = generator.generate(doc: baseDocument) ?? NSAttributedString(string: baseMessage)
        
        // Generate attributed string for the updated chunk
        let chunkDocument = MarkdownParser.standard.parse(updatedChunk)
        let chunkAttributed = generator.generate(doc: chunkDocument) ?? NSAttributedString(string: updatedChunk)
        
        return VStack(spacing: -10) {
            HStack(alignment: .top, spacing: 0) {
                // Base message (unchanged)
                Text(AttributedString(baseAttributed))
                
                // Animated part
                Text(AttributedString(chunkAttributed))
                    .opacity(opacity)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .onAppear {
                withAnimation(.easeIn(duration: animationDuration)) {
                    opacity = 1.0
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
struct ChatBubble_Model_Legacy: View {
    @State var message: String
    var body: some View {
        ZStack {
            VStack {
                Text(message)
                    .foregroundStyle(Color("ChatBubbleTextColor_Model"))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: 300, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ChatBubble_Model_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Group {
                    Text("기본 페이드인 애니메이션 (0.8초)")
                        .font(.headline)
                    
                    ChatBubble_Model_Animate(
                        baseMessage: "안녕하세요! ", 
                        updatedChunk: " 이것은 페이드인 애니메이션으로 표시되는 텍스트입니다. dsasd dsasd  dsasd fghjkdfghjkdfghjkdfghjkdfghjk"
                    )
                }
                
                Group {
                    Text("느린 페이드인 (1.5초)")
                        .font(.headline)
                    
                    ChatBubble_Model_Animate(
                        baseMessage: "마크다운도 지원됩니다: ", 
                        updatedChunk: "**굵은 글씨**, *기울임*, `코드`",
                        animationDuration: 1.5
                    )
                }
                
                Group {
                    Text("빠른 페이드인 (0.3초)")
                        .font(.headline)
                    
                    ChatBubble_Model_Animate(
                        baseMessage: "수학 수식 예제: ", 
                        updatedChunk: "$E = mc^2$",
                        animationDuration: 0.3
                    )
                }
                
                Group {
                    Text("매우 빠른 페이드인 (0.1초)")
                        .font(.headline)
                    
                    ChatBubble_Model_Animate(
                        baseMessage: "신속한 응답: ", 
                        updatedChunk: "이것은 매우 빠른 페이드인 속도입니다.",
                        animationDuration: 0.1
                    )
                }
                
                Group {
                    Text("긴 마크다운 텍스트 예제")
                        .font(.headline)
                    
                    ChatBubble_Model_Animate(
                        baseMessage: "마크다운 예제: ",
                        updatedChunk: """
                        **굵은 글씨**를 사용하고 *기울임*도 있고 `코드 블록`도 있습니다.
                        
                        1. 첫 번째 항목
                        2. 두 번째 항목
                        
                        > 인용구도 지원됩니다.
                        """,
                        animationDuration: 1.0
                    )
                }
                
                Group {
                    Text("일반 메시지 (애니메이션 없음)")
                        .font(.headline)
                    
                    ChatBubble_Model(message: "일반 메시지 예제입니다.")
                }
            }
            .padding()
        }
    }
}
