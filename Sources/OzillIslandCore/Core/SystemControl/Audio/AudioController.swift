import Foundation
import SwiftUI
import Combine

/// Kontrak protokol untuk pengontrol audio output sistem macOS.
@MainActor
public protocol AudioControlling: AnyObject {
    var volume: Float { get }
    var isMuted: Bool { get }
    var isAvailable: Bool { get }
    var stepIncrement: Float { get set }

    func setVolume(_ value: Float)
    func increaseVolume()
    func decreaseVolume()
    func toggleMute()
    func refreshVolumeStatus() async
}

/// Pengontrol sistem audio macOS yang aman, non-blocking, dengan debounce
/// dan proteksi UI feedback loop untuk Touch Bar & Quick Controls.
@MainActor
public final class AudioController: ObservableObject, AudioControlling {
    public static let shared = AudioController()
    
    @Published public private(set) var volume: Float = 0.5
    @Published public private(set) var isMuted: Bool = false
    @Published public private(set) var isAvailable: Bool = true
    
    public var stepIncrement: Float = 0.05
    
    private var pendingDebounceTask: Task<Void, Never>?
    private var isUpdatingLocally: Bool = false
    
    public init(
        initialVolume: Float = 0.5,
        isMuted: Bool = false,
        isAvailable: Bool = true,
        stepIncrement: Float = 0.05
    ) {
        self.volume = max(0.0, min(1.0, initialVolume))
        self.isMuted = isMuted
        self.isAvailable = isAvailable
        self.stepIncrement = stepIncrement
        
        Task {
            await refreshVolumeStatus()
        }
    }
    
    /// Membaca volume dan mute status dari sistem macOS secara non-blocking
    public func refreshVolumeStatus() async {
        guard !isUpdatingLocally else { return }
        let script = "set v to output volume of (get volume settings)\nset m to output muted of (get volume settings)\nreturn (v as string) & \":::\" & (m as string)"
        let (success, output) = await ScriptBridge.executeAppleScript(script, timeout: 0.8)
        guard success, !output.isEmpty else {
            if !success && output.contains("execution error") {
                self.isAvailable = false
            }
            return
        }
        
        let parts = output.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: ":::")
        if parts.count >= 2 {
            if let volInt = Float(parts[0]) {
                self.volume = max(0.0, min(1.0, volInt / 100.0))
            }
            self.isMuted = parts[1].lowercased() == "true"
            self.isAvailable = true
        }
    }
    
    /// Mengatur tingkat volume output dengan clamping (0.0 ... 1.0) dan debouncing
    public func setVolume(_ value: Float) {
        let clamped = max(0.0, min(1.0, value))
        self.volume = clamped
        if isMuted && clamped > 0 {
            self.isMuted = false
        }
        
        isUpdatingLocally = true
        pendingDebounceTask?.cancel()
        pendingDebounceTask = Task {
            // Debounce 50ms untuk mencegah spam proses osascript saat slider digeser cepat
            try? await Task.sleep(nanoseconds: 50_000_000)
            guard !Task.isCancelled else { return }
            
            let intVal = Int((clamped * 100.0).rounded())
            let script = "set volume output volume \(intVal)"
            _ = await ScriptBridge.executeAppleScript(script, timeout: 0.8)
            
            // Tahan lock lokal sebentar agar pembaruan background tidak menimpa slider pengguna
            try? await Task.sleep(nanoseconds: 300_000_000)
            await MainActor.run {
                self.isUpdatingLocally = false
            }
        }
    }
    
    /// Meningkatkan volume sebesar stepIncrement (default 0.05)
    public func increaseVolume() {
        setVolume(volume + stepIncrement)
    }
    
    /// Menurunkan volume sebesar stepIncrement (default 0.05)
    public func decreaseVolume() {
        setVolume(volume - stepIncrement)
    }
    
    /// Mengaktifkan atau menonaktifkan mode mute
    public func toggleMute() {
        let newMuted = !isMuted
        self.isMuted = newMuted
        
        isUpdatingLocally = true
        pendingDebounceTask?.cancel()
        pendingDebounceTask = Task {
            let script = "set volume output muted \(newMuted ? "true" : "false")"
            _ = await ScriptBridge.executeAppleScript(script, timeout: 0.8)
            try? await Task.sleep(nanoseconds: 300_000_000)
            await MainActor.run {
                self.isUpdatingLocally = false
            }
        }
    }
}
