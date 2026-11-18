import SwiftUI
import Combine
import AppKit

@MainActor
public final class IslandThemeManager: ObservableObject {
    public static let shared = IslandThemeManager()
    
    // MARK: - Persistence Keys
    public static let themeDefaultsKey = "ozill_selected_theme_preset"
    public static let accentDefaultsKey = "ozill_selected_accent_color"
    public static let customHexDefaultsKey = "ozill_custom_accent_hex"
    
    @Published public var currentPreset: IslandThemePreset {
        didSet {
            UserDefaults.standard.set(currentPreset.rawValue, forKey: Self.themeDefaultsKey)
            updatePalette()
        }
    }
    
    @Published public var currentAccent: IslandAccentColor {
        didSet {
            UserDefaults.standard.set(currentAccent.rawValue, forKey: Self.accentDefaultsKey)
            updatePalette()
        }
    }
    
    @Published public var customAccentHex: String {
        didSet {
            UserDefaults.standard.set(customAccentHex, forKey: Self.customHexDefaultsKey)
            updatePalette()
        }
    }
    
    @Published public private(set) var palette: IslandColorPalette
    
    public var preset: IslandThemePreset {
        get { currentPreset }
        set { currentPreset = newValue }
    }
    
    public var accentColor: IslandAccentColor {
        get { currentAccent }
        set { currentAccent = newValue }
    }
    
    public var customHex: String {
        get { customAccentHex }
        set { customAccentHex = newValue }
    }
    
    public var effectiveAccentColor: Color {
        if currentAccent == .custom {
            return Color(hex: customAccentHex) ?? Color(red: 0.0, green: 0.82, blue: 0.95)
        }
        return currentAccent.color
    }
    
    public init() {
        let savedPresetStr = UserDefaults.standard.string(forKey: Self.themeDefaultsKey) ?? IslandThemePreset.midnight.rawValue
        let preset = IslandThemePreset(rawValue: savedPresetStr) ?? .midnight
        
        let savedAccentStr = UserDefaults.standard.string(forKey: Self.accentDefaultsKey) ?? IslandAccentColor.orange.rawValue
        let accent = IslandAccentColor(rawValue: savedAccentStr) ?? .orange
        
        let savedHex = UserDefaults.standard.string(forKey: Self.customHexDefaultsKey) ?? "#00D2FF"
        
        self.currentPreset = preset
        self.currentAccent = accent
        self.customAccentHex = savedHex
        self.palette = Self.resolvePalette(for: preset)
    }
    
    public func resetToDefault() {
        self.currentPreset = .midnight
        self.currentAccent = .orange
        self.customAccentHex = "#00D2FF"
        updatePalette()
    }
    
    public func updatePalette() {
        self.palette = Self.resolvePalette(for: currentPreset)
    }
    
    public static func resolvePalette(for preset: IslandThemePreset) -> IslandColorPalette {
        switch preset {
        case .midnight:
            return .midnight
        case .pearl:
            return .pearl
        case .emerald:
            return .emerald
        case .aurora:
            return .aurora
        case .system:
            let isDark = NSApp?.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark ? .midnight : .pearl
        }
    }
}
