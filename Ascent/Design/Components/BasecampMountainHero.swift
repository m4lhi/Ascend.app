import SwiftUI

// =========================================
// === DATEI: BasecampMountainHero.swift ===
// === Watercolor-image brand hero ===
// =========================================
//
// Replaces the vector silhouette + procedural sun hero from
// iterations 6/7 with an AI-generated watercolor image asset. The
// image carries the mountains, sun, and atmospheric haze; this
// view just frames it, blends the bottom into paperWarm, and adds
// a barely-there breathing animation.
//
// Public API is unchanged: `BasecampMountainHero(mood:)` is still
// the call site signature, so HealthDashboardView.swift does not
// need to change.

struct BasecampMountainHero: View {
    var mood: Mood = .ready

    @State private var hasAppeared = false
    @State private var breathScale: CGFloat = 1.0

    enum Mood {
        case ready, moderate, rest, caution

        /// Asset name in Assets.xcassets. Only `hero-ready` exists
        /// today — other moods fall back to it until variants are
        /// generated.
        var assetName: String {
            switch self {
            case .ready, .moderate:
                return "hero-ready"
            case .rest:
                return "hero-ready"  // TODO: generate hero-rest variant
            case .caution:
                return "hero-ready"  // TODO: generate hero-caution variant
            }
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {

            // Layer 1: the watercolor image, pinned to the bottom so
            // the natural mist/cream wash at the bottom of the asset
            // stays in view.
            Color.clear
                .frame(height: 200)
                .overlay(
                    Image(mood.assetName)
                        .resizable()
                        .scaledToFill()
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .scaleEffect(breathScale)
                        .opacity(hasAppeared ? 1.0 : 0.0)
                        .animation(.easeOut(duration: 1.4), value: hasAppeared),
                    alignment: .bottom
                )
                .clipped()

            // Layer 2: bottom blend — fade the last 70pt into paperWarm
            // so the seam to the page bg disappears even if the asset's
            // own bottom wash isn't an exact paperWarm match.
            LinearGradient(
                colors: [
                    DesignSystem.Colors.paperWarm.opacity(0),
                    DesignSystem.Colors.paperWarm.opacity(0.40),
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

            // Very subtle breathing — 1.015 reads more as a feeling
            // than as visible motion.
            withAnimation(
                .easeInOut(duration: 6.0).repeatForever(autoreverses: true)
            ) {
                breathScale = 1.015
            }
        }
    }
}

#if DEBUG
#Preview("Ready") {
    VStack(spacing: 0) {
        BasecampMountainHero(mood: .ready)
        Rectangle()
            .fill(DesignSystem.Colors.paperWarm)
            .frame(height: 200)
    }
    .background(DesignSystem.Colors.paperWarm)
}

#Preview("Ready Dark") {
    VStack(spacing: 0) {
        BasecampMountainHero(mood: .ready)
        Rectangle()
            .fill(DesignSystem.Colors.paperWarm)
            .frame(height: 200)
    }
    .background(DesignSystem.Colors.paperWarm)
    .preferredColorScheme(.dark)
}
#endif
