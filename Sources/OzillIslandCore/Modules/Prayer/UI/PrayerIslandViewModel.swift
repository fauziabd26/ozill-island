import Foundation
import SwiftUI
import Combine

@MainActor
public final class PrayerIslandViewModel: ObservableObject {
    public static let shared = PrayerIslandViewModel()
    
    @Published public var state: IslandState = .collapsed {
        didSet {
            IslandWindowController.shared.updateFrame(for: state, animated: true)
        }
    }
    @Published public var isHovered: Bool = false
    
    public let locationManager = LocationManager.shared
    public let scheduler = PrayerScheduler.shared
    public let settings = PrayerSettings.shared
    public let audioManager = AdhanAudioManager.shared
    
    public init() {}
    
    /// Transisi deterministik ke state expanded
    public func expand() {
        guard state != .expanded else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            state = .expanded
        }
    }
    
    /// Transisi deterministik ke state collapsed
    public func collapse() {
        guard state != .collapsed else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            state = .collapsed
        }
    }
    
    /// Buka halaman settings
    public func openSettings() {
        guard state != .settings else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            state = .settings
        }
    }
    
    /// Tutup settings dan kembali ke expanded sheet
    public func closeToExpanded() {
        guard state != .expanded else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            state = .expanded
        }
    }
    
    /// Toggle antara collapsed dan expanded secara aman
    public func toggle() {
        if state == .collapsed {
            expand()
        } else {
            collapse()
        }
    }
    
    /// Alias untuk kompatibilitas pemanggil yang ada
    public func toggleExpand() {
        toggle()
    }
}
