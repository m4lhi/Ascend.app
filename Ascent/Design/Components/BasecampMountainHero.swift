import SwiftUI
import UIKit

// =========================================
// === DATEI: BasecampMountainHero.swift ===
// === Image-asset brand hero (size-agnostic) ===
// =========================================
//
// Renders the character hero asset for the Basecamp main screen.
// Size is owned by the caller (.frame(...) on the outside).
//
// Two unsynchronized animations: a 3.5s breath scale (1.0 ↔ 1.03)
// and a 4.2s float offset (0 ↔ -3pt). Different periods on purpose
// — synced loops read as mechanical bouncing; phase-shifted loops
// read as alive.

struct BasecampMountainHero: View {
    var mood: Mood = .ready

    @State private var hasAppeared = false
    @State private var breathScale: CGFloat = 1.0
    @State private var floatOffset: CGFloat = 0

    enum Mood {
        case ready, moderate, rest, caution

        /// Asset name in Assets.xcassets. Each mood points at its own
        /// variant; if the variant isn't registered yet, fall back to
        /// `hero-ready` so we never show an empty Image at runtime.
        var assetName: String {
            let preferred: String
            switch self {
            case .ready, .moderate: preferred = "hero-ready"
            case .rest:             preferred = "hero-rest"
            case .caution:          preferred = "hero-caution"
            }
            return UIImage(named: preferred) != nil ? preferred : "hero-ready"
        }
    }

    var body: some View {
        Image(mood.assetName)
            .resizable()
            .scaledToFit()
            .scaleEffect(breathScale)
            .offset(y: floatOffset)
            .opacity(hasAppeared ? 1.0 : 0.0)
            .animation(.easeOut(duration: 0.8), value: hasAppeared)
            .animation(.easeInOut(duration: 0.4), value: mood)
            .onAppear {
                hasAppeared = true

                // Subtle breath — gentle scale loop.
                withAnimation(
                    .easeInOut(duration: 3.5).repeatForever(autoreverses: true)
                ) {
                    breathScale = 1.03
                }

                // Subtle float — vertical drift. Different period from
                // breath so the loops don't sync up.
                withAnimation(
                    .easeInOut(duration: 4.2).repeatForever(autoreverses: true)
                ) {
                    floatOffset = -3
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
