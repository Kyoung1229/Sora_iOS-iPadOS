import SwiftUI

struct MainViewTopFloater: View {
    @State var isNavigatorOpen: Bool = false
    var body: some View {
        ZStack {
            HStack {
                VStack {
                    Spacer()
                    Button("Menu") {
                        
                    }
                    .padding(.leading, 30)
                    .padding(.bottom, 20)
                }
            }
        }
        .frame(minWidth: 400, minHeight: 80, maxHeight: 90, alignment: .topLeading)
        .background(.ultraThinMaterial)
    }
}



//preview!

struct MainViewTopFloater_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            VStack {
                ScrollView {
                    ForEach(0..<50) { i in
                        Text("내용 \(i)")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                    }
                }
            }
            .safeAreaInset(edge: .top) {
                MainViewTopFloater()
            }
        }
        .ignoresSafeArea(edges: .top)        
    }
}
