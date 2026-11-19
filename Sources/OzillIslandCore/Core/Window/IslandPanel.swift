import AppKit
import SwiftUI

/// Custom NSHostingView yang meng-override acceptsFirstMouse agar interaksi klik pertama
/// pada floating panel langsung direspons tanpa tertelan saat aplikasi berada dalam status inactive.
/// Menjamin layer transparan sepenuhnya tanpa background bawaan AppKit yang kotak.
public final class IslandHostingView<Content: View>: NSHostingView<Content> {
    @MainActor public required init(rootView: Content) {
        super.init(rootView: rootView)
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.clear.cgColor
        self.layer?.masksToBounds = false
    }
    
    @MainActor public required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.clear.cgColor
        self.layer?.masksToBounds = false
    }
    
    public override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
}

public final class IslandPanel: NSPanel {
    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        self.isFloatingPanel = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.isMovableByWindowBackground = false
        self.hidesOnDeactivate = false
        
        // Pastikan contentView layer murni transparan tanpa artefak kotak
        self.contentView?.wantsLayer = true
        self.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
        self.contentView?.layer?.masksToBounds = false
    }
    
    public override var canBecomeKey: Bool {
        return true
    }
    
    public override var canBecomeMain: Bool {
        return false
    }
}
