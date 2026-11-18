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
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.95)),
                            removal: .opacity.combined(with: .scale(scale: 0.95))
                        ))
                } else {
                    CollapsedPrayerPill(vm: vm)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.95)),
                            removal: .opacity.combined(with: .scale(scale: 0.95))
                        ))
                }
            case .expanded:
                if router.currentMode == .music {
                    ExpandedMusicSheet()
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.98)),
                            removal: .opacity.combined(with: .scale(scale: 0.98))
                        ))
                } else {
                    ExpandedPrayerSheet(vm: vm)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.98)),
                            removal: .opacity.combined(with: .scale(scale: 0.98))
                        ))
                }
            case .settings:
                PrayerSettingsSheet(vm: vm)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.98)),
                        removal: .opacity.combined(with: .scale(scale: 0.98))
                    ))
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: vm.state)
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: router.currentMode)
    }
}
