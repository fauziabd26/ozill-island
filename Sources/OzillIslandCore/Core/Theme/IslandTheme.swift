import SwiftUI

public enum IslandThemePreset: String, CaseIterable, Identifiable, Codable {
    case midnight = "Midnight"
    case pearl = "Pearl"
    case emerald = "Emerald"
    case aurora = "Aurora"
    case system = "System"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .midnight: return "Midnight"
        case .pearl: return "Pearl"
        case .emerald: return "Emerald"
        case .aurora: return "Aurora"
        case .system: return "System"
        }
    }
    
    public var subtitle: String {
        switch self {
        case .midnight: return "Dark premium bernuansa obsidian"
        case .pearl: return "Light clean bernuansa frosted glass"
        case .emerald: return "Hijau zamrud elegan & tenang"
        case .aurora: return "Gradien ungu kosmik futuristik"
        case .system: return "Mengikuti tampilan macOS otomatis"
        }
    }
    
    public var iconName: String {
        switch self {
        case .midnight: return "moon.stars.fill"
        case .pearl: return "sun.max.fill"
        case .emerald: return "leaf.fill"
        case .aurora: return "sparkles"
        case .system: return "circle.righthalf.filled"
        }
    }
}

public enum IslandAccentColor: String, CaseIterable, Identifiable, Codable {
    case orange = "Orange"
    case green = "Green"
    case blue = "Blue"
    case purple = "Purple"
    case pink = "Pink"
    case red = "Red"
    case custom = "Custom"
    
    public static var emeraldGreen: IslandAccentColor { .green }
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .orange: return "Oranye (Default)"
        case .green: return "Hijau Zamrud"
        case .blue: return "Biru Samudera"
        case .purple: return "Ungu Kosmik"
        case .pink: return "Merah Muda"
        case .red: return "Merah Menyala"
        case .custom: return "Warna Kustom"
        }
    }
    
    public var color: Color {
        switch self {
        case .orange: return .orange
        case .green: return Color(red: 0.20, green: 0.78, blue: 0.35)
        case .blue: return Color(red: 0.0, green: 0.48, blue: 1.0)
        case .purple: return Color(red: 0.69, green: 0.32, blue: 0.87)
        case .pink: return Color(red: 1.0, green: 0.18, blue: 0.33)
        case .red: return Color(red: 1.0, green: 0.23, blue: 0.19)
        case .custom: return Color(red: 0.0, green: 0.82, blue: 0.95)
        }
    }
    
    public func color(customHex: String) -> Color {
        if self == .custom {
            return Color(hex: customHex) ?? Color(red: 0.0, green: 0.82, blue: 0.95)
        }
        return self.color
    }
}
