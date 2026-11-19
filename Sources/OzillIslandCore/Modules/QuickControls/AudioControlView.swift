import SwiftUI

/// Tampilan kontrol volume audio horizontal terinspirasi Touch Bar MacBook.
/// Menyediakan slider interaktif, tombol step (-/+), dan tombol bisu cepat.
public struct AudioControlView: View {
    @ObservedObject private var controller = AudioController.shared
    @ObservedObject private var theme = IslandThemeManager.shared
    @State private var isDragging: Bool = false
    
    public init() {}
    
    private var speakerIcon: String {
        if controller.isMuted || controller.volume == 0 {
            return "speaker.slash.fill"
        } else if controller.volume < 0.33 {
            return "speaker.fill"
        } else if controller.volume < 0.66 {
            return "speaker.wave.1.fill"
        } else {
            return "speaker.wave.2.fill"
        }
    }
    
    public var body: some View {
        let palette = theme.palette
        let accent = theme.effectiveAccentColor
        
        HStack(spacing: 8) {
            // Mute / Unmute Button
            Button(action: {
                controller.toggleMute()
            }) {
                Image(systemName: speakerIcon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(controller.isMuted ? .red : palette.primaryText)
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(controller.isMuted ? Color.red.opacity(0.18) : palette.cardBackground)
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .help(controller.isMuted ? "Bunyikan Audio" : "Bisu (Mute)")
            .accessibilityLabel(controller.isMuted ? "Audio dibisukan. Klik untuk membunyikan." : "Audio aktif. Klik untuk membisukan.")
            
            // Decrease Volume Button (-)
            Button(action: {
                controller.decreaseVolume()
            }) {
                Image(systemName: "minus")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundColor(palette.secondaryText)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(palette.cardBackground.opacity(0.7)))
            }
            .buttonStyle(PlainButtonStyle())
            .help("Turunkan Volume (\(Int(controller.stepIncrement * 100))%)")
            .accessibilityLabel("Kurangi volume")
            
            // Interactive Slider Track
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track Background
                    Capsule(style: .continuous)
                        .fill(palette.cardBackground)
                        .frame(height: 5)
                    
                    // Active Fill Track
                    Capsule(style: .continuous)
                        .fill(controller.isMuted ? palette.secondaryText.opacity(0.35) : accent)
                        .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(controller.volume))), height: 5)
                    
                    // Thumb Indicator
                    Circle()
                        .fill(Color.white)
                        .frame(width: 12, height: 12)
                        .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                        .offset(x: max(0, min(geo.size.width - 12, (geo.size.width * CGFloat(controller.volume)) - 6)))
                }
                .frame(height: 20)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            let pct = Float(max(0.0, min(1.0, value.location.x / geo.size.width)))
                            controller.setVolume(pct)
                        }
                        .onEnded { value in
                            isDragging = false
                            let pct = Float(max(0.0, min(1.0, value.location.x / geo.size.width)))
                            controller.setVolume(pct)
                        }
                )
            }
            .frame(height: 20)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Tingkat Volume")
            .accessibilityValue("\(Int(controller.volume * 100)) persen")
            
            // Increase Volume Button (+)
            Button(action: {
                controller.increaseVolume()
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundColor(palette.secondaryText)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(palette.cardBackground.opacity(0.7)))
            }
            .buttonStyle(PlainButtonStyle())
            .help("Naikkan Volume (\(Int(controller.stepIncrement * 100))%)")
            .accessibilityLabel("Tambah volume")
            
            // Percentage Label
            Text("\(Int((controller.volume * 100).rounded()))%")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(controller.isMuted ? palette.secondaryText : palette.primaryText)
                .frame(width: 32, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(palette.background.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(palette.border.opacity(0.6), lineWidth: 0.8)
        )
    }
}
