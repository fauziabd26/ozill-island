import Foundation
import AppKit

/// Informasi sesi media aktif yang terdeteksi di dalam tab browser.
public struct BrowserMediaSession: Equatable, Hashable, Sendable {
    public let id: String
    public let browserBundleId: String
    public let browserName: String
    public let tabTitle: String
    public let urlString: String
    public let nowPlaying: NowPlayingItem
    public let isPlaying: Bool
    public let isYouTube: Bool
    public let isYouTubeMusic: Bool
    
    public init(
        id: String,
        browserBundleId: String,
        browserName: String,
        tabTitle: String,
        urlString: String,
        nowPlaying: NowPlayingItem,
        isPlaying: Bool,
        isYouTube: Bool,
        isYouTubeMusic: Bool
    ) {
        self.id = id
        self.browserBundleId = browserBundleId
        self.browserName = browserName
        self.tabTitle = tabTitle
        self.urlString = urlString
        self.nowPlaying = nowPlaying
        self.isPlaying = isPlaying
        self.isYouTube = isYouTube
        self.isYouTubeMusic = isYouTubeMusic
    }
}

/// Kontrak adapter spesifik per browser untuk mendeteksi dan mengontrol media web.
public protocol BrowserAdapter: AnyObject, Sendable {
    var browserBundleIdentifier: String { get }
    var browserDisplayName: String { get }
    var supportedCapabilities: MusicProviderCapabilities { get }
    
    /// Mengecek apakah proses browser sedang berjalan di macOS
    var isBrowserRunning: Bool { get }
    
    /// Mendeteksi seluruh tab yang sedang memutar atau memuat media (YouTube / YouTube Music)
    func detectMediaSessions() async -> [BrowserMediaSession]
    
    /// Kontrol Play / Pause pada tab tertentu
    func playPause(sessionId: String) async throws
    
    /// Kontrol Next track pada tab tertentu
    func next(sessionId: String) async throws
    
    /// Kontrol Previous track pada tab tertentu
    func previous(sessionId: String) async throws
    
    /// Kontrol Seek posisi waktu pada tab tertentu
    func seek(to seconds: TimeInterval, sessionId: String) async throws
}

public extension BrowserAdapter {
    var isBrowserRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: browserBundleIdentifier).isEmpty
    }
}

public enum BrowserMediaHelper {
    public static func extractYouTubeThumbnail(from urlString: String) -> String? {
        let patterns = [
            #"[?&]v=([a-zA-Z0-9_-]{11})"#,
            #"youtu\.be/([a-zA-Z0-9_-]{11})"#,
            #"youtube\.com/shorts/([a-zA-Z0-9_-]{11})"#,
            #"youtube\.com/embed/([a-zA-Z0-9_-]{11})"#
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: urlString, range: NSRange(urlString.startIndex..., in: urlString)),
               let range = Range(match.range(at: 1), in: urlString) {
                let videoId = String(urlString[range])
                return "https://i.ytimg.com/vi/\(videoId)/mqdefault.jpg"
            }
        }
        return nil
    }
}
