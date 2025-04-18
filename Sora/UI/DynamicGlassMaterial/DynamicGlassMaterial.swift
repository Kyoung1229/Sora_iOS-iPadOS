import SwiftUI
import UIKit

struct GlassMaterialUtilities {
    func getxdeg(gyro: GyroManager, orientation: UIInterfaceOrientation) -> CGFloat {
        var xdeg: CGFloat
        switch orientation {
        case .portrait:
            xdeg = gyro.x
        case .portraitUpsideDown:
            xdeg = -gyro.x
        case .landscapeLeft:
            xdeg = -gyro.y
        case .landscapeRight:
            xdeg = gyro.y
        default:
            xdeg = gyro.x
        }
        return xdeg
    }
    func getydeg(gyro: GyroManager, orientation: UIInterfaceOrientation) -> CGFloat {
        var ydeg: CGFloat
        switch orientation {
        case .portrait:
            ydeg = gyro.y
        case .portraitUpsideDown:
            ydeg = -gyro.y
        case .landscapeLeft:
            ydeg = gyro.x
        case .landscapeRight:
            ydeg = -gyro.x
        default:
            ydeg = gyro.y
        }
        return ydeg
    }
    func overlayColor(forHour hour: Double, colorScheme: ColorScheme) -> Color {
        // 12시(정오)를 기준으로 시간 차이를 계산합니다.
        let diff = abs(hour - 12)
        
        // 시간 차이를 이용하여 선형 가중치를 만듭니다.
        // 목표: 6시와 18시에는 최대(1.0), 0시, 12시, 24시에는 최소(0.0)가 되도록 함
        // 수식: weight = 1 - (|diff - 6| / 6)
        let linearWeight = 1 - abs(diff - 6) / 6
        // 다크 모드에서는 따뜻한 색상이 약간 더 강조되도록 bias를 추가합니다.
        let bias: Double
        if colorScheme == .dark {
            bias = 0.3
        } else {
            bias = -0.1
        }
        let warmWeight = min(max(linearWeight + bias, 0), 1)
        
        // 따뜻한 색상 (오렌지 계열)과 차가운 색상 (블루 계열)을 정의합니다.
        let warmRed: Double = 0.5, warmGreen: Double = 0.25, warmBlue: Double = 0.0
        let coolRed: Double = 0.0, coolGreen: Double = 0, coolBlue: Double = 0.5
        
        // 선형 보간 함수를 이용해 각 색상 성분을 계산합니다.
        func interpolate(_ a: Double, _ b: Double, weight: Double) -> Double {
            return a * weight + b * (1 - weight)
        }
        
        let red   = interpolate(warmRed,   coolRed,   weight: warmWeight)
        let green = interpolate(warmGreen, coolGreen, weight: warmWeight)
        let blue  = interpolate(warmBlue,  coolBlue,  weight: warmWeight)
        
        // 오버레이 효과를 위해 미리 정해진 alpha(예, 0.3)를 적용합니다.
        return Color(red: red, green: green, blue: blue).opacity(0.04)
    }
}

struct GlassRectangle: View {
    enum EdgeMode {
        case fixed, dynamic, automatic
    }
     @State private var interfaceOrientation: UIInterfaceOrientation = .unknown
    @ObservedObject var gyro: GyroManager
    @Environment(\.colorScheme) private var colorScheme
    var cornerRadius: CGFloat
    var width: CGFloat
    var height: CGFloat
    var edgeMode: EdgeMode = .automatic
    var lightingIntensity_edge: CGFloat = 1.0
    var lightingIntensity_surface: CGFloat = 1.0
    var movementIntensity: CGFloat = 1.0
    var xoffset: CGFloat = 0
    var yoffset: CGFloat = 0
    var currentHour: Double = Double(Calendar.current.component(.hour, from: Date())) + Double(Calendar.current.component(.minute, from: Date())) / 60.0
    
    @State private var edgeLight: CGFloat = 0
    @State private var edgeBlend: CGFloat = 0
    @State private var edgeLightingConstant_x: CGFloat = 0
    @State private var edgeLightingConstant_y: CGFloat = 0
    @State private var surfaceLightingConstant: CGFloat = 0
    @State private var surfaceLightingRadius: CGFloat = 0
    @State private var length_constant: CGFloat = 0
    @State private var shadowDistance: CGFloat = 0
    
    static private let lightColor = Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(Color(red: 0.5, green: 0.5, blue: 0.5)) : UIColor(Color(red: 1, green: 1, blue: 1)) })
    var body: some View {
        var xdeg: CGFloat = GlassMaterialUtilities().getxdeg(gyro: gyro, orientation: interfaceOrientation)
        var ydeg: CGFloat = GlassMaterialUtilities().getydeg(gyro: gyro, orientation: interfaceOrientation)
        let shadowConstant = width / 25 * movementIntensity
        
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .foregroundStyle(.ultraThinMaterial.opacity(0.985))
                .frame(width: width, height: height)
                .shadow(color: .black.opacity(0.3), radius: edgeBlend * 8, x: 2 * edgeLightingConstant_x, y:  2 * edgeLightingConstant_y)
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.black.opacity(0.1).gradient.shadow(.inner(color: .white.opacity(edgeLight), radius: edgeBlend, x: -edgeLightingConstant_x, y: -edgeLightingConstant_y)))
                .frame(width: width, height: height)
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(GlassRectangle.lightColor.opacity(0.1).gradient.shadow(.inner(color: .black.opacity(1 * lightingIntensity_edge), radius: edgeBlend, x: edgeLightingConstant_x, y: edgeLightingConstant_y)))
                .frame(width: width, height: height)
            RoundedRectangle(cornerRadius: cornerRadius)
                .foregroundStyle(
                    RadialGradient(
                        gradient: Gradient(colors: [colorScheme == .dark ? GlassRectangle.lightColor.opacity(surfaceLightingConstant) : GlassRectangle.lightColor.opacity(surfaceLightingConstant * 2), GlassRectangle.lightColor.opacity(0)]),
                        center: UnitPoint(x: -xdeg / 2 + 0.5 + xoffset, y: -ydeg / 2 + 0.5 - yoffset),
                        startRadius: 10, endRadius: surfaceLightingRadius * 1.2
                      )
                )
                .frame(width: width, height: height)
                .overlay(
                    GlassMaterialUtilities().overlayColor(forHour: currentHour, colorScheme: colorScheme)
                        .blendMode(.screen)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius)))
        }
        .onChange(of: width) {
            length_constant = width / 2 + height / 2
            switch edgeMode {
            case .fixed:
                surfaceLightingConstant = width / 1500 * lightingIntensity_surface
                surfaceLightingRadius = width * 0.6
            case .dynamic:
                withAnimation {
                    edgeLight = 5 * lightingIntensity_edge
                    edgeBlend = lightingIntensity_edge
                    surfaceLightingConstant = width / 1500 * lightingIntensity_surface
                    surfaceLightingRadius = width * 0.6
                }
            case .automatic:
                withAnimation {
                    edgeLight = (pow(1 / 4, length_constant / 100) + 2) * 2.5 * lightingIntensity_edge
                    edgeBlend = (pow(length_constant, 0.5) + 2) / 24 * lightingIntensity_edge
                    surfaceLightingConstant = (pow(length_constant, 0.5) + 2) / 90 * lightingIntensity_surface
                    surfaceLightingRadius = length_constant * 0.6
                    shadowDistance = (pow(height, 0.5)) / 2
                }
            default:
                edgeLight = 6
                edgeBlend = 1
                edgeLightingConstant_x = xdeg
                edgeLightingConstant_y = ydeg
            }
        }
        .onChange(of: xdeg) {
            switch edgeMode {
            case .fixed:
                edgeLightingConstant_x = xdeg
                edgeLightingConstant_y = ydeg
            case .dynamic:
                edgeLightingConstant_x = xdeg * width / 100 * movementIntensity - xoffset
                edgeLightingConstant_y = ydeg * width / 100 * movementIntensity + yoffset
            case .automatic:
                edgeLightingConstant_x = xdeg * (pow(width, 0.5) + 2) / 20 * movementIntensity - xoffset
                edgeLightingConstant_y = ydeg * (pow(width, 0.5) + 2) / 20 * movementIntensity + yoffset
            default:
                edgeLightingConstant_x = xdeg
                edgeLightingConstant_y = ydeg
            }
        }
        .onAppear {
            length_constant = width / 2 + height / 2
            updateInterfaceOrientation()
            switch edgeMode {
            case .fixed:
                edgeLight = 6
                edgeBlend = 1
                edgeLightingConstant_x = xdeg
                edgeLightingConstant_y = ydeg
                surfaceLightingConstant = width / 1500 * lightingIntensity_surface
                surfaceLightingRadius = width * 0.6
            case .dynamic:
                edgeLight = 5 * lightingIntensity_edge
                edgeBlend = lightingIntensity_edge
                edgeLightingConstant_x = xdeg * width / 100 * movementIntensity - xoffset
                edgeLightingConstant_y = ydeg * width / 100 * movementIntensity + yoffset
                surfaceLightingConstant = width / 1500 * lightingIntensity_surface
                surfaceLightingRadius = width * 0.6
            case .automatic:
                edgeLightingConstant_x = xdeg * (pow(length_constant, 0.5) + 2) / 15 * movementIntensity - xoffset
                edgeLight = (pow(1 / 4, length_constant / 100) + 2) * 2.5 * lightingIntensity_edge
                edgeBlend = (pow(length_constant, 0.5) + 2) / 24 * lightingIntensity_edge
                surfaceLightingConstant = (pow(length_constant, 0.5) + 2) / 80 * lightingIntensity_surface
                surfaceLightingRadius = length_constant * 0.6
                shadowDistance = (pow(height, 0.5)) / 2
            default:
                edgeLight = 6
                edgeBlend = 1
                edgeLightingConstant_x = xdeg
                edgeLightingConstant_y = ydeg
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            updateInterfaceOrientation()
        }
    }
    private func updateInterfaceOrientation() {
        if let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first {
            interfaceOrientation = windowScene.interfaceOrientation
        }
    }
}

struct GlassAmimationTest: View {
    @StateObject private var gyro = GyroManager()
    @State private var width = 200.0
    @State private var height = 123.6
    @State private var cornerRadius = 30.0
    @State private var isExtended = false
    @State private var smallCardOffset = 0.0
    @State private var smallCardElememtOpacity = 1.0
    @State private var hour: Double = 12.0
    var body: some View {
        ZStack {
            Image("대충배경2")
                .resizable()
                .scaledToFill()
            VStack {
                ZStack {
                    GlassRectangle(gyro: gyro, cornerRadius: cornerRadius, width: width, height: height, edgeMode: .automatic, currentHour: hour)
                    ZStack(alignment: .top) {
                        VStack(alignment: .leading) {
                            Text("hi.")
                                .frame(alignment: .top)
                                .padding()
                            Divider()
                                .frame(width: width - 10)
                            Text("Example Content \n asdf")
                                .frame(alignment: .leading)
                                .padding()
                        }
                        .frame(alignment: .top)
                    }
                    .frame(alignment: .top)
                    ZStack {
                        RoundedRectangle(cornerRadius: 30)
                            .foregroundStyle(.ultraThinMaterial.opacity(smallCardElememtOpacity))
                            .frame(width: width, height: height)
                        Text("Tap to Expand")
                            .foregroundStyle(.primary.opacity(smallCardElememtOpacity))
                    }
                    .onTapGesture {
                        if !isExtended {
                            isExtended.toggle()
                        }
                    }
                    .scaleEffect(isExtended ? 1 : 1)
                    .animation(isExtended ? .bouncy : .bouncy(duration: 0.7), value: isExtended)
                }
                Divider()
                    .padding(.top, 30)
                ZStack {
                    GlassRectangle(gyro: gyro, cornerRadius: 25, width: 325, height: 85, edgeMode: .automatic, currentHour: hour)
                    VStack {
                        Toggle("Toggle Extension", isOn: $isExtended)
                            .frame(width: 300)
                        HStack {
                           Text("Hour")
                            Slider(value: $hour, in: 0...24)
                                .frame(width: 250)
                        }
                        .frame(width: 300)
                    }
                    .frame(width: 320, height: 80)
                }
            }
            .onChange(of: isExtended) {
                withAnimation(isExtended ? .bouncy : .bouncy(duration: 0.7)) {
                    if isExtended == true {
                        width = 500
                        height = 300
                        cornerRadius = 50
                        smallCardElememtOpacity = 0
                    } else {
                        width = 200
                        height = 123.6
                        cornerRadius = 30
                        smallCardElememtOpacity  = 1
                    }
                }

            }
        }
    }
}



struct GlassEx: View {
    @StateObject private var gyro = GyroManager()
    @State private var yoffasd = 0.0
    @State private var xoffasd = 0.0
    @State private var movementIntensity = 1.0
    @State private var lightingIntensity = 1.0
    var body: some View {
        ZStack {
            Color(.black)
            Image("") //Image Asset
                .resizable()
                .scaledToFill()
            VStack {
                GlassRectangle(gyro: gyro, cornerRadius: 149, width: 300, height: 500,edgeMode: .automatic, lightingIntensity_edge: lightingIntensity, lightingIntensity_surface: lightingIntensity, movementIntensity: movementIntensity, xoffset: xoffasd, yoffset: yoffasd)
                
                ZStack {
                    GlassRectangle(gyro: gyro, cornerRadius: 14.9, width: 80, height: 30,edgeMode: .automatic, lightingIntensity_edge: 1.2)
                    Text("X Offset")
                        .fontWeight(.light)
                }
                Slider(value: $xoffasd, in: -1.0...1.0)
                    .frame(width: 200)
                ZStack {
                    GlassRectangle(gyro: gyro, cornerRadius: 14.9, width: 80, height: 30,edgeMode: .automatic, lightingIntensity_edge: 1.2)
                    Text("Y Offset")
                        .fontWeight(.light)
                }
                Slider(value: $yoffasd, in: -1.0...1.0)
                    .frame(width: 200)
                ZStack {
                    GlassRectangle(gyro: gyro, cornerRadius: 14.9, width: 160, height: 30,edgeMode: .automatic, lightingIntensity_edge: 1.2)
                    Text("Movement Intensity")
                        .fontWeight(.light)
                }
                Slider(value: $movementIntensity, in: -0.0...2.0)
                    .frame(width: 200)
                ZStack {
                    GlassRectangle(gyro: gyro, cornerRadius: 14.9, width: 150, height: 30,edgeMode: .automatic, lightingIntensity_edge: 1.2)
                    Text("Lighting Intensity")
                        .fontWeight(.light)
                }
                Slider(value: $lightingIntensity, in: -0.0...2.0)
                    .frame(width: 200)
            
            }
        }
    }
}

struct GlassRectangle_Previews: PreviewProvider {
    static var previews: some View {
        GlassAmimationTest()
    }
}
 
