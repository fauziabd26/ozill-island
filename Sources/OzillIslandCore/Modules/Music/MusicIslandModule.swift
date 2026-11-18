import Foundation

/// Modul pemutar musik yang mengadopsi kontrak universal `IslandModule`.
@MainActor
public final class MusicIslandModule: IslandModule {
    public static let shared = MusicIslandModule()
    
    public let identifier: String = "org.ozill.music"
    public let displayName: String = "Pemutar Musik"
    public let associatedMode: IslandMode = .music
    
    public var provider: (any MusicProvider)?
    public var playbackState: PlaybackState = .stopped {
        didSet {
            if playbackState.isPlaying {
                lastPlayedTimestamp = Date()
            }
        }
    }
    private var lastPlayedTimestamp: Date?
    
    public var capabilities: ModuleCapability {
        [.collapsedPill, .expandedSheet, .mediaControl]
    }
    
    public init(provider: (any MusicProvider)? = nil) {
        self.provider = provider
    }
    
    public var isAvailable: Bool {
        return provider != nil
    }
    
    public var currentPriority: ModulePriority {
        if playbackState.isPlaying {
            return .activeMedia
        }
        // Jika baru di-pause dalam 30 detik terakhir, pertahankan prioritas (50) di atas standby (40)
        // agar Island musik tidak langsung lenyap saat pengguna berpindah tab atau jeda lagu!
        if let last = lastPlayedTimestamp, Date().timeIntervalSince(last) < 30.0, playbackState == .paused {
            return ModulePriority(50)
        }
        return .background
    }
    
    /// Sinkronisasi status playback dari provider aktif
    public func updatePlaybackState() async {
        if let prov = provider {
            self.playbackState = await prov.fetchPlaybackState()
        } else {
            self.playbackState = .stopped
        }
    }
    
    public func activate() async {}
    public func deactivate() async {}
}
