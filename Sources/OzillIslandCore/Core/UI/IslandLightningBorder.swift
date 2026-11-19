import SwiftUI

/// Mode bentuk border lightning untuk menyesuaikan kurva dinamis Ozill Island
public enum IslandLightningShapeType: Equatable, Sendable {
    case capsule
    case roundedRectangle(cornerRadius: CGFloat)
}

/// Shape wrapper yang mengonformasi kurva Capsule atau RoundedRectangle secara dinamis
public struct DynamicIslandShape: InsettableShape {
    public let shapeType: IslandLightningShapeType
    public var insetAmount: CGFloat = 0

    public init(shapeType: IslandLightningShapeType, insetAmount: CGFloat = 0) {
        self.shapeType = shapeType
        self.insetAmount = insetAmount
    }

    public func inset(by amount: CGFloat) -> DynamicIslandShape {
        var copy = self
        copy.insetAmount += amount
        return copy
    }

    public func path(in rect: CGRect) -> Path {
        let insetRect = rect.insetBy(dx: insetAmount, dy: insetAmount)
        switch shapeType {
        case .capsule:
            return Capsule(style: .continuous).path(in: insetRect)
        case .roundedRectangle(let radius):
            return RoundedRectangle(cornerRadius: max(0, radius - insetAmount), style: .continuous).path(in: insetRect)
        }
    }
}

/// Komponen visual Lightning Border: Menghadirkan efek kilatan listrik (electric arcs,
/// high-voltage plasma aura, & energetic spark pulses) di sekeliling border melengkung (round) Ozill Island.
@MainActor
public struct IslandLightningBorder: View {
    public let shapeType: IslandLightningShapeType
    public var accentColor: Color? = nil
    public var isHovered: Bool = false

    @ObservedObject private var settings = GeneralSettings.shared
    @ObservedObject private var dimmer = IdleDimmingService.shared

    public init(
        shapeType: IslandLightningShapeType,
        accentColor: Color? = nil,
        isHovered: Bool = false
    ) {
        self.shapeType = shapeType
        self.accentColor = accentColor
        self.isHovered = isHovered
    }

    public var body: some View {
        if settings.isLightningEnabled && !dimmer.isDimmed {
            TimelineView(.animation(paused: dimmer.isDimmed)) { timeline in
                let now = timeline.date.timeIntervalSinceReferenceDate
                let angle = Angle(degrees: (now * 115.0).truncatingRemainder(dividingBy: 360.0))

                // Fluktuasi tegangan listrik & lonjakan kilatan petir (electrical discharge)
                let pulse1 = sin(now * 14.0) * 0.16
                let pulse2 = cos(now * 26.0) * 0.12
                let discharge = (sin(now * 3.7) > 0.82) ? 0.40 : 0.0
                let intensity = min(1.0, max(0.48, 0.72 + pulse1 + pulse2 + discharge + (isHovered ? 0.25 : 0.0)))

                let effectiveAccent = accentColor ?? Color(red: 0.0, green: 0.90, blue: 1.0)
                let islandShape = DynamicIslandShape(shapeType: shapeType)

                // Palet gradien petir neon bertegangan tinggi
                let electricGradient = AngularGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.0, green: 0.92, blue: 1.0),          // Neon Electric Cyan
                        Color.white,                                      // Hot Lightning Core
                        Color(red: 0.2, green: 0.65, blue: 1.0),          // Arc Blue
                        effectiveAccent,                                  // Dynamic Theme Accent
                        Color(red: 0.75, green: 0.38, blue: 1.0),         // Plasma Violet
                        Color.white.opacity(0.95),                        // Spark Flash
                        Color(red: 0.0, green: 0.95, blue: 0.85),         // Electric Turquoise
                        Color(red: 0.0, green: 0.92, blue: 1.0)           // Loop
                    ]),
                    center: .center,
                    angle: angle
                )

                ZStack {
                    // 1. Outer Electric Bloom Glow (Pancaran aura lembut di sekeliling kurva)
                    islandShape
                        .stroke(
                            effectiveAccent.opacity(0.38 * intensity),
                            lineWidth: isHovered ? 4.5 : 3.0
                        )
                        .blur(radius: isHovered ? 4.0 : 2.5)

                    // 2. High-Voltage Plasma Arc (Aliran petir utama yang mengitari border)
                    islandShape
                        .stroke(
                            electricGradient,
                            lineWidth: isHovered ? 1.8 : 1.3
                        )
                        .opacity(intensity)

                    // 3. Ultra-Crisp White Lightning Core (Filamen inti petir putih berkecepatan tinggi)
                    islandShape
                        .stroke(
                            Color.white.opacity(0.75 * intensity),
                            style: StrokeStyle(
                                lineWidth: 0.8,
                                dash: [10, 16, 24, 12],
                                dashPhase: CGFloat((now * 85.0).truncatingRemainder(dividingBy: 62.0))
                            )
                        )

                    // 4. Jagged Electric Sparks (Lonjakan kilatan putih terang saat pelepasan muatan listrik)
                    if discharge > 0.1 || isHovered {
                        islandShape
                            .stroke(
                                Color.white,
                                lineWidth: 1.2
                            )
                            .opacity((discharge + (isHovered ? 0.22 : 0.0)) * 0.85)
                            .shadow(color: Color(red: 0.0, green: 0.90, blue: 1.0), radius: 3.5)
                    }
                }
            }
            .allowsHitTesting(false)
        }
    }
}
