import AppKit
import SwiftUI

@MainActor
public final class IslandWindowController: NSObject {
    public static let shared = IslandWindowController()
    
    private var panel: IslandPanel?
    private var hostingView: IslandHostingView<IslandPillView>?
    
    public override init() {
        super.init()
    }
    
    public func setupAndShow() {
        guard panel == nil else {
            panel?.makeKeyAndOrderFront(nil)
            return
        }
        
        let initialWidth: CGFloat = 260
        let initialHeight: CGFloat = 46
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
            width = 260
            height = 46
        case .expanded:
            width = 390
            height = 375
        case .settings:
            width = 390
            height = 410
        }
        
        let targetFrame = calculateFrame(width: width, height: height)
        
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.32
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
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
