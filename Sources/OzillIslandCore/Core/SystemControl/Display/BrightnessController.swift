import Foundation
import SwiftUI
import Combine
import CoreGraphics
import AppKit
import IOKit
import IOKit.graphics

/// Error domain untuk pengoperasian hardware layar tampilan.
public enum DisplayError: LocalizedError, Sendable {
    case unsupportedExternalMonitor
    case displayNotFound
    case hardwareReadFailed(Int32)
    case hardwareWriteFailed(Int32)
    
    public var errorDescription: String? {
        switch self {
        case .unsupportedExternalMonitor:
            return "Monitor eksternal memerlukan kontrol DDC/CI yang tidak didukung langsung oleh API publik macOS."
        case .displayNotFound:
            return "Layar tampilan tidak ditemukan pada sistem."
        case .hardwareReadFailed(let code):
            return "Gagal membaca kecerahan hardware IOKit (Error code: \(code))."
        case .hardwareWriteFailed(let code):
            return "Gagal menulis kecerahan hardware IOKit (Error code: \(code))."
        }
    }
}

/// Kontrak abstraksi untuk interaksi tingkat rendah dengan hardware layar tampilan macOS.
public protocol DisplayHardwareBridging: Sendable {
    func discoverDisplays() async -> [DisplayDevice]
    func readBrightness(for displayId: CGDirectDisplayID) async -> Result<Float, Error>
    func writeBrightness(_ value: Float, for displayId: CGDirectDisplayID) async -> Result<Void, Error>
}

/// Implementasi native hardware bridge menggunakan public framework Apple IOKit Graphics & AppKit.
public final class NativeDisplayHardwareBridge: DisplayHardwareBridging, @unchecked Sendable {
    public init() {}
    
    public func discoverDisplays() async -> [DisplayDevice] {
        await MainActor.run {
            var devices: [DisplayDevice] = []
            let mainId = CGMainDisplayID()
            
            for screen in NSScreen.screens {
                guard let num = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
                    continue
                }
                let isBuiltIn = CGDisplayIsBuiltin(num) != 0
                let isMain = (num == mainId)
                let name = screen.localizedName
                
                devices.append(
                    DisplayDevice(
                        id: num,
                        name: name,
                        kind: isBuiltIn ? .builtIn : .external,
                        isMain: isMain,
                        canAdjustBrightness: isBuiltIn
                    )
                )
            }
            return devices
        }
    }
    
    public func readBrightness(for displayId: CGDirectDisplayID) async -> Result<Float, Error> {
        let isBuiltIn = CGDisplayIsBuiltin(displayId) != 0
        guard isBuiltIn else {
            return .failure(DisplayError.unsupportedExternalMonitor)
        }
        
        var iterator: io_iterator_t = 0
        let matching = IOServiceMatching("IODisplayConnect")
        let kr = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard kr == kIOReturnSuccess else {
            return .failure(DisplayError.hardwareReadFailed(kr))
        }
        defer { IOObjectRelease(iterator) }
        
        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer { IOObjectRelease(service) }
            var b: Float = 0.0
            let res = IODisplayGetFloatParameter(service, 0, kIODisplayBrightnessKey as CFString, &b)
            if res == kIOReturnSuccess {
                return .success(max(0.0, min(1.0, b)))
            }
            service = IOIteratorNext(iterator)
        }
        return .failure(DisplayError.displayNotFound)
    }
    
    public func writeBrightness(_ value: Float, for displayId: CGDirectDisplayID) async -> Result<Void, Error> {
        let isBuiltIn = CGDisplayIsBuiltin(displayId) != 0
        guard isBuiltIn else {
            return .failure(DisplayError.unsupportedExternalMonitor)
        }
        
        let clamped = max(0.0, min(1.0, value))
        var iterator: io_iterator_t = 0
        let matching = IOServiceMatching("IODisplayConnect")
        let kr = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard kr == kIOReturnSuccess else {
            return .failure(DisplayError.hardwareWriteFailed(kr))
        }
        defer { IOObjectRelease(iterator) }
        
        var service = IOIteratorNext(iterator)
        var updated = false
        while service != 0 {
            defer { IOObjectRelease(service) }
            var b: Float = 0.0
            let readRes = IODisplayGetFloatParameter(service, 0, kIODisplayBrightnessKey as CFString, &b)
            if readRes == kIOReturnSuccess {
                let writeRes = IODisplaySetFloatParameter(service, 0, kIODisplayBrightnessKey as CFString, clamped)
                if writeRes == kIOReturnSuccess {
                    updated = true
                }
            }
            service = IOIteratorNext(iterator)
        }
        return updated ? .success(()) : .failure(DisplayError.hardwareWriteFailed(-1))
    }
}

/// Kontrak protokol untuk pengontrol kecerahan layar sistem macOS.
@MainActor
public protocol BrightnessControlling: AnyObject {
    var brightness: Float { get }
    var isAvailable: Bool { get }
    var status: DisplayBrightnessStatus { get }
    var activeDisplay: DisplayDevice? { get }
    var connectedDisplays: [DisplayDevice] { get }
    var stepIncrement: Float { get set }
    
    func setBrightness(_ value: Float)
    func increaseBrightness()
    func decreaseBrightness()
    func selectDisplay(id: CGDirectDisplayID)
    func refreshDisplays() async
    func refreshBrightness() async
}

/// Pengontrol sistem kecerahan layar macOS yang modular, non-blocking, dengan debouncing
/// dan proteksi sinkronisasi hardware internal/eksternal.
@MainActor
public final class BrightnessController: ObservableObject, BrightnessControlling {
    public static let shared = BrightnessController()
    
    @Published public private(set) var brightness: Float = 0.5
    @Published public private(set) var isAvailable: Bool = true
    @Published public private(set) var status: DisplayBrightnessStatus = .available
    @Published public private(set) var activeDisplay: DisplayDevice?
    @Published public private(set) var connectedDisplays: [DisplayDevice] = []
    
    public var stepIncrement: Float = 0.05
    
    private let hardwareBridge: any DisplayHardwareBridging
    private var pendingDebounceTask: Task<Void, Never>?
    private var isUpdatingLocally: Bool = false
    private var screenChangeObserver: (any NSObjectProtocol)?
    private var syncTimer: Timer?
    
    public init(hardwareBridge: any DisplayHardwareBridging = NativeDisplayHardwareBridge()) {
        self.hardwareBridge = hardwareBridge
        setupScreenObserver()
        Task {
            await refreshDisplays()
            await refreshBrightness()
        }
        startSyncTimer()
    }
    
    deinit {
        if let observer = screenChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        syncTimer?.invalidate()
    }
    
    private func setupScreenObserver() {
        screenChangeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refreshDisplays()
                await self?.refreshBrightness()
            }
        }
    }
    
    public func startSyncTimer() {
        syncTimer?.invalidate()
        syncTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refreshBrightness()
            }
        }
    }
    
    public func stopSyncTimer() {
        syncTimer?.invalidate()
        syncTimer = nil
    }
    
    /// Memperbarui daftar monitor yang tersambung ke komputer
    public func refreshDisplays() async {
        self.isUpdatingLocally = false
        let displays = await hardwareBridge.discoverDisplays()
        self.connectedDisplays = displays
        
        // Pertahankan layar aktif sebelumnya jika masih terpasang, atau pilih built-in / main display
        if let current = activeDisplay, displays.contains(where: { $0.id == current.id }) {
            // Update reference
            if let updated = displays.first(where: { $0.id == current.id }) {
                self.activeDisplay = updated
            }
        } else {
            // Utamakan built-in display jika ada, atau main display
            self.activeDisplay = displays.first(where: { $0.kind == .builtIn }) ?? displays.first(where: { $0.isMain }) ?? displays.first
        }
        
        updateStatusForActiveDisplay()
    }
    
    private func updateStatusForActiveDisplay() {
        guard let display = activeDisplay else {
            self.status = .error("Tidak ada display yang terdeteksi.")
            self.isAvailable = false
            return
        }
        
        if display.canAdjustBrightness {
            self.status = .available
            self.isAvailable = true
        } else {
            self.status = .unsupported(reason: "Monitor eksternal memerlukan kontrol DDC/CI yang tidak didukung langsung oleh API publik macOS.")
            self.isAvailable = false
        }
    }
    
    /// Membaca tingkat kecerahan aktual dari hardware untuk layar aktif
    public func refreshBrightness() async {
        await refreshBrightness(force: false)
    }
    
    /// Membaca tingkat kecerahan dengan opsi memaksa pembaruan mengabaikan lock lokal
    public func refreshBrightness(force: Bool) async {
        guard force || !isUpdatingLocally else { return }
        guard let display = activeDisplay else { return }
        guard display.canAdjustBrightness else {
            updateStatusForActiveDisplay()
            return
        }
        
        let result = await hardwareBridge.readBrightness(for: display.id)
        switch result {
        case .success(let val):
            self.brightness = max(0.0, min(1.0, val))
            self.status = .available
            self.isAvailable = true
        case .failure(let err):
            if let dispErr = err as? DisplayError, case .unsupportedExternalMonitor = dispErr {
                self.status = .unsupported(reason: dispErr.localizedDescription)
                self.isAvailable = false
            } else {
                self.status = .error(err.localizedDescription)
                self.isAvailable = false
            }
        }
    }
    
    /// Mengatur kecerahan dengan clamping (0.0 ... 1.0) dan debouncing non-blocking
    public func setBrightness(_ value: Float) {
        guard isAvailable, let display = activeDisplay, display.canAdjustBrightness else { return }
        let clamped = max(0.0, min(1.0, value))
        self.brightness = clamped
        
        isUpdatingLocally = true
        pendingDebounceTask?.cancel()
        pendingDebounceTask = Task {
            // Debounce 50ms untuk mencegah banjir operasi IOKit saat slider di-drag
            try? await Task.sleep(nanoseconds: 50_000_000)
            guard !Task.isCancelled else { return }
            
            _ = await self.hardwareBridge.writeBrightness(clamped, for: display.id)
            
            // Tahan lock lokal 300ms agar sinkronisasi background tidak menimpa aksi pengguna
            try? await Task.sleep(nanoseconds: 300_000_000)
            await MainActor.run {
                self.isUpdatingLocally = false
            }
        }
    }
    
    /// Meningkatkan kecerahan sebesar stepIncrement (default 0.05)
    public func increaseBrightness() {
        setBrightness(brightness + stepIncrement)
    }
    
    /// Menurunkan kecerahan sebesar stepIncrement (default 0.05)
    public func decreaseBrightness() {
        setBrightness(brightness - stepIncrement)
    }
    
    /// Memilih layar aktif secara manual
    public func selectDisplay(id: CGDirectDisplayID) {
        guard let found = connectedDisplays.first(where: { $0.id == id }) else { return }
        self.isUpdatingLocally = false
        self.activeDisplay = found
        updateStatusForActiveDisplay()
        Task {
            await refreshBrightness(force: true)
        }
    }
}
