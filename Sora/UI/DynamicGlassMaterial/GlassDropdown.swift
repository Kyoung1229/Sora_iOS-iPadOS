import SwiftUI

// ──────────────────────────────────────────────────────────
// GlassDropdown.swift
// ──────────────────────────────────────────────────────────
struct GlassDropdown: View {
    @StateObject var gyro: GyroManager
    @Binding var selectedOption: String     // ← 바인딩
    @State private var dynamicHeight: CGFloat = 80
    
    let options: [String]
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    
    // 최대 4개 셀까지 보임
    private var maxVisibleHeight: CGFloat {
        height * CGFloat(min(options.count, 4))
    }
    
    @State private var isExpanded = false
    private var springAnim: Animation {
        .spring(response: 0.4, dampingFraction: 0.9)
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Glass 배경 + ScrollView
            GlassRectangle(
                gyro: gyro,
                cornerRadius: cornerRadius,
                width: width,
                height: dynamicHeight
            )
            .opacity(isExpanded ? 1 : 1)
            .animation(springAnim, value: isExpanded)
            .overlay {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 0) {
                            
                            
                            ForEach(options.indices, id: \.self) { idx in
                                let option = options[idx]
                                Button {
                                    selectedOption = option
                                    isExpanded = false
                                    // 선택값 업데이트
                                } label: {
                                    HStack {
                                        Text(option)
                                            .foregroundColor(Color("CloudyTextColor").opacity(isExpanded ? 1 : 1))
                                        Spacer()
                                    }
                                    .padding(.horizontal, 12)
                                    .frame(height: height)
                                }
                                .id(option)
                                Divider()
                                    .frame(width: isExpanded ? width * 0.9 : 0)
                                    .animation(.smooth(duration: 0.7), value: isExpanded)
                            }
                        }
                    }
                    .background(Color.clear)
                    .scrollDisabled(!isExpanded)
                    .onChange(of: selectedOption) { _ in
                        // 선택이 바뀌면 접힌 상태로
                        isExpanded = false
                    }
                    .onChange(of: isExpanded) { expanded in
                        withAnimation(springAnim) {
                            dynamicHeight = isExpanded ? maxVisibleHeight : height
                        }
                        if expanded {
                            DispatchQueue.main.async {
                                
                            }
                        } else {
                            // 축소된 직후에도 선택된 셀이 보이도록
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0) {
                                withAnimation(.bouncy) {
                                    proxy.scrollTo(selectedOption, anchor: .top)
                                }
                            }
                        }
                    }
                    .onAppear {
                        dynamicHeight = isExpanded ? maxVisibleHeight : height
                        DispatchQueue.main.async {
                            withAnimation(springAnim) {
                                proxy.scrollTo(selectedOption, anchor: .top)
                            }
                        }
                    }
                }
                .frame(width: width, height: dynamicHeight, alignment: .center)
                .clipped()
            }
            .animation(springAnim, value: dynamicHeight)
            
            // 화살표
            Image(systemName: "chevron.down")
                .rotationEffect(.degrees(isExpanded ? 180 : 0))
                .foregroundColor(.white.opacity(0.7))
                .padding(.top).padding(.trailing, 12)
                .animation(springAnim, value: isExpanded)
                .shadow(color: .black.opacity(isExpanded ? 0.6 : 0.2), radius: 2, y: 3)
            
            // 탭 제스처
            Rectangle()
                .fill(Color.clear)
                .frame(width: width, height: height)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(springAnim) {
                        isExpanded.toggle()
                    }
                }
                .allowsHitTesting(isExpanded ? false : true)
        }
    }
}


// ──────────────────────────────────────────────────────────
// ContentView.swift
// ──────────────────────────────────────────────────────────
struct ContentView: View {
    @State private var selected = "옵션 1"   // 초기값
    @StateObject private var gyro = GyroManager()
    
    var body: some View {
        VStack(spacing: 20) {
            GlassDropdown(gyro: gyro,
                selectedOption: $selected,
                options: (1...10).map { "옵션 \($0)" },
                width: 260,
                height: 44,
                cornerRadius: 14
            )
            
            // 선택된 값을 화면에 출력
            Text("선택된 항목: \(selected)")
                .foregroundColor(.white)
                .font(.headline)
        }
        .padding()
        .background(
            ZStack {
                LinearGradient(
                    colors: [.black, .blue.opacity(0.3)],
                    startPoint: .top, endPoint: .bottom
                )
                GlassRectangle(gyro: gyro, cornerRadius: 20, width: 1000, height: 1000, lightingIntensity_surface: 0.5)
            }
            .ignoresSafeArea()
        )
    }
}


// ──────────────────────────────────────────────────────────
// Preview
// ──────────────────────────────────────────────────────────
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            
            .previewLayout(.sizeThatFits)
    }
}
