import SwiftUI

// =========================================
// === DATEI: Tokens+Ascent.swift ===
// === Gentler-Streak-flavoured design tokens ===
// =========================================
//
// New tokens for the BasecampScreen redesign. Sit alongside the
// existing dark-pink Outsiders tokens in DesignSystem.swift — those
// stay untouched (50+ consumers across the app). The new tokens use
// light/dark adaptive Colors and intentionally suffix typography
// variants with "Inter" so they can't collide with the legacy names.

// MARK: - Adaptive Color helper

extension Color {
    /// Light-/dark-mode adaptive Color. Bridged via UIColor.
    fileprivate static func ascentAdaptive(light: Color, dark: Color) -> Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}

// MARK: - Color tokens

extension DesignSystem.Colors {
    /// Warm cream-off-white app background. Light: #EDEEE7, Dark: #141814.
    static let paperWarm = Color.ascentAdaptive(
        light: Color(red: 0.929, green: 0.933, blue: 0.906),
        dark:  Color(red: 0.078, green: 0.094, blue: 0.078)
    )

    /// Sage-mint pastel card background — Erholung / Recovery family.
    static let sageCard = Color.ascentAdaptive(
        light: Color(red: 0.851, green: 0.886, blue: 0.851),
        dark:  Color(red: 0.122, green: 0.165, blue: 0.118)
    )

    /// Ice-glacier pastel card background — Wetter / Weather family.
    static let iceGlacierCard = Color.ascentAdaptive(
        light: Color(red: 0.835, green: 0.871, blue: 0.886),
        dark:  Color(red: 0.118, green: 0.165, blue: 0.188)
    )

    /// Warm sand card background — Featured / Empfehlung family.
    static let sandCard = Color.ascentAdaptive(
        light: Color(red: 0.922, green: 0.875, blue: 0.800),
        dark:  Color(red: 0.180, green: 0.149, blue: 0.094))

    /// Text on sageCard — dark warm sage.
    static let inkOnSage = Color.ascentAdaptive(
        light: Color(red: 0.169, green: 0.239, blue: 0.180),
        dark:  Color(red: 0.851, green: 0.886, blue: 0.851)
    )

    /// Text on iceGlacierCard — deep cool slate.
    static let inkOnIce = Color.ascentAdaptive(
        light: Color(red: 0.235, green: 0.353, blue: 0.400),
        dark:  Color(red: 0.835, green: 0.871, blue: 0.886)
    )

    /// Text on sandCard — dark warm brown.
    static let inkOnSand = Color.ascentAdaptive(
        light: Color(red: 0.239, green: 0.180, blue: 0.118),
        dark:  Color(red: 0.922, green: 0.875, blue: 0.800)
    )

    /// Glacier — kühler Hauptakzent (Links, Interactivity).
    static let glacierDeep = Color.ascentAdaptive(
        light: Color(red: 0.180, green: 0.486, blue: 0.573),
        dark:  Color(red: 0.357, green: 0.663, blue: 0.753)
    )

    /// Ember — sparingly used danger / caution accent. Per the design
    /// system constitution: #C44A3F light / #E47A6A dark.
    static let ember = Color.ascentAdaptive(
        light: Color(red: 0.769, green: 0.290, blue: 0.247),
        dark:  Color(red: 0.894, green: 0.478, blue: 0.416)
    )

    /// Alpenglow — warmer Akzent (Ready / Featured CTA).
    static let alpenglow = Color.ascentAdaptive(
        light: Color(red: 0.910, green: 0.608, blue: 0.369),
        dark:  Color(red: 0.941, green: 0.675, blue: 0.482)
    )

    /// Tertiary / Kicker text on paperWarm.
    static let inkFaintWarm = Color.ascentAdaptive(
        light: Color(red: 0.435, green: 0.443, blue: 0.404),
        dark:  Color(red: 0.514, green: 0.522, blue: 0.482)
    )

    /// Primary text on paperWarm — warm slate, never pure black.
    static let inkWarm = Color.ascentAdaptive(
        light: Color(red: 0.118, green: 0.149, blue: 0.122),
        dark:  Color(red: 0.910, green: 0.918, blue: 0.882)
    )
}

// MARK: - Typography (Inter, with safe SF-Pro fallback)
//
// Inter Variable isn't registered in the bundle yet. `Font.custom`
// falls back to SF Pro automatically when the family isn't found,
// so layout is correct now and switches to Inter the moment Kumpel
// drops the .ttf into Resources/Fonts + Info.plist's UIAppFonts.

extension DesignSystem.Typography {
    static var displayInter: Font  { Font.custom("Inter", size: 32).weight(.semibold) }
    static var title1Inter: Font   { Font.custom("Inter", size: 28).weight(.semibold) }
    static var title2Inter: Font   { Font.custom("Inter", size: 22).weight(.semibold) }
    static var title3Inter: Font   { Font.custom("Inter", size: 18).weight(.medium) }
    static var bodyEmphasisInter: Font { Font.custom("Inter", size: 16).weight(.medium) }
    static var bodyInter: Font     { Font.custom("Inter", size: 16).weight(.regular) }
    static var subheadInter: Font  { Font.custom("Inter", size: 14).weight(.regular) }
    static var footnoteInter: Font { Font.custom("Inter", size: 13).weight(.regular) }
    static var kickerInter: Font   { Font.custom("Inter", size: 11).weight(.medium) }
}

// MARK: - Radius

extension DesignSystem.Radius {
    /// 28pt — Gentler-Streak pillow-soft card radius. Used by the new
    /// BasecampScreen bento + featured cards. Legacy 20pt `card` stays
    /// the default elsewhere.
    static let cardSoft: CGFloat = 28
}

// MARK: - Pastel Card Modifier
//
// Gentler-Streak-flavoured card wrapper. Picks a pastel background +
// matching ink color from the new tokens. Drop-in replacement for the
// legacy `.ascentCard(...)` modifier on a per-widget basis.

enum PastelFamily {
    case sage
    case ice
    case sand

    var background: Color {
        switch self {
        case .sage: return DesignSystem.Colors.sageCard
        case .ice:  return DesignSystem.Colors.iceGlacierCard
        case .sand: return DesignSystem.Colors.sandCard
        }
    }

    var ink: Color {
        switch self {
        case .sage: return DesignSystem.Colors.inkOnSage
        case .ice:  return DesignSystem.Colors.inkOnIce
        case .sand: return DesignSystem.Colors.inkOnSand
        }
    }
}

extension View {
    /// Pastel pillow-soft card. 28pt radius, no border, no shadow.
    /// `applyForeground` (default true) sets the matching ink color
    /// on descendants — turn it off if a widget needs to mix multiple
    /// text colors itself.
    func pastelCard(_ family: PastelFamily,
                    padding: CGFloat = 16,
                    applyForeground: Bool = true) -> some View {
        Group {
            if applyForeground {
                self
                    .foregroundStyle(family.ink)
                    .padding(padding)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.cardSoft, style: .continuous)
                            .fill(family.background)
                    )
            } else {
                self
                    .padding(padding)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.cardSoft, style: .continuous)
                            .fill(family.background)
                    )
            }
        }
    }
}
