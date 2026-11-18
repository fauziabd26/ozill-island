import Foundation
import Combine

/// Engine penentu mode aktif dan modul terdepan yang berhak tampil di Ozill Island.
@MainActor
public final class IslandModeRouter: ObservableObject {
    public static let shared = IslandModeRouter()
    
    private let registry: ModuleRegistry
    private let settings: GeneralSettings
    
    @Published public private(set) var currentMode: IslandMode = .idle
    @Published public private(set) var activeModule: IslandModule?
    
    @MainActor
    public init() {
        self.registry = ModuleRegistry.shared
        self.settings = GeneralSettings.shared
    }
    
    @MainActor
    public init(
        registry: ModuleRegistry,
        settings: GeneralSettings
    ) {
        self.registry = registry
        self.settings = settings
    }
    
    /// Mengevaluasi seluruh modul terdaftar dan memperbarui mode aktif secara deterministik.
    @discardableResult
    public func updateRoute() async -> (IslandMode, IslandModule?) {
        let (resolvedMode, resolvedModule) = resolveActiveMode()
        
        // Anti-flapping: Jika modul dan mode tidak berubah, jangan memicu re-render atau siklus hidup berulang
        if resolvedMode == currentMode && resolvedModule?.identifier == activeModule?.identifier {
            return (resolvedMode, resolvedModule)
        }
        
        let oldModule = activeModule
        
        // Deactivate modul lama jika berbeda
        if let old = oldModule, old.identifier != resolvedModule?.identifier {
            await old.deactivate()
        }
        
        self.currentMode = resolvedMode
        self.activeModule = resolvedModule
        
        // Activate modul baru jika ada
        if let new = resolvedModule, new.identifier != oldModule?.identifier {
            await new.activate()
        }
        
        return (resolvedMode, resolvedModule)
    }
    
    /// Resolusi murni logika prioritas tanpa efek samping (Pure Resolution Engine).
    public func resolveActiveMode() -> (IslandMode, IslandModule?) {
        let sorted = registry.availableModulesSortedByPriority()
        
        // 1. Level 1: Critical Events (>= 100, misal: adzan audio berkumandang, timer selesai)
        if let critical = sorted.first(where: { $0.currentPriority >= .critical }) {
            return (critical.associatedMode, critical)
        }
        
        // 2. Level 2: Active Playback / Active Intensive Tasks (>= 80, misal: pemutar musik aktif)
        if let activeMedia = sorted.first(where: { $0.currentPriority >= .activeMedia }) {
            return (activeMedia.associatedMode, activeMedia)
        }
        
        // 3. Level 3: Upcoming Important Events (>= 60, misal: 15 menit menjelang shalat)
        if let upcoming = sorted.first(where: { $0.currentPriority >= .upcomingEvent }) {
            return (upcoming.associatedMode, upcoming)
        }
        
        // 4. Level 4: User-Configured Standby Mode
        switch settings.standbyMode {
        case .smart:
            // Pada Smart Mode, gunakan modul teratas yang tersedia, atau fallback ke idle
            if let bestAvailable = sorted.first {
                return (bestAvailable.associatedMode, bestAvailable)
            }
            return (.idle, nil)
            
        case .prayer:
            if let prayerMod = registry.module(for: "org.ozill.prayer"), prayerMod.isAvailable {
                return (prayerMod.associatedMode, prayerMod)
            }
            return (.prayer, nil)
            
        case .music:
            if let musicMod = registry.module(for: "org.ozill.music"), musicMod.isAvailable {
                return (musicMod.associatedMode, musicMod)
            }
            return (.music, nil)
            
        case .clock, .battery, .calendar, .minimal:
            return (.idle, nil)
        }
    }
}
