import Foundation
import Combine

/// Pengelola orkestrasi pemutar media multi-provider (Apple Music, Spotify, YouTube Browser).
@MainActor
public final class UniversalMusicManager: ObservableObject {
    public static let shared = UniversalMusicManager()
    
    @Published public private(set) var currentItem: NowPlayingItem?
    @Published public private(set) var playbackState: PlaybackState = .stopped
    @Published public private(set) var activeProvider: (any MusicProvider)?
    @Published public private(set) var detectedSessionsCount: Int = 0
    
    public let browserProvider = BrowserMusicProvider()
    public let spotifyProvider = SpotifyProvider()
    public let appleMusicProvider = AppleMusicProvider()
    public var mockProvider: MockMusicProvider?
    
    private var pollTimer: Timer?
    private var manualSelectedProviderId: String?
    
    public init() {
        startPolling()
    }
    
    deinit {
        pollTimer?.invalidate()
    }
    
    public func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.pollActiveMedia()
            }
        }
    }
    
    public func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
    
    /// Polling berkala terhadap seluruh provider aktif untuk mendeteksi media playing secara instan
    public func pollActiveMedia() async {
        var providers: [any MusicProvider] = [
            browserProvider,
            spotifyProvider,
            appleMusicProvider
        ]
        if let mock = mockProvider {
            providers.insert(mock, at: 0)
        }
        
        var candidateProvider: (any MusicProvider)?
        var candidateItem: NowPlayingItem?
        var candidateState: PlaybackState = .stopped
        
        // 1. Cek apakah ada provider yang secara eksplisit dipilih pengguna
        if let manualId = manualSelectedProviderId,
           let manualMatch = providers.first(where: { $0.identifier == manualId && $0.isAvailable }) {
            let state = await manualMatch.fetchPlaybackState()
            if let snap = await manualMatch.fetchSnapshot() {
                candidateProvider = manualMatch
                candidateItem = snap
                candidateState = state
            }
        }
        
        // 2. Jika tidak ada seleksi manual atau tidak aktif, cari provider yang sedang .playing
        if candidateItem == nil {
            for prov in providers where prov.isAvailable {
                let state = await prov.fetchPlaybackState()
                if state.isPlaying, let snap = await prov.fetchSnapshot() {
                    candidateProvider = prov
                    candidateItem = snap
                    candidateState = state
                    break
                }
            }
        }
        
        // 3. Fallback: Provider yang sedang paused (punya track)
        if candidateItem == nil {
            for prov in providers where prov.isAvailable {
                if let snap = await prov.fetchSnapshot() {
                    let state = await prov.fetchPlaybackState()
                    candidateProvider = prov
                    candidateItem = snap
                    candidateState = state
                    break
                }
            }
        }
        
        self.activeProvider = candidateProvider
        self.currentItem = candidateItem
        self.playbackState = candidateState
        self.detectedSessionsCount = browserProvider.getDetectedSessions().count
        
        // Sinkronisasi ke modul MusicIslandModule agar router memperhitungkan prioritas
        MusicIslandModule.shared.provider = candidateProvider
        MusicIslandModule.shared.playbackState = candidateState
        
        // Picu evaluasi rute IslandModeRouter
        await IslandModeRouter.shared.updateRoute()
    }
    
    // MARK: - Playback Controls
    
    public func playPause() async {
        guard let prov = activeProvider else { return }
        do {
            try await prov.playPause()
            await pollActiveMedia()
        } catch {
            print("UniversalMusicManager: playPause error -", error)
        }
    }
    
    public func next() async {
        guard let prov = activeProvider else { return }
        do {
            try await prov.next()
            await pollActiveMedia()
        } catch {
            print("UniversalMusicManager: next error -", error)
        }
    }
    
    public func previous() async {
        guard let prov = activeProvider else { return }
        do {
            try await prov.previous()
            await pollActiveMedia()
        } catch {
            print("UniversalMusicManager: previous error -", error)
        }
    }
    
    public func seek(to seconds: TimeInterval) async {
        guard let prov = activeProvider else { return }
        if let browser = prov as? BrowserMusicProvider {
            try? await browser.seek(to: seconds)
        } else if let apple = prov as? AppleMusicProvider {
            try? await apple.seek(to: seconds)
        } else if let spotify = prov as? SpotifyProvider {
            try? await spotify.seek(to: seconds)
        }
        await pollActiveMedia()
    }
    
    public func selectProvider(id: String?) {
        self.manualSelectedProviderId = id
        Task {
            await pollActiveMedia()
        }
    }
}
