import AppKit
import SwiftUI

@MainActor
public final class IslandWindowController: NSObject {
    public static let shared = IslandWindowController()
    
    private var panel: IslandPanel?
    private var hostingView: IslandHostingView<IslandPillView>?
    private var globalClickMonitor: Any?
    private var localClickMonitor: Any?
    
    // MARK: - Dragging & Custom Positioning
    private let kUserOffsetXKey = "OzillIsland_UserOffsetX"
    private let kUserOffsetYKey = "OzillIsland_UserOffsetY"
    
    public private(set) var customOffset: CGSize = .zero
    private var dragStartOrigin: NSPoint?
    
    public override init() {
        super.init()
        let savedX = UserDefaults.standard.double(forKey: kUserOffsetXKey)
        let savedY = UserDefaults.standard.double(forKey: kUserOffsetYKey)
        self.customOffset = CGSize(width: savedX, height: savedY)
    }
    
    public func setupAndShow() {
        guard panel == nil else {
            panel?.makeKeyAndOrderFront(nil)
            return
        }
        
        let initialWidth: CGFloat = 360
        let initialHeight: CGFloat = 48
        let rect = calculateFrame(width: initialWidth, height: initialHeight)
        
        let newPanel = IslandPanel(contentRect: rect)
        let rootView = IslandPillView(vm: PrayerIslandViewModel.shared)
        let hosting = IslandHostingView(rootView: rootView)
        hosting.frame = NSRect(x: 0, y: 0, width: initialWidth, height: initialHeight)
        hosting.autoresizingMask = [.width, .height]
        
        newPanel.contentView = hosting
        newPanel.setFrame(rect, display: true)
        newPanel.makeKeyAndOrderFront(nil)
        newPanel.orderFrontRegardless()
        
        self.panel = newPanel
        self.hostingView = hosting
        
        // Listen to screen changes (e.g. connecting external monitor)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        
        // Setup otomatis auto-collapse saat pengguna klik di luar island
        setupClickOutsideMonitoring()
    }
    
    // MARK: - Window Dragging Engine (Kiri, Kanan, Atas, Bawah)
    
    public func startDrag() {
        guard let panel = panel else { return }
        self.dragStartOrigin = panel.frame.origin
    }
    
    public func updateDrag(translation: CGSize) {
        guard let panel = panel, let start = dragStartOrigin else { return }
        
        // Di macOS AppKit: y positif adalah ke atas, sedangkan di SwiftUI translation.height positif adalah ke bawah
        let newX = start.x + translation.width
        let newY = start.y - translation.height
        
        panel.setFrameOrigin(NSPoint(x: newX, y: newY))
    }
    
    public func endDrag(translation: CGSize) {
        guard let panel = panel, let start = dragStartOrigin, let screen = NSScreen.main else {
            self.dragStartOrigin = nil
            return
        }
        
        let finalX = start.x + translation.width
        let finalY = start.y - translation.height
        
        let visibleFrame = screen.visibleFrame
        let currentSize = panel.frame.size
        let defaultX = visibleFrame.origin.x + (visibleFrame.width - currentSize.width) / 2
        let defaultY = visibleFrame.origin.y + visibleFrame.height - currentSize.height - 4
        
        // Hitung offset relatif terhadap default notch
        let newOffsetX = finalX - defaultX
        let newOffsetY = finalY - defaultY
        
        self.customOffset = CGSize(width: newOffsetX, height: newOffsetY)
        UserDefaults.standard.set(newOffsetX, forKey: kUserOffsetXKey)
        UserDefaults.standard.set(newOffsetY, forKey: kUserOffsetYKey)
        
        self.dragStartOrigin = nil
        
        // Snap halus ke batas frame layar jika terlempar ke luar layar
        updateFrame(for: PrayerIslandViewModel.shared.state, animated: true)
    }
    
    /// Reset posisi Island kembali ke tengah atas default (bawah notch / menu bar)
    public func resetPositionToDefault() {
        self.customOffset = .zero
        UserDefaults.standard.removeObject(forKey: kUserOffsetXKey)
        UserDefaults.standard.removeObject(forKey: kUserOffsetYKey)
        updateFrame(for: PrayerIslandViewModel.shared.state, animated: true)
    }
    
    // MARK: - Click Outside Handling
    
    private func setupClickOutsideMonitoring() {
        if globalClickMonitor == nil {
            globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handlePotentialClickOutside()
                }
            }
        }
        if localClickMonitor == nil {
            localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                Task { @MainActor [weak self] in
                    self?.handlePotentialClickOutside()
                }
                return event
            }
        }
    }
    
    private func handlePotentialClickOutside() {
        guard let panel = panel else { return }
        let currentState = PrayerIslandViewModel.shared.state
        guard currentState != .collapsed else { return }
        
        let mouseLocation = NSEvent.mouseLocation
        if !panel.frame.contains(mouseLocation) {
            collapse()
        }
    }
    
    public func openSettings() {
        setupAndShow()
        IdleDimmingService.shared.recordActivity()
        panel?.makeKeyAndOrderFront(nil)
        PrayerIslandViewModel.shared.openSettings()
    }
    
    public func expand() {
        setupAndShow()
        IdleDimmingService.shared.recordActivity()
        PrayerIslandViewModel.shared.expand()
    }
    
    public func collapse() {
        IdleDimmingService.shared.recordActivity()
        PrayerIslandViewModel.shared.collapse()
    }
    
    public func toggleExpand() {
        setupAndShow()
        IdleDimmingService.shared.recordActivity()
        PrayerIslandViewModel.shared.toggle()
    }
    
    // MARK: - Smooth Anchor-Aware Frame Update (Top-Center Pinned)
    
    public func updateFrame(for state: IslandState, animated: Bool = true) {
        guard let panel = panel, let screen = NSScreen.main else { return }
        
        let targetWidth: CGFloat
        let targetHeight: CGFloat
        
        switch state {
        case .collapsed:
            targetWidth = 360
            targetHeight = 48
        case .expanded:
            targetWidth = 390
            targetHeight = 425
        case .settings:
            targetWidth = 390
            targetHeight = 425
        }
        
        let currentFrame = panel.frame
        let visibleFrame = screen.visibleFrame
        
        // PENTING: Pertahankan titik jangkar top-center agar ekspansi dan kolaps
        // mekar / menggulung secara mulus dari posisi atas Island saat ini
        let currentTopCenter = CGPoint(
            x: currentFrame.origin.x + currentFrame.width / 2,
            y: currentFrame.origin.y + currentFrame.height
        )
        
        var targetX = currentTopCenter.x - targetWidth / 2
        var targetY = currentTopCenter.y - targetHeight
        
        // Jika belum ada posisi sebelumnya atau di luar batas, gunakan kalkulasi frame berbasis offset
        if currentFrame.width < 10 || currentFrame.height < 10 {
            let baseFrame = calculateFrame(width: targetWidth, height: targetHeight)
            targetX = baseFrame.origin.x
            targetY = baseFrame.origin.y
        } else {
            // Clamp agar tidak keluar dari visible frame layar
            targetX = max(visibleFrame.origin.x + 8, min(visibleFrame.origin.x + visibleFrame.width - targetWidth - 8, targetX))
            targetY = max(visibleFrame.origin.y + 8, min(visibleFrame.origin.y + visibleFrame.height - targetHeight - 2, targetY))
        }
        
        let targetFrame = NSRect(x: targetX, y: targetY, width: targetWidth, height: targetHeight)
        
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.40
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1.0, 0.3, 1.0)
                context.allowsImplicitAnimation = true
                panel.animator().setFrame(targetFrame, display: true)
            }
        } else {
            panel.setFrame(targetFrame, display: true)
        }
    }
    
    private func calculateFrame(width: CGFloat, height: CGFloat) -> NSRect {
        guard let screen = NSScreen.main else {
            return NSRect(x: 100, y: 100, width: width, height: height)
        }
        
        let visibleFrame = screen.visibleFrame
        
        // Posisi dasar: Tepat di tengah horizontal, tepat di bawah menu bar
        let defaultX = visibleFrame.origin.x + (visibleFrame.width - width) / 2
        let defaultY = visibleFrame.origin.y + visibleFrame.height - height - 4
        
        var x = defaultX + customOffset.width
        var y = defaultY + customOffset.height
        
        // Clamp agar tidak keluar dari visible frame layar
        x = max(visibleFrame.origin.x + 8, min(visibleFrame.origin.x + visibleFrame.width - width - 8, x))
        y = max(visibleFrame.origin.y + 8, min(visibleFrame.origin.y + visibleFrame.height - height - 2, y))
        
        return NSRect(x: x, y: y, width: width, height: height)
    }
    
    @objc private func screenParametersChanged() {
        guard let panel = panel else { return }
        let currentSize = panel.frame.size
        let newFrame = calculateFrame(width: currentSize.width, height: currentSize.height)
        panel.setFrame(newFrame, display: true, animate: true)
    }
}
