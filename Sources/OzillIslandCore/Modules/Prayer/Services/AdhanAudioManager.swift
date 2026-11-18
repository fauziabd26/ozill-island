import Foundation
import AVFoundation
import Combine

@MainActor
public final class AdhanAudioManager: NSObject, ObservableObject, AVAudioPlayerDelegate {
    public static let shared = AdhanAudioManager()
    
    private var player: AVAudioPlayer?
    @Published public var isPlaying: Bool = false
    @Published public var currentPrayerName: String = ""
    @Published public var errorMessage: String?
    
    public nonisolated static var sampleAudioURL: URL? {
        return Bundle.module.url(forResource: "AdhanSample", withExtension: "wav")
    }
    
    public override init() {
        super.init()
    }
    
    /// Memutar audio adzan (mencari Adhan.mp3 di bundle, atau fallback ke AdhanSample.wav)
    public func play(for prayer: PrayerName? = nil) {
        stop()
        
        let bundle = Bundle.module
        var soundURL: URL? = nil
        
        // Cek jika ada custom Adhan.mp3
        if let customUrl = bundle.url(forResource: "Adhan", withExtension: "mp3") {
            soundURL = customUrl
        } else if let sampleUrl = bundle.url(forResource: "AdhanSample", withExtension: "wav") {
            soundURL = sampleUrl
        } else if let mainUrl = Bundle.main.url(forResource: "Adhan", withExtension: "mp3") {
            soundURL = mainUrl
        } else if let mainSample = Bundle.main.url(forResource: "AdhanSample", withExtension: "wav") {
            soundURL = mainSample
        }
        
        guard let url = soundURL else {
            errorMessage = "File audio Adhan/Sample tidak ditemukan di bundle."
            print("AdhanAudioManager:", errorMessage ?? "")
            return
        }
        
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.prepareToPlay()
            player?.play()
            self.isPlaying = true
            self.currentPrayerName = prayer?.rawValue ?? "Shalat"
            self.errorMessage = nil
        } catch {
            self.errorMessage = "Gagal memutar audio: \(error.localizedDescription)"
            print("AdhanAudioManager error:", error)
        }
    }
    
    public func stop() {
        if player != nil {
            player?.stop()
            player = nil
        }
        isPlaying = false
        currentPrayerName = ""
    }
    
    // MARK: - AVAudioPlayerDelegate
    public nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.currentPrayerName = ""
        }
    }
}
