import AppKit
import SwiftUI

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var globalKeyMonitor: Any?
    private var localKeyMonitor: Any?
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Registrasi modul awal ke ModuleRegistry universal
        do {
            try ModuleRegistry.shared.register(PrayerIslandModule.shared)
            try ModuleRegistry.shared.register(MusicIslandModule.shared)
            try ModuleRegistry.shared.register(TimerIslandModule.shared)
        } catch {
            print("AppDelegate: Gagal registrasi modul awal -", error)
        }
        
        // Mulai pemantauan media otomatis di latar belakang
        _ = UniversalMusicManager.shared
        
        // Setup status item di macOS Menu Bar sebagai kontrol sekunder
        setupStatusItem()
        
        // Setup Pintasan Keyboard Global (Cmd + Shift + I)
        setupGlobalKeyboardShortcut()
        
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
        
        let settingsItem = NSMenuItem(title: "Pengaturan Ozill Island...", action: #selector(openSettingsAction), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
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
    
    private func setupGlobalKeyboardShortcut() {
        // Cmd + Shift + I (keyCode 34 adalah 'i' pada keyboard ANSI)
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains([.command, .shift]) && event.keyCode == 34 {
                Task { @MainActor in
                    self?.handleGlobalShortcutToggle()
                }
            }
        }
        
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains([.command, .shift]) && event.keyCode == 34 {
                Task { @MainActor in
                    self?.handleGlobalShortcutToggle()
                }
                return nil
            }
            return event
        }
    }
    
    @MainActor
    private func handleGlobalShortcutToggle() {
        let vm = PrayerIslandViewModel.shared
        if vm.state == .collapsed {
            vm.expand()
        } else {
            vm.collapse()
        }
    }
    
    public func applicationWillTerminate(_ notification: Notification) {
        if let g = globalKeyMonitor {
            NSEvent.removeMonitor(g)
        }
        if let l = localKeyMonitor {
            NSEvent.removeMonitor(l)
        }
    }
    
    @objc private func openSettingsAction() {
        IslandWindowController.shared.openSettings()
    }
    
    @objc private func refreshLocation() {
        LocationManager.shared.requestSingleLocation()
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
