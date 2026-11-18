import AppKit
import SwiftUI

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Setup status item di macOS Menu Bar sebagai kontrol sekunder
        setupStatusItem()
        
        // Inisialisasi dan tampilkan floating dynamic island
        IslandWindowController.shared.setupAndShow()
        
        // Minta izin notifikasi
        Task {
            await PrayerNotificationManager.shared.requestPermission()
        }
        
        // Minta lokasi awal (single-shot)
        if PrayerSettings.shared.locationMode == .automaticGPS {
            LocationManager.shared.requestSingleLocation()
        }
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "moon.stars.fill", accessibilityDescription: "Ozill Island")
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Ozill Island (Prayer Times)", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        
        let toggleItem = NSMenuItem(title: "Tampilkan / Sembunyikan Island", action: #selector(toggleIsland), keyEquivalent: "i")
        toggleItem.target = self
        menu.addItem(toggleItem)
        
        let refreshLocItem = NSMenuItem(title: "Perbarui Lokasi GPS", action: #selector(refreshLocation), keyEquivalent: "r")
        refreshLocItem.target = self
        menu.addItem(refreshLocItem)
        
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Keluar dari Ozill Island", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    @objc private func toggleIsland() {
        IslandWindowController.shared.setupAndShow()
    }
    
    @objc private func refreshLocation() {
        LocationManager.shared.requestSingleLocation()
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
