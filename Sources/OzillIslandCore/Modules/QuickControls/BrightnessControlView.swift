import SwiftUI

/// Tampilan kontrol kecerahan layar horizontal terinspirasi Touch Bar MacBook.
/// Menyediakan slider interaktif, tombol step (-/+), dan tombol pintas min/max.
public struct BrightnessControlView: View {
    @ObservedObject private var controller = BrightnessController.shared
    @ObservedObject private var theme = IslandThemeManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDragging: Bool = false
    
    public init() {}
    
    private var isAvailable: Bool {
        controller.isAvailable
    }
    
    public var body: some View {
        let palette = theme.palette
        let accent = theme.effectiveAccentColor
        
        HStack(spacing: 6) {
            // Sun Dim Button (Hit target 32x32 pt)
            Button(action: {
                controller.setBrightness(0.05)
            }) {
                Image(systemName: "sun.min.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(isAvailable ? palette.secondaryText : palette.secondaryText.opacity(0.3))
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(palette.cardBackground.opacity(isAvailable ? 0.7 : 0.35))
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!isAvailable)
            .help(isAvailable ? "Kecerahan Minimum (5%)" : "Kecerahan tidak didukung")
            .accessibilityLabel("Kecerahan minimum")
            
            // Decrease Brightness Button (-) (Hit target 32x32 pt)
            Button(action: {
                controller.decreaseBrightness()
            }) {
                Image(systemName: "minus")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(isAvailable ? palette.primaryText : palette.secondaryText.opacity(0.3))
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(palette.cardBackground.opacity(isAvailable ? 0.7 : 0.35))
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!isAvailable)
            .help("Turunkan Kecerahan (\(Int(controller.stepIncrement * 100))%)")
            .accessibilityLabel("Kurangi kecerahan")
            
            // Interactive Slider Track
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track Background
                    Capsule(style: .continuous)
                        .fill(palette.cardBackground.opacity(isAvailable ? 1.0 : 0.4))
                        .frame(height: 5)
                    
                    if isAvailable {
                        // Active Fill Track
                        Capsule(style: .continuous)
                            .fill(accent)
                            .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(controller.brightness))), height: 5)
                        
                        // Thumb Indicator
                        Circle()
                            .fill(Color.white)
                            .frame(width: 12, height: 12)
                            .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                            .offset(x: max(0, min(geo.size.width - 12, (geo.size.width * CGFloat(controller.brightness)) - 6)))
                    } else {
                        // Unavailable diagonal or muted indicator
                        Text("Tidak Didukung")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(palette.secondaryText.opacity(0.5))
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .frame(height: 32)
                .contentShape(Rectangle())
                .gesture(
                    isAvailable ?
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            let pct = Float(max(0.0, min(1.0, value.location.x / geo.size.width)))
                            controller.setBrightness(pct)
                        }
                        .onEnded { value in
                            isDragging = false
                            let pct = Float(max(0.0, min(1.0, value.location.x / geo.size.width)))
                            controller.setBrightness(pct)
                        }
                    : nil
                )
            }
            .frame(height: 32)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Kecerahan Layar")
            .accessibilityValue(isAvailable ? "\(Int(controller.brightness * 100)) persen" : "Tidak didukung")
            
            // Increase Brightness Button (+) (Hit target 32x32 pt)
            Button(action: {
                controller.increaseBrightness()
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(isAvailable ? palette.primaryText : palette.secondaryText.opacity(0.3))
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(palette.cardBackground.opacity(isAvailable ? 0.7 : 0.35))
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!isAvailable)
            .help("Tingkatkan Kecerahan (\(Int(controller.stepIncrement * 100))%)")
            .accessibilityLabel("Tingkatkan kecerahan")
            
            // Sun Max Button (Hit target 32x32 pt)
            Button(action: {
                controller.setBrightness(1.0)
            }) {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isAvailable ? palette.secondaryText : palette.secondaryText.opacity(0.3))
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(palette.cardBackground.opacity(isAvailable ? 0.7 : 0.35))
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!isAvailable)
            .help(isAvailable ? "Kecerahan Maksimum (100%)" : "Kecerahan tidak didukung")
            .accessibilityLabel("Kecerahan maksimum")
        }
        .frame(height: 32)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: controller.brightness)
    }
}
