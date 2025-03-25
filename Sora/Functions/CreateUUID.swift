import Foundation

extension String {
    static func createUUID() -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String(
            (0..<32)
                .map { _ in letters.randomElement()! }
        )
    }
}


