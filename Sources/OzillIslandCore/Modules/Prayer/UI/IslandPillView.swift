import SwiftUI

@MainActor
public struct IslandPillView: View {
    @ObservedObject private var vm: PrayerIslandViewModel
    @ObservedObject private var router = IslandModeRouter.shared
    @ObservedObject private var dimmer = IdleDimmingService.shared
    @ObservedObject private var notifService = NotificationIslandService.shared
    
    @State private var isDragging: Bool = false
    
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
                                insertion: .opacity.combined(with: .scale(scale: 0.94, anchor: .top)).combined(with: .offset(y: -3)),
                                removal: .opacity.combined(with: .scale(scale: 0.95, anchor: .top)).combined(with: .offset(y: 3))
                            ))
                            .zIndex(2)
                    } else if router.currentMode == .music {
                        CollapsedMusicPill()
                            .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
                            .zIndex(1)
                    } else {
                        CollapsedPrayerPill(vm: vm)
                            .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
                            .zIndex(0)
                    }
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.92, anchor: .top)),
                    removal: .opacity.combined(with: .scale(scale: 0.92, anchor: .top))
                ))
                // Gesture Geser (Drag ke kiri, kanan, atas, bawah) saat mode collapsed
                .gesture(
                    DragGesture(minimumDistance: 4, coordinateSpace: .global)
                        .onChanged { value in
                            if !isDragging {
                                isDragging = true
                                IslandWindowController.shared.startDrag()
                            }
                            IslandWindowController.shared.updateDrag(translation: value.translation)
                        }
                        .onEnded { value in
                            isDragging = false
                            IslandWindowController.shared.endDrag(translation: value.translation)
                        }
                )
            case .expanded:
                ExpandedHubSheet(vm: vm)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .top)).combined(with: .offset(y: -4)),
                        removal: .opacity.combined(with: .scale(scale: 0.95, anchor: .top)).combined(with: .offset(y: -4))
                    ))
            case .settings:
                PrayerSettingsSheet(vm: vm)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .top)).combined(with: .offset(y: -4)),
                        removal: .opacity.combined(with: .scale(scale: 0.95, anchor: .top)).combined(with: .offset(y: -4))
                    ))
            }
        }
        .opacity(dimmer.currentOpacity)
        .animation(.easeInOut(duration: dimmer.isDimmed ? 0.8 : 0.35), value: dimmer.isDimmed)
        .animation(.spring(response: 0.40, dampingFraction: 0.80), value: vm.state)
        .animation(.spring(response: 0.40, dampingFraction: 0.80), value: router.currentMode)
        .animation(.spring(response: 0.40, dampingFraction: 0.80), value: notifService.activeNotification)
        .onHover { hovering in
            if hovering {
                dimmer.recordActivity()
            }
        }
    }
}
