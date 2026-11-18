import SwiftUI
import AppKit
import OzillIslandCore

@main
struct OzillIslandApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
