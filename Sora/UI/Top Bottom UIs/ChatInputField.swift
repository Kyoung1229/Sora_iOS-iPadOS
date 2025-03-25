import SwiftUI

struct ChatInputField: View {
  var body: some View {
      HStack(alignment: .center) {
      Spacer()
          Text("채팅")
              .font(.title)
              .fontWeight(.semibold)
              .multilineTextAlignment(.center)
              .lineLimit(1)
              .bold()
        .foregroundColor(.white)
      Spacer()
    }
      .padding(.bottom, 4.0)
    .background(.ultraThinMaterial)
  }
}

struct ChatInputField_Previews: PreviewProvider {
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
            ChatInputField()
        }
    }
}
