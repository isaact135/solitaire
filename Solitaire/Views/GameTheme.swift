import SwiftUI

enum GameTheme {
    static let table = Color(hex: 0x174730)
    static let tableLight = Color(hex: 0x225B3D)
    static let tableForeground = Color(hex: 0xFBF6E9)
    static let surface = Color(hex: 0xFBF6E9)
    static let ink = Color(hex: 0x26211B)
    static let suitRed = Color(hex: 0xB3232F)
    static let accent = Color(hex: 0xC7A94F)
    static let cardBack = Color(hex: 0x5E1424)
    static let cardBackEdge = Color(hex: 0xEFE5CE)
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
