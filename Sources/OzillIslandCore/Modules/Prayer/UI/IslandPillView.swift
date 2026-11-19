import SwiftUI

@MainActor
public struct IslandPillView: View {
    @ObservedObject private var vm: PrayerIslandViewModel
    @ObservedObject private var router = IslandModeRouter.shared
    @ObservedObject private var dimmer = IdleDimmingService.shared
    @ObservedObject private var notifService = NotificationIslandService.shared
    
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
                ZStack {
                    if let activeNotif = notifService.activeNotification {
                        NotificationBannerPill(notification: activeNotif)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.94)).combined(with: .offset(y: -3)),
                                removal: .opacity.combined(with: .scale(scale: 0.95)).combined(with: .offset(y: 3))
                            ))
                            .zIndex(2)
                    } else if router.currentMode == .music {
                        CollapsedMusicPill()
                            .transition(.opacity.combined(with: .scale(scale: 0.97)))
                            .zIndex(1)
                    } else {
                        CollapsedPrayerPill(vm: vm)
                            .transition(.opacity.combined(with: .scale(scale: 0.97)))
                            .zIndex(0)
                    }
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
        .animation(.spring(response: 0.42, dampingFraction: 0.78), value: vm.state)
        .animation(.spring(response: 0.42, dampingFraction: 0.78), value: router.currentMode)
        .animation(.spring(response: 0.42, dampingFraction: 0.78), value: notifService.activeNotification)
        .onHover { hovering in
            if hovering {
                dimmer.recordActivity()
            }
        }
    }
}
