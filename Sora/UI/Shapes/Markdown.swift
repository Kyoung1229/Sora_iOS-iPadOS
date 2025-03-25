import SwiftUI

struct MarkdownText: View {
    let text: String
    
    var body: some View {
        if let attrStr = try? AttributedString(markdown: text, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            Text(attrStr)
        } else {
            Text(text)
        }
    }
}

