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
                    .contentShape(Rectangle())
                    .onTapGesture {
                        vm.toggleExpand()
                    }
            case .expanded:
                ExpandedPrayerSheet(vm: vm)
            case .settings:
                PrayerSettingsSheet(vm: vm)
            }
        }
        .onHover { hovering in
            vm.isHovered = hovering
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: vm.state)
    }
}
