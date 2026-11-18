import Foundation

/// Adapter / Wrapper yang mengintegrasikan Prayer Engine yang sudah production-locked
/// ke dalam arsitektur universal `IslandModule`.
/// 100% Zero-Touch terhadap algoritma kalkulasi hisab, scheduler, dan audio adzan.
@MainActor
public final class PrayerIslandModule: IslandModule {
    public static let shared = PrayerIslandModule()
    
    public let identifier: String = "org.ozill.prayer"
    public let displayName: String = "Jadwal Shalat"
    public let associatedMode: IslandMode = .prayer
    
    public var capabilities: ModuleCapability {
        [.collapsedPill, .expandedSheet, .settingsSheet, .audioOutput, .backgroundTick]
    }
    
    public var isAvailable: Bool {
        return PrayerScheduler.shared.schedule != nil
    }
    
    public var currentPriority: ModulePriority {
        // 1. Jika adzan sedang berkumandang -> Prioritas Kritis (100)
        if AdhanAudioManager.shared.isPlaying {
            return .critical
        }
        
        // 2. Jika waktu shalat tersisa <= 15 menit (900 detik) -> Prioritas Upcoming Event (60)
        let remaining = PrayerScheduler.shared.nextPrayerTime.timeIntervalSince(Date())
        if remaining > 0 && remaining <= 900 {
            return .upcomingEvent
        }
        
        // 3. Status reguler standby (40)
        return .standby
    }
    
    public func activate() async {
        // Lifecycle hook
    }
    
    public func deactivate() async {
        // Lifecycle hook
    }
}
