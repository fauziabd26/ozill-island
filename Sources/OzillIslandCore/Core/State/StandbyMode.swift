import Foundation

/// Konfigurasi tampilan default saat sistem berada dalam kondisi standby (tidak ada event berprioritas tinggi).
public enum StandbyMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case smart
    case clock
    case prayer
    case music
    case battery
    case calendar
    case minimal
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .smart: return "Smart Standby (Otomatis)"
        case .clock: return "Jam & Tanggal"
        case .prayer: return "Jadwal Shalat"
        case .music: return "Pemutar Musik"
        case .battery: return "Status Baterai"
        case .calendar: return "Kalender & Agenda"
        case .minimal: return "Minimalis Notch"
        }
    }
    
    public var description: String {
        switch self {
        case .smart: return "Menampilkan modul paling relevan berdasarkan konteks dan waktu secara otomatis"
        case .clock: return "Menampilkan jam digital dan kalender tanggal saat idle"
        case .prayer: return "Selalu memprioritaskan hitung mundur waktu shalat saat idle"
        case .music: return "Menampilkan media player terakhir saat idle"
        case .battery: return "Menampilkan persentase baterai dan status daya saat idle"
        case .calendar: return "Menampilkan agenda rapat berikutnya saat idle"
        case .minimal: return "Tampilan notch hitam ramping dan bersih saat idle"
        }
    }
}
