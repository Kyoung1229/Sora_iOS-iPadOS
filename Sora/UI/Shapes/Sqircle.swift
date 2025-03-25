import Foundation
import SwiftUI

func Sqircle(width: CGFloat, height: CGFloat, cornerRadius: CGFloat) -> some View {
    Rectangle()
        .fill(Color.red)
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
}
