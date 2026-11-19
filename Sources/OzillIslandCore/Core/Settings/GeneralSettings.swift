import Foundation
import Combine

/// Pengaturan umum OzillIsland (terpisah secara modular dari PrayerSettings).
@MainActor
public final class GeneralSettings: ObservableObject {
    public static let shared = GeneralSettings()
    
    public static let standbyModeKey = "ozill_standby_mode"
    public static let autoHideAfterSecondsKey = "ozill_auto_hide_seconds"
    public static let playSoundOnEventKey = "ozill_play_sound_on_event"
    public static let isLightningEnabledKey = "ozill_lightning_border_enabled"
    
    @Published public var standbyMode: StandbyMode {
        didSet {
            UserDefaults.standard.set(standbyMode.rawValue, forKey: Self.standbyModeKey)
        }
    }
    
    @Published public var autoHideAfterSeconds: Int {
        didSet {
            UserDefaults.standard.set(autoHideAfterSeconds, forKey: Self.autoHideAfterSecondsKey)
        }
    }
    
    @Published public var playSoundOnEvent: Bool {
        didSet {
            UserDefaults.standard.set(playSoundOnEvent, forKey: Self.playSoundOnEventKey)
        }
    }

    @Published public var isLightningEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isLightningEnabled, forKey: Self.isLightningEnabledKey)
        }
    }
    
    public init() {
        let savedStandby = UserDefaults.standard.string(forKey: Self.standbyModeKey)
            .flatMap { StandbyMode(rawValue: $0) } ?? .smart
        let savedAutoHide = UserDefaults.standard.integer(forKey: Self.autoHideAfterSecondsKey)
        let savedSound = UserDefaults.standard.object(forKey: Self.playSoundOnEventKey) as? Bool ?? true
        let savedLightning = UserDefaults.standard.object(forKey: Self.isLightningEnabledKey) as? Bool ?? true
        
        self.standbyMode = savedStandby
        self.autoHideAfterSeconds = savedAutoHide > 0 ? savedAutoHide : 0
        self.playSoundOnEvent = savedSound
        self.isLightningEnabled = savedLightning
    }
    
    /// Mengembalikan pengaturan umum ke baseline default pabrik.
    public func resetToDefaults() {
        self.standbyMode = .smart
        self.autoHideAfterSeconds = 0
        self.playSoundOnEvent = true
        self.isLightningEnabled = true
    }
}
