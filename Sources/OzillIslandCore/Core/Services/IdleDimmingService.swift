import Foundation
import SwiftUI
import Combine

/// Pengelola transparansi otomatis (auto-dimming) saat Ozill Island tidak disentuh selama > 15 menit.
/// Mencegah layar tertutup saat pengguna fokus bekerja, dan langsung kembali terlihat penuh saat didekati kursor atau ada event aktif.
@MainActor
public final class IdleDimmingService: ObservableObject {
    public static let shared = IdleDimmingService()
    
    /// Batas waktu idle sebelum menjadi transparan (default: 15 menit = 900 detik)
    public var idleTimeoutSeconds: TimeInterval = 15 * 60
    
    /// Nilai opasitas saat idle transparan (0.18 = sangat halus dan tembus pandang)
    public let dimmedOpacity: Double = 0.18
    
    @Published public private(set) var isDimmed: Bool = false
    @Published public private(set) var lastActivityDate: Date = Date()
    
    private var checkTimer: Timer?
    
    public init(timeoutSeconds: TimeInterval = 15 * 60) {
        self.idleTimeoutSeconds = timeoutSeconds
        startIdleTimer()
    }
    
    deinit {
        checkTimer?.invalidate()
    }
    
    public func startIdleTimer() {
        checkTimer?.invalidate()
        checkTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.evaluateIdleState()
            }
        }
    }
    
    /// Mencatat aktivitas interaksi pengguna (hover mouse, klik, kontrol lagu, shalat)
    public func recordActivity() {
        self.lastActivityDate = Date()
        if isDimmed {
            withAnimation(.easeInOut(duration: 0.35)) {
                self.isDimmed = false
            }
        }
    }
    
    /// Evaluasi kondisi idle untuk menentukan apakah opasitas harus diturunkan
    public func evaluateIdleState(
        simulatedDate: Date? = nil,
        checkUpcomingPrayer: Bool = true,
        checkMediaPlaying: Bool = true
    ) {
        // 1. Jangan pernah transparan jika ada adzan berkumandang atau musik sedang aktif berputar
        if AdhanAudioManager.shared.isPlaying || (checkMediaPlaying && UniversalMusicManager.shared.playbackState.isPlaying) {
            recordActivity()
            return
        }
        
        // 2. Jangan pernah transparan jika panel sedang dibuka (Expanded atau Settings)
        if PrayerIslandViewModel.shared.state != .collapsed {
            recordActivity()
            return
        }
        
        // 3. Jangan transparan jika waktu shalat tersisa <= 15 menit (Upcoming Event)
        if checkUpcomingPrayer {
            let remaining = PrayerScheduler.shared.nextPrayerTime.timeIntervalSince(Date())
            if remaining > 0 && remaining <= 900 {
                recordActivity()
                return
            }
        }
        
        let now = simulatedDate ?? Date()
        let elapsed = now.timeIntervalSince(lastActivityDate)
        
        if elapsed >= idleTimeoutSeconds {
            if !isDimmed {
                withAnimation(.easeInOut(duration: 0.8)) {
                    self.isDimmed = true
                }
            }
        } else {
            if isDimmed {
                withAnimation(.easeInOut(duration: 0.35)) {
                    self.isDimmed = false
                }
            }
        }
    }
    
    public var currentOpacity: Double {
        return isDimmed ? dimmedOpacity : 1.0
    }
}
