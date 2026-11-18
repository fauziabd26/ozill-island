import Foundation
import SwiftUI

/// Modul Focus / Pomodoro Timer untuk Ozill Island Hub.
@MainActor
public final class TimerIslandModule: IslandModule {
    public static let shared = TimerIslandModule()
    
    public let identifier: String = "org.ozill.timer"
    public let displayName: String = "Focus Timer"
    public let capabilities: ModuleCapability = [.collapsedPill, .expandedSheet, .audioOutput]
    public let associatedMode: IslandMode = .idle
    
    private let timerService: TimerService
    
    @MainActor
    public init() {
        self.timerService = .shared
    }
    
    @MainActor
    public init(timerService: TimerService) {
        self.timerService = timerService
    }
    
    public var isAvailable: Bool {
        return true
    }
    
    public var currentPriority: ModulePriority {
        switch timerService.state {
        case .completed:
            return .critical
        case .running:
            return .activeMedia
        case .paused:
            return .upcomingEvent
        case .idle:
            return .background
        }
    }
    
    public func activate() async {
        // Did activate
    }
    
    public func deactivate() async {
        // Did deactivate
    }
}
