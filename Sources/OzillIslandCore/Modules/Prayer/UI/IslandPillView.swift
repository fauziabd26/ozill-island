import SwiftUI

@MainActor
public struct IslandPillView: View {
    @ObservedObject private var vm: PrayerIslandViewModel
    @ObservedObject private var router = IslandModeRouter.shared
    @ObservedObject private var dimmer = IdleDimmingService.shared
    
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
                ExpandedHubSheet(vm: vm)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.98)),
                        removal: .opacity.combined(with: .scale(scale: 0.98))
                    ))
            case .settings:
                PrayerSettingsSheet(vm: vm)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.98)),
                        removal: .opacity.combined(with: .scale(scale: 0.98))
                    ))
            }
        }
        .opacity(dimmer.currentOpacity)
        .animation(.easeInOut(duration: dimmer.isDimmed ? 0.8 : 0.35), value: dimmer.isDimmed)
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: vm.state)
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: router.currentMode)
        .onHover { hovering in
            if hovering {
                dimmer.recordActivity()
            }
        }
    }
}
