import Foundation

public enum TimerPreset: String, CaseIterable, Identifiable, Sendable {
    case focus = "Fokus"
    case shortBreak = "Istirahat Singkat"
    case longBreak = "Istirahat Panjang"
    
    public var id: String { rawValue }
    
    public var durationSeconds: TimeInterval {
        switch self {
        case .focus: return 25 * 60
        case .shortBreak: return 5 * 60
        case .longBreak: return 15 * 60
        }
    }
    
    public var shortLabel: String {
        switch self {
        case .focus: return "25m Fokus"
        case .shortBreak: return "5m Break"
        case .longBreak: return "15m Relax"
        }
    }
    
    public var sfSymbol: String {
        switch self {
        case .focus: return "brain.head.profile"
        case .shortBreak: return "cup.and.saucer.fill"
        case .longBreak: return "leaf.fill"
        }
    }
}

public enum TimerRunState: String, Sendable {
    case idle
    case running
    case paused
    case completed
}
