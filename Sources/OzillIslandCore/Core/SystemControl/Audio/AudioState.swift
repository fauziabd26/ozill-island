import Foundation

/// Model state independen yang merepresentasikan status audio output sistem macOS.
public struct AudioState: Equatable, Sendable {
    public var volume: Float
    public var isMuted: Bool
    public var isAvailable: Bool
    
    public init(volume: Float = 0.5, isMuted: Bool = false, isAvailable: Bool = true) {
        self.volume = max(0.0, min(1.0, volume))
        self.isMuted = isMuted
        self.isAvailable = isAvailable
    }
}
