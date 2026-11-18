import Foundation
import SwiftUI

/// Modul Pusat Notifikasi untuk Ozill Island yang mengintegrasikan Jalur A, B, dan C.
@MainActor
public final class NotificationIslandModule: IslandModule {
    public static let shared = NotificationIslandModule()
    
    public let identifier: String = "org.ozill.notification"
    public let displayName: String = "Pusat Notifikasi"
    public let capabilities: ModuleCapability = [.collapsedPill, .expandedSheet, .audioOutput]
    public let associatedMode: IslandMode = .banner
    
    private let notifService: NotificationIslandService
    
    @MainActor
    public init() {
        self.notifService = .shared
    }
    
    @MainActor
    public init(notifService: NotificationIslandService) {
        self.notifService = notifService
    }
    
    public var isAvailable: Bool {
        return true
    }
    
    public var currentPriority: ModulePriority {
        if notifService.activeNotification != nil {
            return .critical
        }
        return .background
    }
    
    public func activate() async {}
    public func deactivate() async {}
}
