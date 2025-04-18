import SwiftUI

struct MemoCard: View {
    @State private var isExpanded = false
    var body: some View {
        ZStack(alignment: .center) {
            //Memo
            MemoView(memo: Memo(id: MemoProcessor.generateID(), title: "Sample Title", content: "Sample Content", thoughts: "", links: ""))
                .animation(.bouncy, value: isExpanded)
                .frame(maxWidth: isExpanded ? .infinity : 200, maxHeight: isExpanded ? .infinity : 100, alignment: .center)
                .scaleEffect(isExpanded ? 1 : 0.2)
            //Collapsed
            RoundedRectangle(cornerRadius: 20)
                .foregroundStyle(.ultraThinMaterial)
                .offset(y: isExpanded ? -20 : 0)
                .frame(width: 200, height: 100, alignment: .center)
                .opacity(isExpanded ? 0 : 1)
                .scaleEffect(isExpanded ? 1.5 : 1)
                .blur(radius: isExpanded ? 40 : 0)
        }
        .onTapGesture {
            withAnimation(.interpolatingSpring) {
                isExpanded.toggle()
            }

        }
    }
}

#Preview {
    MemoCard()
}
