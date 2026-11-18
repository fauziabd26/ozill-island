import Foundation

/// Modul pemutar musik yang mengadopsi kontrak universal `IslandModule`.
@MainActor
public final class MusicIslandModule: IslandModule {
    public static let shared = MusicIslandModule()
    
    public let identifier: String = "org.ozill.music"
    public let displayName: String = "Pemutar Musik"
    public let associatedMode: IslandMode = .music
    
    public var provider: (any MusicProvider)?
    public var playbackState: PlaybackState = .stopped
    
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
