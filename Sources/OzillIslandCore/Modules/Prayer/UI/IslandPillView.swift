import SwiftUI

@MainActor
public struct IslandPillView: View {
    @ObservedObject private var vm: PrayerIslandViewModel
    
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
                CollapsedPrayerPill(vm: vm)
            case .expanded:
                ExpandedPrayerSheet(vm: vm)
            case .settings:
                PrayerSettingsSheet(vm: vm)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: vm.state)
    }
}
