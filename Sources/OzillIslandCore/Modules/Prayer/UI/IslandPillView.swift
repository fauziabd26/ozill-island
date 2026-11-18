import SwiftUI

@MainActor
public struct IslandPillView: View {
    @ObservedObject private var vm: PrayerIslandViewModel
    @ObservedObject private var router = IslandModeRouter.shared
    
    public init(vm: PrayerIslandViewModel) {
        self.vm = vm
    }
    
    public init() {
        self.vm = PrayerIslandViewModel.shared
    }
    
    public var body: some View {
        Group {
            switch vm.state {
            case .collapsed:
                if router.currentMode == .music {
                    CollapsedMusicPill()
                } else {
                    CollapsedPrayerPill(vm: vm)
                }
            case .expanded:
                if router.currentMode == .music {
                    ExpandedMusicSheet()
                } else {
                    ExpandedPrayerSheet(vm: vm)
                }
            case .settings:
                PrayerSettingsSheet(vm: vm)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: vm.state)
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: router.currentMode)
    }
}
