import SwiftUI

enum Theme {
    static let background = Color(red: 0.96, green: 0.95, blue: 0.93)
    static let surface = Color(red: 0.97, green: 0.98, blue: 0.97)
    static let primary = Color(red: 0.56, green: 0.66, blue: 0.51)
    static let primaryDark = Color(red: 0.48, green: 0.57, blue: 0.44)
    static let accent = Color(red: 0.79, green: 0.48, blue: 0.44)
    static let neutralText = Color(red: 0.42, green: 0.44, blue: 0.39)

    static func gradient() -> LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.56, green: 0.66, blue: 0.51),
                Color(red: 0.66, green: 0.71, blue: 0.61)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
