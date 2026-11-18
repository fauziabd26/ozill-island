import Foundation
import SwiftUI
import AppKit

/// Layanan timer Pomodoro dan Focus Session terpusat.
@MainActor
public final class TimerService: ObservableObject {
    public static let shared = TimerService()
    
    @Published public private(set) var state: TimerRunState = .idle
    @Published public private(set) var currentPreset: TimerPreset = .focus
    @Published public private(set) var totalDuration: TimeInterval = 25 * 60
    @Published public private(set) var remainingSeconds: TimeInterval = 25 * 60
    
    private var internalTimer: Timer?
    private var completionAlertTimer: Timer?
    
    public init() {
        self.totalDuration = TimerPreset.focus.durationSeconds
        self.remainingSeconds = TimerPreset.focus.durationSeconds
    }
    
    deinit {
        internalTimer?.invalidate()
        completionAlertTimer?.invalidate()
    }
    
    public var progress: Double {
        guard totalDuration > 0 else { return 0 }
        let elapsed = totalDuration - remainingSeconds
        return max(0.0, min(1.0, elapsed / totalDuration))
    }
    
    public var formattedRemainingTime: String {
        let totalSecs = Int(ceil(remainingSeconds))
        let minutes = totalSecs / 60
        let seconds = totalSecs % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    public func selectPreset(_ preset: TimerPreset) {
        pause()
        self.currentPreset = preset
        self.totalDuration = preset.durationSeconds
        self.remainingSeconds = preset.durationSeconds
        self.state = .idle
    }
    
    public func start() {
        if state == .completed {
            remainingSeconds = totalDuration
        }
        state = .running
        startTimerLoop()
    }
    
    public func pause() {
        guard state == .running else { return }
        state = .paused
        internalTimer?.invalidate()
        internalTimer = nil
    }
    
    public func resume() {
        guard state == .paused else { return }
        state = .running
        startTimerLoop()
    }
    
    public func togglePlayPause() {
        switch state {
        case .idle, .completed:
            start()
        case .running:
            pause()
        case .paused:
            resume()
        }
    }
    
    public func reset() {
        internalTimer?.invalidate()
        internalTimer = nil
        completionAlertTimer?.invalidate()
        completionAlertTimer = nil
        remainingSeconds = totalDuration
        state = .idle
    }
    
    private func startTimerLoop() {
        internalTimer?.invalidate()
        internalTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                guard self.state == .running else { return }
                
                if self.remainingSeconds > 1 {
                    self.remainingSeconds -= 1
                } else {
                    self.remainingSeconds = 0
                    self.timerDidComplete()
                }
            }
        }
    }
    
    private func timerDidComplete() {
        internalTimer?.invalidate()
        internalTimer = nil
        state = .completed
        NSSound.beep()
        
        NotificationIslandService.shared.postNotification(
            IslandNotification(
                appName: "Focus Timer",
                title: "Waktu Fokus Selesai! 🎉",
                message: "Sesi \(currentPreset.rawValue) telah berakhir. Istirahat sejenak ☕",
                iconSymbol: "timer",
                accentHex: "#FF9500",
                duration: 6.0
            )
        )
        
        // Auto-dismiss alert after 10 seconds jika tidak di-reset
        completionAlertTimer?.invalidate()
        completionAlertTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                if self?.state == .completed {
                    self?.reset()
                }
            }
        }
    }
}
