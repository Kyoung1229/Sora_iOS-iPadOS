import SwiftUI

struct SoraMainView: View {
    @State private var showNavigator: Bool = false
    @StateObject private var gyro = GyroManager()
    
    // 화면 크기 계산
    let screenWidth = UIScreen.main.bounds.width
    let screenHeight = UIScreen.main.bounds.height
    let headerHeight: CGFloat = 60
    let navigatorWidth: CGFloat = UIScreen.main.bounds.width * 0.6
    
    var body: some View {
        NavigationView {
            ZStack {
                // 배경색
                Color("BackgroundColor")
                    .ignoresSafeArea()
                
                // 메인 콘텐츠 영역 (내비게이터 표시 여부와 관계없이 항상 동일한 레이아웃)
                VStack(spacing: 0) {
                    // 상단 헤더 바 자리를 위한 공간 (실제 헤더는 ZStack으로 위에 겹침)
                    Rectangle()
                        .frame(height: headerHeight)
                        .foregroundColor(.clear)
                    
                    // 실제 콘텐츠 영역 (빈 공간)
                    Spacer()
                }
                
                // 상단 헤더 바 (DynamicGlassMaterial 적용)
                VStack {
                    ZStack {
                        // 헤더 배경 (GlassMaterial)
                        GlassRectangle(
                            gyro: gyro,
                            cornerRadius: 0,
                            width: screenWidth,
                            height: headerHeight + 40  // safe area 포함
                        )
                        
                        // 헤더 콘텐츠
                        HStack {
                            // 내비게이터 토글 버튼
                            Button(action: {
                                withAnimation(showNavigator ? .smooth(duration: 0.3) : .smooth(duration: 0.5)) {
                                    showNavigator.toggle()
                                }
                            }) {
                                Image(systemName: showNavigator ? "sidebar.left" : "sidebar.right")
                                    .font(.title3)
                                    .foregroundColor(.primary)
                                    .padding(10)
                                    .background(Circle().fill(.ultraThinMaterial))
                            }
                            .padding(.leading, 16)
                            
                            Spacer()
                            
                            // 중앙 타이틀
                            Text("소라")
                                .font(.title3.bold())
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            // 오른쪽 여백 (균형을 위해)
                            Color.clear
                                .frame(width: 44, height: 44)
                        }
                        .padding(.top, 40)  // safe area를 위한 패딩
                    }
                    .frame(height: headerHeight + 40)  // safe area 포함
                    
                    Spacer()
                }
                .ignoresSafeArea(edges: .top)
                .zIndex(1)  // zIndex를 1로 변경 (내비게이터보다 낮게)
                
                // 내비게이터가 표시될 때 여백 클릭을 감지하는 오버레이
                if showNavigator {
                    Color.black.opacity(0.01) // 거의 투명한 오버레이
                        .onTapGesture {
                            withAnimation(.smooth(duration: 0.3)) {
                                showNavigator = false
                            }
                        }
                        .ignoresSafeArea()
                        .zIndex(1.5) // 헤더보다는 위에, 내비게이터보다는 아래에 배치
                }
                
                // 내비게이터 (ZStack으로 콘텐츠와 헤더 위에 배치)
                HStack(spacing: 0) {
                    if showNavigator {
                        MainNavigator()
                            .frame(width: navigatorWidth, alignment: .center)
                            .transition(.move(edge: .leading))
                            .ignoresSafeArea()
                    }
                    
                    Spacer()
                }
                .ignoresSafeArea(edges: .top)
                .zIndex(2)  // zIndex를 2로 변경 (헤더보다 높게)
            }
            .navigationBarHidden(true)
        }
    }
}

struct SoraMainView_Previews: PreviewProvider {
    static var previews: some View {
        SoraMainView()
    }
} 
