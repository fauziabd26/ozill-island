import SwiftUI

/// Gaya presentasi untuk TimerControlView:
/// - `.strip`: Tampilan ringkas 1-baris untuk Touch Bar drawer
/// - `.card`: Tampilan kartu lengkap terintegrasi di sheet Quick Controls
public enum TimerControlPresentationStyle: Sendable {
    case strip
    case card
}

/// Tampilan kontrol timer Pomodoro / Focus Session yang terintegrasi di Quick Controls.
/// Menggunakan TimerService.shared sebagai Single Source of Truth.
public struct TimerControlView: View {
    @ObservedObject private var timerService = TimerService.shared
    @ObservedObject private var theme = IslandThemeManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public var presentationStyle: TimerControlPresentationStyle

    public init(presentationStyle: TimerControlPresentationStyle = .card) {
        self.presentationStyle = presentationStyle
    }

    public var body: some View {
        switch presentationStyle {
        case .strip:
            stripLayout
        case .card:
            cardLayout
        }
    }

    // MARK: - Strip Layout (Touch Bar 1-Row Drawer)

    @ViewBuilder
    private var stripLayout: some View {
        let palette = theme.palette
        let accent = theme.effectiveAccentColor
        let isRunning = timerService.state == .running

        HStack(spacing: 6) {
            // Preset Pills
            ForEach(TimerPreset.allCases) { preset in
                let isSelected = timerService.currentPreset == preset
                Button(action: {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.78)) {
                        timerService.selectPreset(preset)
                    }
                }) {
                    Text(preset.shortLabel)
                        .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                        .foregroundColor(isSelected ? .white : palette.secondaryText)
                        .padding(.horizontal, 7)
                        .frame(height: 32)
                        .background(
                            Capsule(style: .continuous)
                                .fill(isSelected ? accent : palette.cardBackground.opacity(0.7))
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .help("Pilih durasi \(preset.rawValue)")
                .accessibilityLabel("Preset \(preset.rawValue)")
            }

            // Countdown Display
            Text(timerService.formattedRemainingTime)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(isRunning ? accent : palette.primaryText)
                .padding(.horizontal, 8)
                .frame(height: 32)
                .background(
                    Capsule(style: .continuous)
                        .fill(palette.cardBackground.opacity(0.8))
                )
                .accessibilityLabel("Sisa waktu \(timerService.formattedRemainingTime)")

            // Play / Pause Toggle Button (32x32 pt hit target)
            Button(action: {
                withAnimation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.78)) {
                    timerService.togglePlayPause()
                }
            }) {
                Image(systemName: isRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(isRunning ? accent : palette.primaryText)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(isRunning ? accent.opacity(0.18) : palette.cardBackground)
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .help(isRunning ? "Jeda Timer" : "Mulai Timer")
            .accessibilityLabel(isRunning ? "Jeda timer" : "Mulai timer")

            // Reset Button (32x32 pt hit target)
            Button(action: {
                withAnimation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.78)) {
                    timerService.reset()
                }
            }) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(palette.secondaryText)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(palette.cardBackground))
            }
            .buttonStyle(PlainButtonStyle())
            .help("Reset Timer ke Awal")
            .accessibilityLabel("Reset timer")
        }
        .frame(height: 32)
    }

    // MARK: - Card Layout (Sheet Presentation in Quick Controls)

    @ViewBuilder
    private var cardLayout: some View {
        let palette = theme.palette
        let accent = theme.effectiveAccentColor
        let isRunning = timerService.state == .running
        let isCompleted = timerService.state == .completed

        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "timer")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(isRunning ? accent : palette.primaryText)

                Text("Focus & Pomodoro Timer")
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundColor(palette.primaryText)

                Spacer()

                Text(isCompleted ? "SELESAI! 🎉" : (isRunning ? "Sedang Berjalan" : (timerService.state == .paused ? "Dijeda" : "Siap")))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(isCompleted ? .green : (isRunning ? accent : palette.secondaryText))
            }

            // Preset Pills
            HStack(spacing: 6) {
                ForEach(TimerPreset.allCases) { preset in
                    let isSelected = timerService.currentPreset == preset
                    Button(action: {
                        withAnimation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.78)) {
                            timerService.selectPreset(preset)
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: preset.sfSymbol)
                                .font(.system(size: 9))
                            Text(preset.rawValue)
                                .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                        }
                        .foregroundColor(isSelected ? .white : palette.secondaryText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4.5)
                        .frame(maxWidth: .infinity)
                        .background(
                            isSelected ?
                            AnyView(Capsule(style: .continuous).fill(accent)) :
                            AnyView(Capsule(style: .continuous).fill(palette.background.opacity(0.6)))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Atur timer ke \(preset.rawValue)")
                }
            }

            // Timer Display & Controls Row
            HStack(spacing: 12) {
                // Countdown Digital Display
                HStack(spacing: 6) {
                    Text(timerService.formattedRemainingTime)
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundColor(palette.primaryText)

                    if isRunning {
                        Circle()
                            .fill(accent)
                            .frame(width: 6, height: 6)
                    }
                }
                .padding(.horizontal, 10)
                .frame(height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(palette.background.opacity(0.7))
                )

                Spacer()

                // Play / Pause Button (Hit target 32x32 pt)
                Button(action: {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.78)) {
                        timerService.togglePlayPause()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: isRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text(isRunning ? "Jeda" : "Mulai")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(isRunning ? .white : palette.primaryText)
                    .padding(.horizontal, 12)
                    .frame(height: 32)
                    .background(
                        Capsule(style: .continuous)
                            .fill(isRunning ? accent : palette.background)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .help(isRunning ? "Jeda hitungan mundur" : "Mulai hitungan mundur")
                .accessibilityLabel(isRunning ? "Jeda timer" : "Mulai timer")

                // Reset Button (Hit target 32x32 pt)
                Button(action: {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.78)) {
                        timerService.reset()
                    }
                }) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(palette.secondaryText)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(palette.background))
                }
                .buttonStyle(PlainButtonStyle())
                .help("Reset Timer")
                .accessibilityLabel("Reset timer")
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(palette.cardBackground.opacity(0.6))
        )
    }
}
