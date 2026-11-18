import SwiftUI

public struct IslandColorPalette: Equatable {
    public let background: Color
    public let cardBackground: Color
    public let primaryText: Color
    public let secondaryText: Color
    public let border: Color
    public let hoverBorder: Color
    public let shadowColor: Color
    public let isDark: Bool
    
    public static let midnight = IslandColorPalette(
        background: Color(red: 0.05, green: 0.05, blue: 0.07).opacity(0.95),
        cardBackground: Color.white.opacity(0.06),
        primaryText: Color.white,
        secondaryText: Color.white.opacity(0.65),
        border: Color.white.opacity(0.14),
        hoverBorder: Color.white.opacity(0.35),
        shadowColor: Color.black.opacity(0.55),
        isDark: true
    )
    
    public static let pearl = IslandColorPalette(
        background: Color(red: 0.95, green: 0.96, blue: 0.98).opacity(0.96),
        cardBackground: Color.black.opacity(0.05),
        primaryText: Color(red: 0.10, green: 0.12, blue: 0.15),
        secondaryText: Color(red: 0.35, green: 0.38, blue: 0.44),
        border: Color.black.opacity(0.12),
        hoverBorder: Color.black.opacity(0.32),
        shadowColor: Color.black.opacity(0.20),
        isDark: false
    )
    
    public static let emerald = IslandColorPalette(
        background: Color(red: 0.03, green: 0.10, blue: 0.07).opacity(0.96),
        cardBackground: Color(red: 0.06, green: 0.18, blue: 0.12).opacity(0.7),
        primaryText: Color.white,
        secondaryText: Color(red: 0.72, green: 0.92, blue: 0.82),
        border: Color(red: 0.20, green: 0.65, blue: 0.42).opacity(0.38),
        hoverBorder: Color(red: 0.32, green: 0.88, blue: 0.58).opacity(0.65),
        shadowColor: Color(red: 0.01, green: 0.06, blue: 0.03).opacity(0.6),
        isDark: true
    )
    
    public static let aurora = IslandColorPalette(
        background: Color(red: 0.07, green: 0.05, blue: 0.14).opacity(0.96),
        cardBackground: Color(red: 0.16, green: 0.10, blue: 0.30).opacity(0.55),
        primaryText: Color.white,
        secondaryText: Color(red: 0.85, green: 0.80, blue: 0.96),
        border: Color(red: 0.68, green: 0.35, blue: 0.98).opacity(0.38),
        hoverBorder: Color(red: 0.88, green: 0.48, blue: 1.0).opacity(0.65),
        shadowColor: Color(red: 0.10, green: 0.02, blue: 0.22).opacity(0.65),
        isDark: true
    )
}

public extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        let length = hexSanitized.count
        if length == 6 {
            self.init(
                red: Double((rgb & 0xFF0000) >> 16) / 255.0,
                green: Double((rgb & 0x00FF00) >> 8) / 255.0,
                blue: Double(rgb & 0x0000FF) / 255.0
            )
        } else {
            return nil
        }
    }
}
