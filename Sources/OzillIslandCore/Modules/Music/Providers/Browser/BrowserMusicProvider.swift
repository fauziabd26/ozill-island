import Foundation

/// Provider agregator universal untuk seluruh media browser (YouTube, YouTube Music, dsb).
public final class BrowserMusicProvider: MusicProvider, @unchecked Sendable {
    public let identifier: String = "org.ozill.provider.browser"
    public let displayName: String = "Browser Media (YouTube)"
    
    private let lock = NSLock()
    private var adapters: [BrowserAdapter]
    private var activeSessions: [BrowserMediaSession] = []
    private var selectedSessionId: String?
    
    public var isAvailable: Bool {
        lock.withLock {
            adapters.contains { $0.isBrowserRunning }
        }
    }
    
    public var capabilities: MusicProviderCapabilities {
        lock.withLock {
            guard let active = currentActiveSession() else {
                return [.playPause]
            }
            if let adapter = adapters.first(where: { $0.browserBundleIdentifier == active.browserBundleId }) {
                return adapter.supportedCapabilities
            }
            return [.playPause]
        }
    }
    
    public init(adapters: [BrowserAdapter]? = nil) {
        self.adapters = adapters ?? [
            ChromeMusicAdapter(),
            SafariMusicAdapter(),
            EdgeMusicAdapter(),
            FirefoxMusicAdapter()
        ]
    }
    
    /// Mengambil seluruh sesi media yang terdeteksi di seluruh browser
    public func fetchAllSessions() async -> [BrowserMediaSession] {
        var all: [BrowserMediaSession] = []
        for adapter in adapters where adapter.isBrowserRunning {
            let found = await adapter.detectMediaSessions()
            all.append(contentsOf: found)
        }
        
        lock.withLock {
            self.activeSessions = all
            // Jika sesi yang dipilih sebelumnya sudah tidak ada, reset seleksi
            if let selected = self.selectedSessionId, !all.contains(where: { $0.id == selected }) {
                self.selectedSessionId = nil
            }
        }
        return all
    }
    
    public func fetchSnapshot() async -> NowPlayingItem? {
        let all = await fetchAllSessions()
        guard !all.isEmpty else { return nil }
        
        return lock.withLock { () -> NowPlayingItem? in
            guard let active = currentActiveSession() else { return nil }
            return active.nowPlaying
        }
    }
    
    public func fetchPlaybackState() async -> PlaybackState {
        let _ = await fetchSnapshot()
        return lock.withLock {
            guard let active = currentActiveSession() else { return .stopped }
            return active.isPlaying ? .playing : .paused
        }
    }
    
    public func playPause() async throws {
        let (session, adapter) = try resolveActiveTarget()
        try await adapter.playPause(sessionId: session.id)
    }
    
    public func next() async throws {
        let (session, adapter) = try resolveActiveTarget()
        try await adapter.next(sessionId: session.id)
    }
    
    public func previous() async throws {
        let (session, adapter) = try resolveActiveTarget()
        try await adapter.previous(sessionId: session.id)
    }
    
    public func seek(to seconds: TimeInterval) async throws {
        let (session, adapter) = try resolveActiveTarget()
        try await adapter.seek(to: seconds, sessionId: session.id)
    }
    
    // MARK: - Session Selection
    
    public func selectSession(id: String) {
        lock.withLock {
            if activeSessions.contains(where: { $0.id == id }) {
                self.selectedSessionId = id
            }
        }
    }
    
    public func getDetectedSessions() -> [BrowserMediaSession] {
        lock.withLock { activeSessions }
    }
    
    // MARK: - Internal Helpers
    
    private func currentActiveSession() -> BrowserMediaSession? {
        // 1. Jika pengguna secara manual memilih tab sesi tertentu, hormati seleksi manual
        if let selected = selectedSessionId,
           let match = activeSessions.first(where: { $0.id == selected }) {
            return match
        }
        // 2. Prioritas otomatis: Cari tab yang sedang .isPlaying
        if let playing = activeSessions.first(where: { $0.isPlaying }) {
            return playing
        }
        // 3. Fallback: sesi pertama yang tersedia
        return activeSessions.first
    }
    
    private func resolveActiveTarget() throws -> (BrowserMediaSession, BrowserAdapter) {
        return try lock.withLock {
            guard let active = currentActiveSession() else {
                throw MusicProviderError.providerUnavailable("Tidak ada tab media aktif di browser.")
            }
            guard let adapter = adapters.first(where: { $0.browserBundleIdentifier == active.browserBundleId }) else {
                throw MusicProviderError.providerUnavailable("Adapter untuk browser \(active.browserName) tidak ditemukan.")
            }
            return (active, adapter)
        }
    }
}
