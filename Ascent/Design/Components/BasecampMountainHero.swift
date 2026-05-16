import SwiftUI

// =========================================
// === DATEI: BasecampMountainHero.swift ===
// === Staged mountain silhouettes + rising sun brand hero ===
// =========================================
//
// Replaces ReadinessHero on the Basecamp main screen so the
// topography pattern stays exclusive to the Summit Readiness
// detail view. 200pt tall, three layered silhouettes (back ->
// middle -> front), sun glow + small disc anchored slightly left
// of center. Sun drifts vertically on an 8s loop, back layer
// "breathes" atmospherically on a 6s loop — both GPU-cheap.
//
// ReadinessHero.swift stays in the repo for the SummitReadiness
// detail screen and any future use.

struct BasecampMountainHero: View {
    var mood: Mood = .ready

    @State private var hasAppeared = false
    @State private var sunDrift: CGFloat = 0
    @State private var atmospherePulse: CGFloat = 1.0

    enum Mood {
        case ready, moderate, rest, caution

        var sunColor: Color {
            switch self {
            case .ready:    return DesignSystem.Colors.alpenglow
            case .moderate: return DesignSystem.Colors.alpenglow.opacity(0.85)
            case .rest:     return DesignSystem.Colors.glacierDeep
            case .caution:  return DesignSystem.Colors.ember
            }
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {

            // Layer 1: sun glow (large radial behind mountains)
            sunGlow
                .offset(y: sunDrift)

            // Layer 2: sun disc (small bright core)
            sunDisc
                .offset(y: sunDrift)

            // Layer 3: back mountains — atmospheric haze
            MountainSilhouetteShape(layer: .back)
                .fill(DesignSystem.Colors.glacierDeep.opacity(0.14))
                .scaleEffect(x: 1.0, y: atmospherePulse, anchor: .bottom)
                .opacity(hasAppeared ? 1.0 : 0.0)
                .animation(.easeOut(duration: 1.2).delay(0.1), value: hasAppeared)

            // Layer 4: middle mountains — glacier tint
            MountainSilhouetteShape(layer: .middle)
                .fill(DesignSystem.Colors.glacierDeep.opacity(0.32))
                .opacity(hasAppeared ? 1.0 : 0.0)
                .animation(.easeOut(duration: 1.2).delay(0.3), value: hasAppeared)

            // Layer 5: front mountains — warm slate silhouette, not a
            // black stone block. inkWarm @ 0.55 reads soft-dark-warm.
            MountainSilhouetteShape(layer: .front)
                .fill(DesignSystem.Colors.inkWarm.opacity(0.55))
                .opacity(hasAppeared ? 1.0 : 0.0)
                .animation(.easeOut(duration: 1.2).delay(0.5), value: hasAppeared)

            // Layer 6: bottom fade — last 70pt melt into paperWarm so
            // the hero glides into the page bg without a hard seam.
            LinearGradient(
                colors: [
                    DesignSystem.Colors.paperWarm.opacity(0),
                    DesignSystem.Colors.paperWarm.opacity(0.35),
                    DesignSystem.Colors.paperWarm
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 70)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .allowsHitTesting(false)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .clipped()
        .onAppear {
            hasAppeared = true

            // Sun drifts vertically very slowly (sunrise feel).
            withAnimation(
                .easeInOut(duration: 8.0).repeatForever(autoreverses: true)
            ) {
                sunDrift = -10
            }

            // Back mountains breathe atmospherically.
            withAnimation(
                .easeInOut(duration: 6.0).repeatForever(autoreverses: true)
            ) {
                atmospherePulse = 1.03
            }
        }
    }

    // MARK: - Sun

    private var sunGlow: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        mood.sunColor.opacity(0.50),
                        mood.sunColor.opacity(0.20),
                        mood.sunColor.opacity(0.05),
                        .clear
                    ],
                    center: .center,
                    startRadius: 6,
                    endRadius: 110
                )
            )
            .frame(width: 220, height: 220)
            .offset(x: -50, y: -25)
            .opacity(hasAppeared ? 1.0 : 0.0)
            .animation(.easeOut(duration: 1.6).delay(0.2), value: hasAppeared)
    }

    private var sunDisc: some View {
        Circle()
            .fill(mood.sunColor)
            .frame(width: 18, height: 18)
            .offset(x: -50, y: -25)
            .opacity(hasAppeared ? 1.0 : 0.0)
            .animation(.easeOut(duration: 0.7).delay(0.7), value: hasAppeared)
    }
}

// MARK: - Mountain Silhouette Shape

struct MountainSilhouetteShape: Shape {
    enum Layer {
        case back, middle, front

        /// Normalized peak coordinates (x, y). X is allowed to go
        /// outside 0..1 so the ridgelines visually continue past the
        /// frame edges — the parent ZStack's .clipped() handles the
        /// trim. Y is from top (0) to bottom (1) — smaller y = taller.
        var peaks: [(x: CGFloat, y: CGFloat)] {
            switch self {
            case .back:
                return [
                    (-0.10, 0.55),
                    ( 0.10, 0.32),
                    ( 0.30, 0.48),
                    ( 0.50, 0.22),
                    ( 0.70, 0.45),
                    ( 0.90, 0.30),
                    ( 1.10, 0.50)
                ]
            case .middle:
                return [
                    (-0.10, 0.70),
                    ( 0.08, 0.42),
                    ( 0.25, 0.58),
                    ( 0.40, 0.30),
                    ( 0.55, 0.52),
                    ( 0.72, 0.35),
                    ( 0.88, 0.48),
                    ( 1.10, 0.62)
                ]
            case .front:
                return [
                    (-0.10, 0.85),
                    ( 0.08, 0.55),
                    ( 0.22, 0.72),
                    ( 0.36, 0.40),
                    ( 0.50, 0.66),
                    ( 0.65, 0.32),
                    ( 0.80, 0.60),
                    ( 0.94, 0.48),
                    ( 1.10, 0.75)
                ]
            }
        }

        /// Front layer is sharpest, back layer smoothest.
        var smoothness: CGFloat {
            switch self {
            case .back:   return 0.6
            case .middle: return 0.35
            case .front:  return 0.15
            }
        }
    }

    let layer: Layer

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let pts = layer.peaks.map {
            CGPoint(x: $0.x * rect.width, y: $0.y * rect.height)
        }
        let smoothness = layer.smoothness

        // Start at the bottom directly under the first peak — may be
        // off the left edge, which is fine because the parent clips.
        path.move(to: CGPoint(x: pts.first!.x, y: rect.height))
        path.addLine(to: pts[0])

        for i in 1..<pts.count {
            let prev = pts[i-1]
            let curr = pts[i]
            let midX = (prev.x + curr.x) / 2
            let lowerY = max(prev.y, curr.y)
            let controlY = lowerY + (rect.height - lowerY) * smoothness
            path.addQuadCurve(
                to: curr,
                control: CGPoint(x: midX, y: controlY)
            )
        }

        // Close at the bottom directly under the last peak — also
        // possibly past the right edge.
        path.addLine(to: CGPoint(x: pts.last!.x, y: rect.height))
        path.closeSubpath()
        return path
    }
}

#if DEBUG
#Preview("Ready") {
    BasecampMountainHero(mood: .ready)
        .background(DesignSystem.Colors.paperWarm)
}

#Preview("Rest") {
    BasecampMountainHero(mood: .rest)
        .background(DesignSystem.Colors.paperWarm)
}

#Preview("Caution") {
    BasecampMountainHero(mood: .caution)
        .background(DesignSystem.Colors.paperWarm)
}

#Preview("Ready Dark") {
    BasecampMountainHero(mood: .ready)
        .background(DesignSystem.Colors.paperWarm)
        .preferredColorScheme(.dark)
}
#endif
