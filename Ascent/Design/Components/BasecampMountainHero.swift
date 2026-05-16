import SwiftUI

// =========================================
// === DATEI: BasecampMountainHero.swift ===
// === Image-asset brand hero (size-agnostic) ===
// =========================================
//
// Renders the watercolor / character hero asset for the Basecamp
// main screen. Size is owned by the caller (.frame(...) on the
// outside) so the same component works as a 110×130 portrait next
// to the greeting OR as a full-width landscape banner — whichever
// the layout calls for.
//
// All atmospheric framing (fixed height, bottom-fade gradient,
// horizon blend) was removed in iteration 11 because the new
// composition treats the hero as an L-shape companion to the
// greeting block, not as a full-bleed banner.

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
        Image(mood.assetName)
            .resizable()
            .scaledToFit()
            .scaleEffect(breathScale)
            .opacity(hasAppeared ? 1.0 : 0.0)
            .animation(.easeOut(duration: 1.4), value: hasAppeared)
            .onAppear {
                hasAppeared = true
                withAnimation(
                    .easeInOut(duration: 6.0).repeatForever(autoreverses: true)
                ) {
                    breathScale = 1.015
                }
            }
    }
}

#if DEBUG
#Preview("Portrait 110×130") {
    BasecampMountainHero(mood: .ready)
        .frame(width: 110, height: 130)
        .background(DesignSystem.Colors.paperWarm)
}

#Preview("Full-width 200") {
    BasecampMountainHero(mood: .ready)
        .frame(height: 200)
        .background(DesignSystem.Colors.paperWarm)
}

#Preview("Portrait Dark") {
    BasecampMountainHero(mood: .ready)
        .frame(width: 110, height: 130)
        .background(DesignSystem.Colors.paperWarm)
        .preferredColorScheme(.dark)
}
#endif
