import SwiftUI

public struct TimerTabContent: View {
    @ObservedObject private var timerService = TimerService.shared
    @ObservedObject private var theme = IslandThemeManager.shared
    
    public init() {}
    
    public var body: some View {
        let palette = theme.palette
        let accent = theme.effectiveAccentColor
        let isRunning = timerService.state == .running
        let isCompleted = timerService.state == .completed
        
        VStack(spacing: 12) {
            // Preset Selectors
            HStack(spacing: 6) {
                ForEach(TimerPreset.allCases) { preset in
                    let isSelected = timerService.currentPreset == preset
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            timerService.selectPreset(preset)
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: preset.sfSymbol)
                                .font(.system(size: 9))
                            Text(preset.shortLabel)
                                .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                        }
                        .foregroundColor(isSelected ? .white : palette.secondaryText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4.5)
                        .background(
                            isSelected ?
                            AnyView(Capsule(style: .continuous).fill(accent)) :
                            AnyView(Capsule(style: .continuous).fill(palette.cardBackground))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.top, 4)
            
            // Countdown Display with Circular Ring
            ZStack {
                // Background Track
                Circle()
                    .stroke(palette.border.opacity(0.8), lineWidth: 6)
                    .frame(width: 140, height: 140)
                
                // Progress Arc
                Circle()
                    .trim(from: 0.0, to: CGFloat(timerService.progress))
                    .stroke(
                        isCompleted ? Color.green : accent,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 140, height: 140)
                    .animation(.linear(duration: 0.5), value: timerService.progress)
                
                VStack(spacing: 2) {
                    if isCompleted {
                        Text("SELESAI! 🎉")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundColor(.green)
                    } else {
                        Text(timerService.currentPreset.rawValue.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(palette.secondaryText)
                    }
                    
                    Text(timerService.formattedRemainingTime)
                        .font(.system(size: 30, weight: .bold, design: .monospaced))
                        .foregroundColor(palette.primaryText)
                    
                    Text(isRunning ? "Sedang Berjalan" : (timerService.state == .paused ? "Dijeda" : "Siap"))
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundColor(palette.secondaryText)
                }
            }
            .padding(.vertical, 4)
            
            // Controls (Start/Pause & Reset)
            HStack(spacing: 16) {
                // Reset Button
                Button(action: {
                    withAnimation {
                        timerService.reset()
                    }
                }) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(palette.primaryText)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(palette.cardBackground))
                }
                .buttonStyle(PlainButtonStyle())
                .help("Reset Timer")
                
                // Play / Pause Button
                Button(action: {
                    withAnimation {
                        timerService.togglePlayPause()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: isRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text(isRunning ? "Jeda" : (timerService.state == .paused ? "Lanjut" : "Mulai"))
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 9)
                    .background(
                        Capsule(style: .continuous)
                            .fill(accent)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }
}
