import SwiftUI

// =========================================
// === DATEI: ReadinessHero.swift ===
// === Topographic brand-anchor hero for BasecampScreen ===
// =========================================
//
// 200pt-tall topography + warm radial glow + central summit dot.
// Sits between top header and editorial block on the main screen.
// Entry animation (~1.4s once) + dauerhafte 4s breathing-pulse on
// the glow only — rings stay static for GPU-cheap frame budget.

struct ReadinessHero: View {
    var mood: Mood = .ready

    @State private var hasAppeared = false
    @State private var pulseScale: CGFloat = 1.0

    enum Mood {
        case ready, moderate, rest, caution

        var glowColor: Color {
            switch self {
            case .ready:    return DesignSystem.Colors.alpenglow
            case .moderate: return DesignSystem.Colors.alpenglow.opacity(0.7)
            case .rest:     return DesignSystem.Colors.glacierDeep
            case .caution:  return DesignSystem.Colors.ember
            }
        }
    }

    var body: some View {
        ZStack {
            // Layer 1: warm radial glow — breathes (4s loop on scaleEffect).
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            mood.glowColor.opacity(0.42),
                            mood.glowColor.opacity(0.16),
                            mood.glowColor.opacity(0.04),
                            .clear
                        ],
                        center: .center,
                        startRadius: 4,
                        endRadius: 90
                    )
                )
                .frame(width: 200, height: 200)
                .scaleEffect(pulseScale)
                .opacity(hasAppeared ? 1.0 : 0.0)
                .animation(.easeOut(duration: 1.4).delay(0.2), value: hasAppeared)

            // Layer 2: contour rings (irregular concentric ellipses, outer → inner).
            ZStack {
                ForEach(Array(ringConfigs.enumerated()), id: \.offset) { index, config in
                    ContourRingShape(seed: index)
                        .stroke(
                            DesignSystem.Colors.glacierDeep.opacity(config.opacity),
                            style: StrokeStyle(lineWidth: 0.8, lineCap: .round, lineJoin: .round)
                        )
                        .frame(width: config.width, height: config.height)
                        .opacity(hasAppeared ? 1.0 : 0.0)
                        .scaleEffect(hasAppeared ? 1.0 : 0.85)
                        .animation(
                            .easeOut(duration: 0.9)
                                .delay(0.1 + Double(index) * 0.08),
                            value: hasAppeared
                        )
                }
            }

            // Layer 3: central summit dot.
            Circle()
                .fill(mood.glowColor)
                .frame(width: 6, height: 6)
                .opacity(hasAppeared ? 1.0 : 0.0)
                .scaleEffect(hasAppeared ? 1.0 : 0.5)
                .animation(.easeOut(duration: 0.6).delay(0.6), value: hasAppeared)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .onAppear {
            hasAppeared = true

            withAnimation(
                .easeInOut(duration: 4.0).repeatForever(autoreverses: true)
            ) {
                pulseScale = 1.06
            }
        }
    }

    // Largest first → smallest. Width/height differ to stay elliptical.
    private var ringConfigs: [(width: CGFloat, height: CGFloat, opacity: Double)] {
        [
            (290, 200, 0.14),
            (240, 165, 0.20),
            (190, 130, 0.28),
            (145, 100, 0.38),
            (105, 72,  0.50),
            (70,  48,  0.62)
        ]
    }
}

// MARK: - Contour Ring Shape (irregular concentric ellipse for organic feel)

struct ContourRingShape: Shape {
    let seed: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cx = rect.midX
        let cy = rect.midY
        let rx = rect.width / 2
        let ry = rect.height / 2

        let segments = 24
        for i in 0...segments {
            let angle = (Double(i) / Double(segments)) * 2 * .pi
            let variance = sin(angle * 3 + Double(seed) * 0.7) * 0.06 + 1.0
            let x = cx + cos(angle) * rx * variance
            let y = cy + sin(angle) * ry * variance

            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()
        return path
    }
}

#if DEBUG
#Preview("Ready") {
    ReadinessHero(mood: .ready)
        .background(DesignSystem.Colors.paperWarm)
}

#Preview("Rest") {
    ReadinessHero(mood: .rest)
        .background(DesignSystem.Colors.paperWarm)
}

#Preview("Caution") {
    ReadinessHero(mood: .caution)
        .background(DesignSystem.Colors.paperWarm)
}
#endif
