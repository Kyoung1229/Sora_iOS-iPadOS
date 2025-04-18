import SwiftUI

struct MainNavigator: View {
    @StateObject private var gyro = GyroManager()
    @State private var offset: CGFloat = UIScreen.main.bounds.width * -0.6
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedMenu: String? = nil
    
    var body: some View {
        ZStack {
            // 배경: GlassRectangle 사용
            GlassRectangle(
                gyro: gyro,
                cornerRadius: 0,
                width: UIScreen.main.bounds.width * 0.6,
                height: UIScreen.main.bounds.height
            )
            
            // 메뉴 콘텐츠
            VStack(alignment: .leading, spacing: 0) {
                // 상단 헤더 영역 (안전 영역 고려)
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: 80)
                
                // 앱 타이틀과 구분선
                Text("소라 메뉴")
                    .font(.title2.bold())
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)
                
                Divider()
                    .background(Color.white.opacity(0.3))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                
                // 메뉴 항목들
                NavigationLink(destination: ChatListView(), tag: "chats", selection: $selectedMenu) {
                    menuItem(
                        icon: "bubble.left.and.bubble.right.fill",
                        title: "채팅 목록",
                        isSelected: selectedMenu == "chats"
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                NavigationLink(destination: SoraArchiveView(), tag: "archive", selection: $selectedMenu) {
                    menuItem(
                        icon: "archivebox.fill",
                        title: "아카이브",
                        isSelected: selectedMenu == "archive"
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
            }
            .padding(.top, 20)
        }
        .ignoresSafeArea()
        .offset(x: offset)
        .onAppear() {
            withAnimation {
                offset = 0
            }
        }
        .onDisappear() {
            withAnimation {
                offset = UIScreen.main.bounds.width * -0.6
            }
        }
        
    }
    
    // 메뉴 항목 컴포넌트
    private func menuItem(icon: String, title: String, isSelected: Bool) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .frame(width: 26, height: 26)
            
            Text(title)
                .font(.headline)
            
            Spacer()
            
            if isSelected {
                Circle()
                    .fill(Color.white.opacity(0.8))
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 20)
        .background(
            Group {
                if isSelected {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.ultraThinMaterial)
                        .padding(.horizontal, 10)
                }
            }
        )
        .foregroundColor(isSelected ? .primary : .primary.opacity(0.8))
    }
}

struct MainNavigator_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            MainNavigator()
                .frame(width: UIScreen.main.bounds.width * 0.6)
                .background(Color.blue.opacity(0.2))
        }
    }
}
