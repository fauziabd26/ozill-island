import AppKit
import SwiftUI

@MainActor
public final class IslandWindowController: NSObject {
    public static let shared = IslandWindowController()
    
    private var panel: IslandPanel?
    private var hostingView: IslandHostingView<IslandPillView>?
    private var globalClickMonitor: Any?
    private var localClickMonitor: Any?
    
    public override init() {
        super.init()
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
        // Hanya auto-collapse jika sedang dalam state expanded atau settings
        guard currentState != .collapsed else { return }
        
        let mouseLocation = NSEvent.mouseLocation
        if !panel.frame.contains(mouseLocation) {
            collapse()
        }
    }
    
    /// Membuka langsung halaman Settings di floating island
    public func openSettings() {
        setupAndShow()
        panel?.makeKeyAndOrderFront(nil)
        PrayerIslandViewModel.shared.openSettings()
    }
    
    /// Membuka ke tampilan expanded
    public func expand() {
        setupAndShow()
        PrayerIslandViewModel.shared.expand()
    }
    
    /// Menutup panel kembali ke pill collapsed
    public func collapse() {
        PrayerIslandViewModel.shared.collapse()
    }
    
    /// Toggle antara collapsed dan expanded
    public func toggleExpand() {
        setupAndShow()
        PrayerIslandViewModel.shared.toggle()
    }
    
    public func updateFrame(for state: IslandState, animated: Bool = true) {
        guard let panel = panel else { return }
        
        let width: CGFloat
        let height: CGFloat
        
        switch state {
        case .collapsed:
            width = 360
            height = 48
        case .expanded:
            width = 390
            height = 405
        case .settings:
            width = 390
            height = 410
        }
        
        let targetFrame = calculateFrame(width: width, height: height)
        
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.35
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
        
        // Posisi tepat di tengah horizontal
        let x = visibleFrame.origin.x + (visibleFrame.width - width) / 2
        
        // Posisi tepat di bawah menu bar (2-4 pt padding)
        let menuBarBottom = visibleFrame.origin.y + visibleFrame.height
        let y = menuBarBottom - height - 4
        
        return NSRect(x: x, y: y, width: width, height: height)
    }
    
    @objc private func screenParametersChanged() {
        guard let panel = panel else { return }
        let currentSize = panel.frame.size
        let newFrame = calculateFrame(width: currentSize.width, height: currentSize.height)
        panel.setFrame(newFrame, display: true, animate: true)
    }
}
