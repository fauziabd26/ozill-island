import Foundation

/// Mode penangkapan layar tangkapan (Screenshot) yang didukung.
public enum ScreenshotMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case fullScreen = "Full Screen"
    case selectedArea = "Area"
    case window = "Window"
    
    public var id: String { rawValue }
    
    public var systemImage: String {
        switch self {
        case .fullScreen: return "display"
        case .selectedArea: return "viewfinder"
        case .window: return "macwindow"
        }
    }
    
    public var title: String {
        switch self {
        case .fullScreen: return "Layar Penuh"
        case .selectedArea: return "Pilih Area"
        case .window: return "Jendela"
        }
    }
    
    public var subtitle: String {
        switch self {
        case .fullScreen: return "Tangkap seluruh layar tampilan"
        case .selectedArea: return "Pilih dan tangkap area persegi"
        case .window: return "Pilih dan tangkap satu jendela aplikasi"
        }
    }
}
