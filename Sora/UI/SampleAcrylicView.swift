import SwiftUI

struct SampleAcrylicView: View {
    @State private var showSettings = false
    @State private var isDarkMode = false
    @State private var selectedTab = 0
    @State private var sliderValue: Double = 0.5
    @State private var toggleValue = false
    
    var body: some View {
        ZStack {
            // 배경 그라디언트
            LinearGradient(
                gradient: Gradient(colors: isDarkMode 
                                  ? [.black.opacity(0.8), .blue.opacity(0.3), .purple.opacity(0.2)] 
                                  : [.blue.opacity(0.3), .purple.opacity(0.2), .white.opacity(0.7)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 상단 헤더
                headerView
                
                // 컨텐츠 영역
                ScrollView {
                    VStack(spacing: 20) {
                        // 환영 메시지 카드
                        welcomeCard
                        
                        // 탭 선택 버튼
                        tabSelectorView
                        
                        // 탭 컨텐츠
                        Group {
                            if selectedTab == 0 {
                                stylesExampleView
                            } else if selectedTab == 1 {
                                componentsExampleView
                            } else {
                                settingsView
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                        .animation(.easeInOut, value: selectedTab)
                    }
                    .padding()
                }
                
                // 하단 작업 바
                bottomBar
            }
            .preferredColorScheme(isDarkMode ? .dark : .light)
        }
    }
    
    // 상단 헤더 뷰
    private var headerView: some View {
        HStack {
            Text("소라 아크릴 디자인")
                .font(.title.bold())
                .foregroundColor(isDarkMode ? .white : .black)
            
            Spacer()
            
            Button {
                isDarkMode.toggle()
            } label: {
                Image(systemName: isDarkMode ? "sun.max.fill" : "moon.fill")
                    .font(.title3)
                    .foregroundColor(isDarkMode ? .yellow : .indigo)
                    .padding(10)
                    .background(Circle().fill(.ultraThinMaterial))
            }
        }
        .padding()
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.8)
                .shadow(color: Color.black.opacity(0.15), radius: 5, y: 5)
        )
    }
    
    // 환영 카드 뷰
    private var welcomeCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "sparkles.tv.fill")
                    .font(.largeTitle)
                    .foregroundColor(.accentColor)
                
                Text("아크릴 디자인 시스템")
                    .font(.title2.bold())
            }
            
            Text("깊이감과 입체감이 있는 현대적인 아크릴 디자인 시스템입니다. 다양한 스타일과 컴포넌트를 탐색해보세요.")
                .font(.subheadline)
                .opacity(0.9)
            
            HStack {
                Image(systemName: "sparkle")
                    .foregroundColor(.yellow)
                Text("모든 요소는 다크 모드와 라이트 모드를 지원합니다.")
                    .font(.caption)
                    .opacity(0.8)
            }
            .padding(.top, 5)
        }
        .padding()
        .soraAcrylicBackground(
            style: isDarkMode ? .dark : .light,
            cornerRadius: 16,
            shadowRadius: 15
        )
    }
    
    // 탭 선택기 뷰
    private var tabSelectorView: some View {
        HStack(spacing: 0) {
            ForEach(["스타일", "컴포넌트", "설정"].indices, id: \.self) { index in
                Button {
                    withAnimation {
                        selectedTab = index
                    }
                } label: {
                    Text(["스타일", "컴포넌트", "설정"][index])
                        .font(.headline)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .foregroundColor(selectedTab == index ? .accentColor : .primary.opacity(0.7))
                        .background(
                            ZStack {
                                if selectedTab == index {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(.ultraThinMaterial)
                                        .shadow(color: Color.accentColor.opacity(0.3), radius: 5, y: 2)
                                }
                            }
                        )
                }
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }
    
    // 스타일 예시 뷰
    private var stylesExampleView: some View {
        VStack(spacing: 20) {
            Text("다양한 아크릴 스타일")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Group {
                Text("기본 라이트 스타일")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .soraAcrylicBackground(style: .light, cornerRadius: 12)
                
                Text("다크 스타일")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .soraAcrylicBackground(style: .dark, cornerRadius: 12)
                
                Text("강조색 스타일")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .soraAcrylicBackground(style: .accent, cornerRadius: 12)
                
                Text("생동감 있는 스타일")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .soraAcrylicBackground(style: .vibrant, cornerRadius: 12)
                
                Text("미묘한 효과 스타일")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .soraAcrylicBackground(style: .subtle, cornerRadius: 12)
                
                Text("사용자 정의 스타일 (레드)")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .soraAcrylicBackground(
                        style: .custom(tint: .red, opacity: 0.2, intensity: 0.5),
                        cornerRadius: 12
                    )
            }
        }
    }
    
    // 컴포넌트 예시 뷰
    private var componentsExampleView: some View {
        VStack(spacing: 25) {
            Text("아크릴 컴포넌트")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // 버튼 예시
            VStack(alignment: .leading, spacing: 12) {
                Text("버튼")
                    .font(.subheadline.bold())
                
                HStack(spacing: 15) {
                    Button("기본") {}
                        .soraAcrylicButton()
                    
                    Button("다크") {}
                        .soraAcrylicButton(style: .dark)
                    
                    Button("강조") {}
                        .soraAcrylicButton(style: .accent)
                }
                .frame(maxWidth: .infinity)
            }
            .padding()
            .soraAcrylicBackground(style: .subtle, cornerRadius: 12)
            
            // 카드 예시
            VStack(alignment: .leading, spacing: 12) {
                Text("카드")
                    .font(.subheadline.bold())
                
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.accentColor)
                        Text("정보 카드")
                            .font(.headline)
                    }
                    
                    Text("이 카드는 중요한 정보를 표시하는 데 사용될 수 있습니다. 간결하고 명확한 메시지를 제공하세요.")
                        .font(.subheadline)
                        .opacity(0.9)
                }
                .padding()
                .soraAcrylicBackground(style: .light, cornerRadius: 12)
            }
            .padding()
            .soraAcrylicBackground(style: .subtle, cornerRadius: 12)
            
            // 입력 요소 예시
            VStack(alignment: .leading, spacing: 12) {
                Text("입력 요소")
                    .font(.subheadline.bold())
                
                // 슬라이더
                VStack(alignment: .leading, spacing: 5) {
                    Text("슬라이더: \(Int(sliderValue * 100))%")
                        .font(.caption)
                    
                    Slider(value: $sliderValue)
                        .accentColor(.accentColor)
                }
                .padding()
                .soraAcrylicBackground(style: .light, cornerRadius: 8)
                
                // 토글
                Toggle("설정 활성화", isOn: $toggleValue)
                    .padding()
                    .soraAcrylicBackground(style: .light, cornerRadius: 8)
            }
            .padding()
            .soraAcrylicBackground(style: .subtle, cornerRadius: 12)
            
            // 아이콘 버튼 그리드
            VStack(alignment: .leading, spacing: 12) {
                Text("아이콘 그리드")
                    .font(.subheadline.bold())
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 15) {
                    ForEach(["heart.fill", "star.fill", "bell.fill", "gear", 
                            "person.fill", "lock.fill", "chart.bar.fill", "photo"], id: \.self) { iconName in
                        Button {
                            // 액션
                        } label: {
                            Image(systemName: iconName)
                                .font(.title2)
                                .foregroundColor(.primary)
                                .frame(width: 50, height: 50)
                                .soraAcrylicBackground(style: .subtle, cornerRadius: 12)
                        }
                    }
                }
            }
            .padding()
            .soraAcrylicBackground(style: .subtle, cornerRadius: 12)
        }
    }
    
    // 설정 뷰
    private var settingsView: some View {
        VStack(spacing: 20) {
            Text("설정")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // 설정 항목들
            Group {
                Toggle("다크 모드", isOn: $isDarkMode)
                    .padding()
                    .soraAcrylicBackground(style: .subtle, cornerRadius: 12)
                
                HStack {
                    Text("불투명도")
                    Spacer()
                    Slider(value: $sliderValue, in: 0...1)
                        .frame(width: 200)
                }
                .padding()
                .soraAcrylicBackground(style: .subtle, cornerRadius: 12)
                
                Button("앱 재시작") {
                    // 액션
                }
                .padding()
                .frame(maxWidth: .infinity)
                .soraAcrylicBackground(style: .accent, cornerRadius: 12)
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("정보")
                        .font(.headline)
                    
                    Group {
                        Text("소라 아크릴 디자인 시스템")
                        Text("버전: 1.0.0")
                        Text("© 2025 소라 앱")
                    }
                    .font(.caption)
                    .opacity(0.8)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .soraAcrylicBackground(style: .subtle, cornerRadius: 12)
            }
        }
    }
    
    // 하단 탐색 바
    private var bottomBar: some View {
        HStack(spacing: 0) {
            ForEach(["house.fill", "star.fill", "gear"].indices, id: \.self) { index in
                Button {
                    withAnimation {
                        selectedTab = index
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: ["house.fill", "star.fill", "gear"][index])
                            .font(.title3)
                        
                        Text(["홈", "즐겨찾기", "설정"][index])
                            .font(.caption)
                    }
                    .foregroundColor(selectedTab == index ? .accentColor : .primary.opacity(0.6))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
            }
        }
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.2), radius: 10, y: -5)
        )
    }
}

#Preview {
    SampleAcrylicView()
}