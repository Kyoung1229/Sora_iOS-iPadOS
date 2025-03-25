import SwiftUI

struct ChatViewTopPanel: View {
    var title: String
    var body: some View {
      HStack(alignment: .center) {
      Spacer()
      Text(title)
              .font(.title2)
          .fontWeight(.medium)
          .lineLimit(1)
          .bold()
          .padding(.bottom, 4.0)
          .frame(maxWidth: 250)
      Spacer()
    }
      .padding(.bottom, 4.0)
    .background(.ultraThickMaterial)
  }
}

struct ChatViewTopPanel_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
                    VStack(spacing: 20) {
                        ForEach(0..<50) { i in
                            Text("내용 \(i)")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.gray.opacity(0.2))
                        }
                    }
                    .padding()
                }
        .safeAreaInset(edge: .top) {
            ChatViewTopPanel(title: "새로운 채팅")
        }
    }
}
