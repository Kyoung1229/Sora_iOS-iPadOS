import CoreMotion
import SwiftUI

func normalizedCoordinates(fromPitch pitch: Double, roll: Double, maxAngle: Double = 90.0) -> (x: Double, y: Double) {
    let pitchDegrees = pitch * 180 / .pi
    let rollDegrees = roll * 180 / .pi
    let normalizedX = max(min(rollDegrees / maxAngle, 1.0), -1.0)
    let normalizedY = max(min(pitchDegrees / maxAngle, 1.0), -1.0)
    return (normalizedX, normalizedY)
}

class GyroManager: ObservableObject {
    private let motionManager = CMMotionManager()
    
    @Published var x: Double = 0.0
    @Published var y: Double = 0.0
    
    init() {
        startUpdates()
    }
    
    private func startUpdates() {
        guard motionManager.isDeviceMotionAvailable else {
            print("Device Motion is Not Available.") //Test at real device.
            return
        }
        
        motionManager.deviceMotionUpdateInterval = 0.02
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self = self, let attitude = motion?.attitude else { return }
            let coords = normalizedCoordinates(fromPitch: attitude.pitch, roll: attitude.roll)
            self.x = coords.x
            self.y = coords.y
        }
    }
    
    deinit {
        motionManager.stopDeviceMotionUpdates()
    }
}
