import Foundation
import SwiftUI
import Combine

/// Layanan terpusat untuk membaca dan mengontrol output volume sistem macOS secara non-blocking.
@MainActor
public final class SystemVolumeService: ObservableObject {
    public static let shared = SystemVolumeService()
    
    @Published public private(set) var volume: Double = 0.5
    @Published public private(set) var isMuted: Bool = false
    
    private var pendingSetTask: Task<Void, Never>?
    private var isUpdatingLocally: Bool = false
    
    public init() {
        Task {
            await refreshVolumeStatus()
        }
    }
    
    /// Mengambil status volume dan mute saat ini dari macOS
    public func refreshVolumeStatus() async {
        guard !isUpdatingLocally else { return }
        let script = "set v to output volume of (get volume settings)\nset m to output muted of (get volume settings)\nreturn (v as string) & \":::\" & (m as string)"
        let (success, output) = await ScriptBridge.executeAppleScript(script, timeout: 0.8)
        guard success, !output.isEmpty else { return }
        
        let parts = output.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: ":::")
        if parts.count >= 2 {
            if let volInt = Double(parts[0]) {
                self.volume = max(0.0, min(1.0, volInt / 100.0))
            }
            self.isMuted = parts[1].lowercased() == "true"
        }
    }
    
    /// Mengatur tingkat volume output (0.0 ... 1.0)
    public func setVolume(_ newVolume: Double) {
        let clamped = max(0.0, min(1.0, newVolume))
        self.volume = clamped
        if isMuted && clamped > 0 {
            self.isMuted = false
        }
        
        isUpdatingLocally = true
        pendingSetTask?.cancel()
        pendingSetTask = Task {
            let intVal = Int(clamped * 100.0)
            let script = "set volume output volume \(intVal)"
            _ = await ScriptBridge.executeAppleScript(script, timeout: 0.8)
            try? await Task.sleep(nanoseconds: 500_000_000)
            await MainActor.run {
                self.isUpdatingLocally = false
            }
        }
    }
    
    /// Beralih antara bisu (mute) dan bunyi
    public func toggleMute() {
        let newMuted = !isMuted
        self.isMuted = newMuted
        
        isUpdatingLocally = true
        pendingSetTask?.cancel()
        pendingSetTask = Task {
            let script = "set volume output muted \(newMuted ? "true" : "false")"
            _ = await ScriptBridge.executeAppleScript(script, timeout: 0.8)
            try? await Task.sleep(nanoseconds: 500_000_000)
            await MainActor.run {
                self.isUpdatingLocally = false
            }
        }
    }
}
