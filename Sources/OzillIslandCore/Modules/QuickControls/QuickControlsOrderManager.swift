import SwiftUI
import UniformTypeIdentifiers

/// Jenis kartu kontrol yang tersedia pada panel Quick Controls.
public enum QuickControlCardType: String, CaseIterable, Identifiable, Codable, Sendable {
    case mediaAudio = "media_audio"
    case timer = "timer"
    case brightness = "brightness"
    case quickActions = "quick_actions"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .mediaAudio: return "Pemutar Media & Audio"
        case .timer: return "Focus & Pomodoro Timer"
        case .brightness: return "Kecerahan Layar"
        case .quickActions: return "Aksi Cepat & Utilitas"
        }
    }

    public var sfSymbol: String {
        switch self {
        case .mediaAudio: return "music.note"
        case .timer: return "timer"
        case .brightness: return "sun.max.fill"
        case .quickActions: return "square.grid.2x2.fill"
        }
    }
}

/// Pengelola urutan kartu Quick Controls dengan dukungan Drag & Drop dan persistensi UserDefaults.
@MainActor
public final class QuickControlsOrderManager: ObservableObject {
    public static let shared = QuickControlsOrderManager()

    private let kOrderKey = "OzillIsland_QuickControlsCardOrder_v1"

    @Published public var cardOrder: [QuickControlCardType] {
        didSet {
            saveOrder()
        }
    }

    public init() {
        if let data = UserDefaults.standard.data(forKey: kOrderKey),
           let saved = try? JSONDecoder().decode([QuickControlCardType].self, from: data),
           !saved.isEmpty {
            var merged = saved
            for card in QuickControlCardType.allCases where !merged.contains(card) {
                merged.append(card)
            }
            self.cardOrder = merged
        } else {
            self.cardOrder = QuickControlCardType.allCases
        }
    }

    public func moveItem(from sourceItem: QuickControlCardType, to destinationItem: QuickControlCardType) {
        guard let fromIndex = cardOrder.firstIndex(of: sourceItem),
              let toIndex = cardOrder.firstIndex(of: destinationItem),
              fromIndex != toIndex else { return }

        withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
            cardOrder.remove(at: fromIndex)
            cardOrder.insert(sourceItem, at: toIndex)
        }
    }

    public func resetToDefault() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
            self.cardOrder = QuickControlCardType.allCases
        }
    }

    public var isCustomized: Bool {
        cardOrder != QuickControlCardType.allCases
    }

    private func saveOrder() {
        if let encoded = try? JSONEncoder().encode(cardOrder) {
            UserDefaults.standard.set(encoded, forKey: kOrderKey)
        }
    }
}
