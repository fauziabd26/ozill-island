import Foundation
import SwiftUI
import Combine

/// Layanan terpusat untuk membaca dan mengontrol output volume sistem macOS secara non-blocking.
/// Menggunakan `AudioController.shared` sebagai satu-satunya Single Source of Truth (SSOT).
@MainActor
public final class SystemVolumeService: ObservableObject {
    public static let shared = SystemVolumeService()
    
    private let controller: AudioController
    private var cancellables = Set<AnyCancellable>()
    
    @Published public private(set) var volume: Double = 0.5
    @Published public private(set) var isMuted: Bool = false
    
    public convenience init() {
        self.init(controller: AudioController.shared)
    }
    
    public init(controller: AudioController) {
        self.controller = controller
        self.volume = Double(controller.volume)
        self.isMuted = controller.isMuted
        
        // Sinkronisasi dua arah non-blocking dengan AudioController (Single Source of Truth)
        controller.$volume
            .receive(on: RunLoop.main)
            .sink { [weak self] newVol in
                self?.volume = Double(newVol)
            }
            .store(in: &cancellables)
            
        controller.$isMuted
            .receive(on: RunLoop.main)
            .sink { [weak self] newMuted in
                self?.isMuted = newMuted
            }
            .store(in: &cancellables)
    }
    
    /// Mengambil status volume dan mute saat ini dari macOS
    public func refreshVolumeStatus() async {
        await controller.refreshVolumeStatus()
    }
    
    /// Mengatur tingkat volume output (0.0 ... 1.0) dengan clamping
    public func setVolume(_ newVolume: Double) {
        controller.setVolume(Float(newVolume))
        self.volume = Double(controller.volume)
        self.isMuted = controller.isMuted
    }
    
    /// Beralih antara bisu (mute) dan bunyi
    public func toggleMute() {
        controller.toggleMute()
        self.isMuted = controller.isMuted
    }
}
