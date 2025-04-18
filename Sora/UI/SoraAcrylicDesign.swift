import SwiftUI

// MARK: - BlurView (UIKit의 UIVisualEffectView 활용)
struct BlurView: UIViewRepresentable {
    let style: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}

// MARK: - SoraAcrylicStyle
/// 소라 앱에서 사용할 아크릴 스타일 정의
enum SoraAcrylicStyle {
    case light       // 밝은 반투명 아크릴
    case dark        // 어두운 반투명 아크릴
    case accent      // 앱 강조색 베이스 아크릴
    case vibrant     // 더 강한 색상과 대비를 가진 아크릴
    case subtle      // 미묘한 효과의 아크릴
    case custom(tint: Color, opacity: Double, intensity: Double) // 사용자 정의 아크릴
    
    // 스타일에 따른 기본 투명도
    var baseOpacity: Double {
        switch self {
        case .light: return 0.2
        case .dark: return 0.25
        case .accent: return 0.3
        case .vibrant: return 0.4
        case .subtle: return 0.15
        case .custom(_, let opacity, _): return opacity
        }
    }
    
    // 스타일에 따른 틴트 색상
    var tintColor: Color {
        switch self {
        case .light: return .white
        case .dark: return .black
        case .accent: return .accentColor
        case .vibrant: return .accentColor.opacity(0.7)
        case .subtle: return .gray.opacity(0.3)
        case .custom(let tint, _, _): return tint
        }
    }
    
    // 스타일에 따른 블러 스타일
    var blurStyle: UIBlurEffect.Style {
        switch self {
        case .light: return .systemUltraThinMaterial
        case .dark: return .systemMaterial
        case .accent, .vibrant: return .systemThinMaterial
        case .subtle: return .systemUltraThinMaterial
        case .custom(_, _, let intensity):
            // 강도에 따라 블러 스타일 결정
            if intensity > 0.7 {
                return .systemMaterial
            } else if intensity > 0.4 {
                return .systemThinMaterial
            } else {
                return .systemUltraThinMaterial
            }
        }
    }
    
    // 스타일에 따른 하이라이트 색상
    var highlightColor: Color {
        switch self {
        case .light: return .white
        case .dark: return .white.opacity(0.3)
        case .accent: return .white.opacity(0.5)
        case .vibrant: return .white.opacity(0.7)
        case .subtle: return .white.opacity(0.2)
        case .custom(let tint, _, _): return tint.opacity(0.5)
        }
    }
    
    // 스타일에 따른 테두리 색상
    var borderGradient: Gradient {
        switch self {
        case .light:
            return Gradient(colors: [.white.opacity(0.6), .white.opacity(0.2)])
        case .dark:
            return Gradient(colors: [.white.opacity(0.3), .white.opacity(0.1)])
        case .accent:
            return Gradient(colors: [.accentColor.opacity(0.6), .accentColor.opacity(0.2)])
        case .vibrant:
            return Gradient(colors: [.white.opacity(0.8), .accentColor.opacity(0.3)])
        case .subtle:
            return Gradient(colors: [.white.opacity(0.1), .white.opacity(0.05)])
        case .custom(let tint, _, _):
            return Gradient(colors: [tint.opacity(0.6), tint.opacity(0.1)])
        }
    }
}

// MARK: - AcrylicHighlight
/// 상단/좌측에 밝은 빛 번짐(볼륨감 강조) + 전체적 반사
struct AcrylicHighlight: View {
    var cornerRadius: CGFloat
    var style: SoraAcrylicStyle
    
    init(cornerRadius: CGFloat, style: SoraAcrylicStyle = .light) {
        self.cornerRadius = cornerRadius
        self.style = style
    }
    
    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            
            RadialGradient(
                gradient: Gradient(colors: [
                    style.highlightColor.opacity(0.7),
                    style.highlightColor.opacity(0.4),
                ]),
                center: .topLeading,
                startRadius: 0,
                endRadius: size.width * 1.2
            )
            .blur(radius: 10)
            .blendMode(.screen)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

// MARK: - NoiseOverlay
/// 노이즈 텍스처로 실제 재질감(얼룩, 입자)을 표현
struct NoiseOverlay: View {
    var cornerRadius: CGFloat
    var opacity: Double
    
    init(cornerRadius: CGFloat, opacity: Double = 0.05) {
        self.cornerRadius = cornerRadius
        self.opacity = opacity
    }
    
    var body: some View {
        GeometryReader { geo in
            // "noiseTexture"는 Assets에 추가해둔 노이즈 이미지
            Image("noiseTexture")
                .resizable()
                .scaledToFill()
                .frame(width: geo.size.width, height: geo.size.height)
                .opacity(opacity)
                .blendMode(.overlay)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
    }
}

// MARK: - SoraAcrylicShapeStyle
/// ShapeStyle 프로토콜을 준수하는 아크릴 스타일 구현으로 .fill() 메서드에 직접 사용 가능
struct SoraAcrylicShapeStyle: ShapeStyle {
    var style: SoraAcrylicStyle
    var cornerRadius: CGFloat = 20
    
    @Environment(\.colorScheme) private var colorScheme
    
    func _apply(to shape: inout _ShapeStyle_Shape, rect: CGRect) {
        let material = AnyShapeStyle(Material.regularMaterial)
        material._apply(to: &shape)
    }
}

extension ShapeStyle where Self == SoraAcrylicShapeStyle {
    static func soraAcrylic(style: SoraAcrylicStyle = .light, cornerRadius: CGFloat = 20) -> SoraAcrylicShapeStyle {
        SoraAcrylicShapeStyle(style: style, cornerRadius: cornerRadius)
    }
}

extension SoraAcrylicStyle: Equatable {}


// MARK: - SoraAcrylicBackgroundModifier
/// 소라 앱의 아크릴 배경 수정자
struct SoraAcrylicBackgroundModifier: ViewModifier {
    var style: SoraAcrylicStyle
    var cornerRadius: CGFloat
    var shadowRadius: CGFloat
    var padding: CGFloat?
    var animation: Animation?
    
    @Environment(\.colorScheme) private var colorScheme
    
    init(
        style: SoraAcrylicStyle = .light,
        cornerRadius: CGFloat = 20,
        shadowRadius: CGFloat = 10,
        padding: CGFloat? = nil,
        animation: Animation? = nil
    ) {
        self.style = style
        self.cornerRadius = cornerRadius
        self.shadowRadius = shadowRadius
        self.padding = padding
        self.animation = animation
    }
    
    func body(content: Content) -> some View {
        content
        .padding(padding ?? 0)
            .background(
                ZStack {
                    // 기본 블러 레이어
                    BlurView(style: style.blurStyle)
                    
                    // 색상 오버레이
                    style.tintColor
                        .opacity(style.baseOpacity)
                        .blendMode(.plusLighter)
                    
                    // 노이즈 텍스처 (선택적으로 애니메이션 적용)
                    NoiseOverlay(cornerRadius: cornerRadius)
                        .opacity(colorScheme == .dark ? 0.07 : 0.05)
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .overlay(
                    // 테두리 그라디언트
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            LinearGradient(
                                gradient: style.borderGradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
            )
            // 하이라이트 효과 (볼륨감)
            .overlay(
                AcrylicHighlight(cornerRadius: cornerRadius, style: style)
                    .allowsHitTesting(false)
            )
            // 그림자 효과
            .shadow(
                color: (colorScheme == .dark ? Color.black : style.tintColor).opacity(0.15),
                radius: shadowRadius,
                x: 0,
                y: shadowRadius * 0.3
            )
            // 애니메이션 적용 (있는 경우)
        .animation(animation, value: style)
    }
}

// MARK: - PressableAcrylicButtonStyle
/// 눌림 효과가 있는 아크릴 버튼 스타일
struct PressableAcrylicButtonStyle: ButtonStyle {
    var style: SoraAcrylicStyle
    var cornerRadius: CGFloat
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(
                Group {
                    if configuration.isPressed {
                        // 눌렸을 때 효과
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(.soraAcrylic(style: style, cornerRadius: cornerRadius))
                            .overlay(
                                RoundedRectangle(cornerRadius: cornerRadius)
                                    .fill(Color.black.opacity(0.1))
                            )
                            .scaleEffect(0.98)
                            .shadow(radius: 2)
                    } else {
                        // 기본 상태
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(.soraAcrylic(style: style, cornerRadius: cornerRadius))
                            .shadow(color: Color.black.opacity(0.1), radius: 5, y: 2)
                    }
                }
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - SoraAcrylicRectangleView
struct SoraAcrylicRectangleView: View {
    var style: SoraAcrylicStyle = .light
    var cornerRadius: CGFloat = 20
    var shadowRadius: CGFloat = 10
    var width: CGFloat = 200
    var height: CGFloat = 80

    var body: some View {
        ZStack {
            // 블러 배경
            BlurView(style: style.blurStyle)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))

            // 색상 오버레이
            style.tintColor
                .opacity(style.baseOpacity)
                .blendMode(.plusLighter)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))

            // 노이즈 텍스처
            NoiseOverlay(cornerRadius: cornerRadius)
                .opacity(style == .dark ? 0.07 : 0.05)

            // 하이라이트
            AcrylicHighlight(cornerRadius: cornerRadius, style: style)

            // 테두리
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(
                    LinearGradient(
                        gradient: style.borderGradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .frame(width: width, height: height)
        .shadow(
            color: (style == .dark ? Color.black : style.tintColor).opacity(0.15),
            radius: shadowRadius,
            x: 0,
            y: shadowRadius * 0.3
        )
    }
}


// MARK: - View 확장
extension View {
    /// 소라 아크릴 배경 효과 적용
    func soraAcrylicBackground(
        style: SoraAcrylicStyle = .light,
        cornerRadius: CGFloat = 20,
        shadowRadius: CGFloat = 10,
        padding: CGFloat? = nil,
        animation: Animation? = nil
    ) -> some View {
        self.modifier(
            SoraAcrylicBackgroundModifier(
                style: style,
                cornerRadius: cornerRadius,
                shadowRadius: shadowRadius,
                padding: padding,
                animation: animation
            )
        )
    }
    
    /// 눌림 효과가 있는 아크릴 버튼 스타일 적용
    func soraAcrylicButton(
        style: SoraAcrylicStyle = .accent,
        cornerRadius: CGFloat = 20
    ) -> some View {
        self.buttonStyle(PressableAcrylicButtonStyle(style: style, cornerRadius: cornerRadius))
    }
}

// MARK: - 프리뷰
struct SoraAcrylicDesign_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            // 배경 이미지 또는 그라디언트
            LinearGradient(
                gradient: Gradient(colors: [.blue.opacity(0.7), .purple.opacity(0.3)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    Group {
                        Text("기본 아크릴 효과")
                            .font(.title3.bold())
                            .padding()
                            .frame(maxWidth: .infinity)
                            .soraAcrylicBackground()
                        
                        Text("어두운 아크릴 효과")
                            .font(.title3.bold())
                            .padding()
                            .frame(maxWidth: .infinity)
                            .soraAcrylicBackground(style: .dark)
                        
                        Text("강조색 아크릴 효과")
                            .font(.title3.bold())
                            .padding()
                            .frame(maxWidth: .infinity)
                            .soraAcrylicBackground(style: .accent, cornerRadius: 15)
                        
                        Text("생동감 있는 아크릴 효과")
                            .font(.title3.bold())
                            .padding()
                            .frame(maxWidth: .infinity)
                            .soraAcrylicBackground(style: .vibrant, cornerRadius: 25)
                        
                        Text("미묘한 아크릴 효과")
                            .font(.title3.bold())
                            .padding()
                            .frame(maxWidth: .infinity)
                            .soraAcrylicBackground(style: .subtle)
                    }
                    
                    Group {
                        Text("사용자 정의 아크릴 효과")
                            .font(.title3.bold())
                            .padding()
                            .frame(maxWidth: .infinity)
                            .soraAcrylicBackground(
                                style: .custom(
                                    tint: .red,
                                    opacity: 0.25,
                                    intensity: 0.6
                                )
                            )
                        
                        // 둥근 모양의 아크릴 예시
                        Circle()
                            .frame(width: 120, height: 120)
                            .soraAcrylicBackground(
                                style: .accent,
                                cornerRadius: 60,
                                shadowRadius: 15
                            )
                            .overlay(
                                Image(systemName: "sparkles")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white)
                            )
                        
                        // 아크릴 버튼 예시
                        Button("아크릴 버튼") {}
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(width: 200)
                            .soraAcrylicButton()
                        
                        // 어두운 아크릴 버튼
                        Button("다크 아크릴 버튼") {}
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(width: 200)
                            .soraAcrylicButton(style: .dark)
                        
                        // 카드 레이아웃 예시
                        VStack(alignment: .leading, spacing: 10) {
                            Text("아크릴 카드 제목")
                                .font(.headline)
                            
                            Text("이것은 아크릴 디자인을 적용한 카드 예시입니다. 이렇게 구성 요소를 배치하면 깔끔한 레이아웃을 구성할 수 있습니다.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Spacer()
                                Button("자세히") {}
                                    .font(.caption)
                                    .padding(.vertical, 5)
                                    .padding(.horizontal, 10)
                                    .background(Capsule().fill(.ultraThinMaterial))
                            }
                        }
                        .padding()
                        .soraAcrylicBackground(
                            style: .subtle,
                            animation: .easeInOut
                        )
                    }
                }
                .padding()
            }
        }
    }
}
