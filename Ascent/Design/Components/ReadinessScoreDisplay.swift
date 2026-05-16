import SwiftUI

// =========================================
// === DATEI: ReadinessScoreDisplay.swift ===
// === Big-format topographic readiness display ===
// =========================================
//
// 280pt-tall variant of ReadinessHero. Reuses ContourRingShape
// (declared in ReadinessHero.swift) but with a larger ring set,
// adds a count-up score number in the center and a status word
// underneath. Glow size & color scale with the score.

struct ReadinessScoreDisplay: View {
    let score: Int
    let status: String

    @State private var hasAppeared = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var animatedScore: Int = 0

    private var glowColor: Color {
        switch score {
        case 75...100: return DesignSystem.Colors.alpenglow
        case 50..<75:  return DesignSystem.Colors.alpenglow.opacity(0.8)
        case 25..<50:  return DesignSystem.Colors.glacierDeep
        default:       return DesignSystem.Colors.glacierDeep.opacity(0.7)
        }
    }

    /// 0..100 → 50..130. Higher score = larger glow halo.
    private var glowRadius: CGFloat {
        50 + (CGFloat(score) / 100.0) * 80
    }

    var body: some View {
        ZStack {
            // Layer 1: score-scaled radial glow — breathes on 4s loop.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            glowColor.opacity(0.55),
                            glowColor.opacity(0.22),
                            glowColor.opacity(0.06),
                            .clear
                        ],
                        center: .center,
                        startRadius: 8,
                        endRadius: glowRadius
                    )
                )
                .frame(width: 260, height: 260)
                .scaleEffect(pulseScale)
                .opacity(hasAppeared ? 1.0 : 0.0)
                .animation(.easeOut(duration: 1.4).delay(0.2), value: hasAppeared)

            // Layer 2: larger contour rings.
            ZStack {
                ForEach(Array(largeRingConfigs.enumerated()), id: \.offset) { index, config in
                    ContourRingShape(seed: index)
                        .stroke(
                            DesignSystem.Colors.glacierDeep.opacity(config.opacity),
                            style: StrokeStyle(lineWidth: 0.9, lineCap: .round, lineJoin: .round)
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

            // Layer 3: count-up score + status word.
            VStack(spacing: DesignSystem.Spacing.xs) {
                Text("\(animatedScore)")
                    .font(.custom("Inter", size: 64).weight(.semibold))
                    .foregroundStyle(DesignSystem.Colors.inkWarm)
                    .monospacedDigit()
                    .opacity(hasAppeared ? 1.0 : 0.0)
                    .animation(.easeOut(duration: 0.5).delay(0.6), value: hasAppeared)

                Text(status)
                    .font(DesignSystem.Typography.title3Inter)
                    .foregroundStyle(DesignSystem.Colors.inkWarm.opacity(0.62))
                    .opacity(hasAppeared ? 1.0 : 0.0)
                    .animation(.easeOut(duration: 0.5).delay(0.8), value: hasAppeared)
            }
        }
        .frame(height: 280)
        .frame(maxWidth: .infinity)
        .onAppear {
            hasAppeared = true

            // Count 0 → score over 1.2s, starting at +0.6s so it lines
            // up with the number's own fade-in.
            let steps = 30
            let duration: Double = 1.2
            let stepDuration = duration / Double(steps)
            for step in 0...steps {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6 + stepDuration * Double(step)) {
                    animatedScore = Int(Double(score) * (Double(step) / Double(steps)))
                }
            }

            // Glow breathing loop.
            withAnimation(
                .easeInOut(duration: 4.0).repeatForever(autoreverses: true)
            ) {
                pulseScale = 1.05
            }
        }
    }

    private var largeRingConfigs: [(width: CGFloat, height: CGFloat, opacity: Double)] {
        [
            (380, 260, 0.10),
            (315, 215, 0.16),
            (255, 175, 0.24),
            (200, 135, 0.32),
            (150, 102, 0.42),
            (105, 70,  0.54)
        ]
    }
}

#if DEBUG
#Preview("Score 87") {
    ReadinessScoreDisplay(score: 87, status: "Peak Readiness")
        .background(DesignSystem.Colors.paperWarm)
}

#Preview("Score 42") {
    ReadinessScoreDisplay(score: 42, status: "Caution Required")
        .background(DesignSystem.Colors.paperWarm)
}

#Preview("Score 42 Dark") {
    ReadinessScoreDisplay(score: 42, status: "Caution Required")
        .background(DesignSystem.Colors.paperWarm)
        .preferredColorScheme(.dark)
}
#endif
