import Foundation
import SwiftUI
import Combine

public enum IslandState {
    case collapsed
    case expanded
    case settings
}

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
    
    public func toggleExpand() {
        withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) {
            if state == .collapsed {
                state = .expanded
            } else {
                state = .collapsed
            }
        }
    }
    
    public func openSettings() {
        withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) {
            state = .settings
        }
    }
    
    public func closeToExpanded() {
        withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) {
            state = .expanded
        }
    }
    
    public func collapse() {
        withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) {
            state = .collapsed
        }
    }
}
