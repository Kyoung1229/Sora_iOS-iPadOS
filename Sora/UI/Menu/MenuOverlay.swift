import SwiftUI

struct MenuOverlay: View {
    @Binding var isMenuOpen: Bool

    var body: some View {
        ZStack(alignment: .trailing) {
            // 반투명 배경: 탭하면 메뉴 닫힘
            Color.black.opacity(0.3)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    withAnimation(.spring()) {
                        isMenuOpen = false
                    }
                }
            
            // 오른쪽에 고정된 메뉴 패널
            VStack(alignment: .leading, spacing: 20) {
                Button(action: {
                    // 홈 이동 동작
                }) {
                    Text("홈")
                        .font(.headline)
                        .foregroundColor(.black)
                }
                
                Button(action: {
                    // 홈 이동 동작
                }) {
                    Text("채팅")
                        .font(.headline)
                        .foregroundColor(.black)
                }
                
                Button(action: {
                    // 설정 화면 이동 동작
                }) {
                    Text("설정")
                        .font(.headline)
                        .foregroundColor(.black)
                }
                
               
                
                Spacer()
            }
            .padding()
            .frame(width: 250)
            .background(Color.white)
        }
    }
}

struct MenuOverlay_Previews: PreviewProvider {
    @State static var isOpen: Bool = true
    static var previews: some View {
        MenuOverlay(isMenuOpen: $isOpen)
    }
}
