import Foundation

/// Sekumpulan kemampuan teknis yang didukung oleh sebuah modul.
public struct ModuleCapability: OptionSet, Sendable, Hashable {
    public let rawValue: Int
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    public static let collapsedPill = ModuleCapability(rawValue: 1 << 0)
    public static let expandedSheet = ModuleCapability(rawValue: 1 << 1)
    public static let settingsSheet = ModuleCapability(rawValue: 1 << 2)
    public static let audioOutput   = ModuleCapability(rawValue: 1 << 3)
    public static let backgroundTick = ModuleCapability(rawValue: 1 << 4)
    public static let mediaControl  = ModuleCapability(rawValue: 1 << 5)
}

/// Kontrak universal untuk seluruh modul di dalam ekosistem OzillIsland.
@MainActor
public protocol IslandModule: AnyObject {
    /// Pengenal unik modul (reverse-DNS style, misal: "org.ozill.prayer", "org.ozill.music").
    var identifier: String { get }
    
    /// Nama ramah pengguna modul untuk UI dan pengaturan.
    var displayName: String { get }
    
    /// Prioritas modul yang dapat berubah dinamis sesuai event runtime.
    var currentPriority: ModulePriority { get }
    
    /// Apakah modul sedang aktif, memiliki data, dan siap ditampilkan.
    var isAvailable: Bool { get }
    
    /// Daftar kapabilitas teknis yang didukung modul.
    var capabilities: ModuleCapability { get }
    
    /// Mode Island yang direpresentasikan oleh modul ini.
    var associatedMode: IslandMode { get }
    
    /// Siklus hidup saat modul diaktifkan oleh router.
    func activate() async
    
    /// Siklus hidup saat modul dinonaktifkan oleh router.
    func deactivate() async
}
