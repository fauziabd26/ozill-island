import Foundation
import SwiftUI

/// Representasi universal sebuah notifikasi yang masuk ke Ozill Island (Jalur A, B, atau C).
public struct IslandNotification: Identifiable, Equatable, Hashable, Sendable {
    public let id: UUID
    public let appName: String
    public let title: String
    public let message: String
    public let iconSymbol: String
    public let accentHex: String
    public let timestamp: Date
    public let duration: TimeInterval
    
    public init(
        id: UUID = UUID(),
        appName: String,
        title: String,
        message: String,
        iconSymbol: String = "bell.fill",
        accentHex: String = "#00D2FF",
        timestamp: Date = Date(),
        duration: TimeInterval = 4.5
    ) {
        self.id = id
        self.appName = appName
        self.title = title
        self.message = message
        self.iconSymbol = iconSymbol
        self.accentHex = accentHex
        self.timestamp = timestamp
        self.duration = duration
    }
    
    public var accentColor: Color {
        Color(hex: accentHex) ?? .blue
    }
}
