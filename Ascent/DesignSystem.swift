//
//  DesignSystem.swift
//  Ascent
//
//  Zentrale Design-Bibliothek der App.
//  Flat, premium, monochromatic blue. Light-mode primary, dark-mode adaptive.
//  No gradient noise, no glass overload — confidence through restraint.
//

import SwiftUI

// === Design System ===
enum DesignSystem {

    // =========================================
    // === FARBEN ===
    // =========================================
    enum Colors {

        // --- BRAND BLUE (single source of truth) ---
        static let accent       = Color(red: 0.15, green: 0.50, blue: 1.00) // #2680FF
        static let accentLight  = Color(red: 0.37, green: 0.72, blue: 1.00) // #5FB8FF
        static let accentDeep   = Color(red: 0.06, green: 0.33, blue: 0.80) // #0F54CC
        static let accentSoft   = Color(red: 0.92, green: 0.95, blue: 1.00) // background tint (light)
        static let accentTint   = Color(red: 0.96, green: 0.98, blue: 1.00) // ultra-light wash

        // Dark-mode adaptive sub-tone (subtle blue glow on cards in dark)
        static let accentGlow = Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.30, green: 0.55, blue: 1.00, alpha: 1.0)
                : UIColor(red: 0.15, green: 0.50, blue: 1.00, alpha: 1.0)
        })

        // Prestige-Gold — für hohe Ränge und besondere Achievements
        static let prestige = Color(red: 0.95, green: 0.74, blue: 0.22)

        // --- SURFACES (adaptive Light/Dark) ---
        static let background        = Color(.systemBackground)
        static let surface           = Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.08, green: 0.09, blue: 0.12, alpha: 1.0)
                : UIColor.white
        })
        static let surfaceElevated   = Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.11, green: 0.12, blue: 0.16, alpha: 1.0)
                : UIColor.white
        })
        static let surfaceMuted      = Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.06, green: 0.07, blue: 0.10, alpha: 1.0)
                : UIColor(red: 0.97, green: 0.97, blue: 0.98, alpha: 1.0)
        })

        // Card background — flat, adaptive
        static let cardBackground = surfaceElevated
        static let elevatedBackground = surfaceElevated

        // Subtle border for cards (very low contrast)
        static let cardBorder = Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor.white.withAlphaComponent(0.08)
                : UIColor.black.withAlphaComponent(0.06)
        })

        // Textfarben
        static let primaryText   = Color(.label)
        static let secondaryText = Color(.secondaryLabel)
        static let tertiaryText  = Color(.tertiaryLabel)

        // Statusfarben
        static let success = Color(.systemGreen)
        static let warning = Color(.systemOrange)
        static let error   = Color(.systemRed)

        // --- LEGACY GRADIENT TOKENS (retained for back-compat, now FLAT) ---
        // Replaced multi-stop gradients with subtle 2-stop tonal shifts.
        // Visually reads as a solid blue with a hint of depth.
        static let mountainGradient = LinearGradient(
            colors: [accent, accentDeep],
            startPoint: .top,
            endPoint: .bottom
        )

        static let logoGradient = LinearGradient(
            colors: [accent, accentDeep],
            startPoint: .top,
            endPoint: .bottom
        )

        // Schwierigkeitsgrad-Farben
        static func difficultyColor(_ difficulty: String) -> Color {
            switch difficulty {
            case "Leicht":  return .systemGreen
            case "Mittel":  return .systemOrange
            case "Schwer":  return Color(red: 0.85, green: 0.2, blue: 0.2)
            case "Extrem":  return Color(red: 0.55, green: 0.0, blue: 0.55)
            default:        return Color(.secondaryLabel)
            }
        }
    }

    // =========================================
    // === ABSTÄNDE ===
    // 8pt-Raster, plus generous tokens for premium whitespace
    // =========================================
    enum Spacing {
        static let xs:   CGFloat = 4
        static let sm:   CGFloat = 8
        static let md:   CGFloat = 16
        static let lg:   CGFloat = 24
        static let xl:   CGFloat = 32
        static let xxl:  CGFloat = 48
        static let xxxl: CGFloat = 64

        // New "premium" tokens — use for hero sections and breathing room
        static let cardPadding: CGFloat = 20
        static let sectionGap:  CGFloat = 28
        static let screenInset: CGFloat = 20
    }

    // =========================================
    // === ECKENRADIEN ===
    // =========================================
    enum Radius {
        static let sm:   CGFloat = 10
        static let md:   CGFloat = 14
        static let lg:   CGFloat = 18
        static let xl:   CGFloat = 22
        static let xxl:  CGFloat = 28
        static let card: CGFloat = 22
        static let full: CGFloat = 999
    }

    // =========================================
    // === SCHATTEN — single soft shadow per element ===
    // =========================================
    enum Shadow {
        static let card   = ShadowStyle(color: .black.opacity(0.06), radius: 16, x: 0, y: 6)
        static let subtle = ShadowStyle(color: .black.opacity(0.04), radius: 8,  x: 0, y: 2)
        static let accent = ShadowStyle(color: Colors.accent.opacity(0.22), radius: 18, x: 0, y: 8)
        static let liquidGlow = ShadowStyle(color: Colors.accent.opacity(0.15), radius: 12, x: 0, y: 4)
    }

    // =========================================
    // === ANIMATIONEN ===
    // =========================================
    enum Animations {
        static let standard = Animation.spring(response: 0.4, dampingFraction: 0.85)
        static let quick    = Animation.spring(response: 0.25, dampingFraction: 0.75)
        static let panel    = Animation.spring(response: 0.50, dampingFraction: 0.88)
        static let progress = Animation.easeOut(duration: 1.0)
        static let pop      = Animation.spring(response: 0.35, dampingFraction: 0.65)
    }

    // =========================================
    // === TYPOGRAFIE ===
    // =========================================
    enum Typography {
        static let heroTitle    = Font.app(size: 34, weight: .black)
        static let title        = Font.app(size: 26, weight: .bold)
        static let subtitle     = Font.app(size: 18, weight: .semibold)
        static let body         = Font.app(size: 16, weight: .regular)
        static let bodySecondary = Font.app(size: 15, weight: .regular)
        static let caption      = Font.app(size: 13, weight: .medium)
        static let micro        = Font.app(size: 11, weight: .semibold)
    }
}

// === Schatten-Hilfsstruct ===
struct ShadowStyle {
    let color:  Color
    let radius: CGFloat
    let x:      CGFloat
    let y:      CGFloat
}

// =========================================
// === VIEW MODIFIER: ASCENT CARD ===
// Flat, premium card. Solid surface, subtle border, single soft shadow.
// Adaptive in light/dark. The card you reach for 90% of the time.
// =========================================
struct AscentCardModifier: ViewModifier {
    var cornerRadius: CGFloat = DesignSystem.Radius.card

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Solid surface
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(DesignSystem.Colors.surfaceElevated)
                    // Subtle top highlight — reads as "real surface lit from above"
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.55), .clear],
                                startPoint: .top,
                                endPoint: UnitPoint(x: 0.5, y: 0.35)
                            )
                        )
                        .blendMode(.plusLighter)
                        .opacity(0.45)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(DesignSystem.Colors.cardBorder, lineWidth: 0.75)
            )
            .shadow(color: .black.opacity(0.06), radius: 16, x: 0, y: 6)
            .shadow(color: .black.opacity(0.03), radius: 3,  x: 0, y: 1)
    }
}

// =========================================
// === VIEW MODIFIER: GLASS CARD (used over imagery) ===
// Single material layer, subtle border. No specular layers.
// =========================================
struct GlassCardModifier: ViewModifier {
    var tint: Color = .white
    var cornerRadius: CGFloat = DesignSystem.Radius.card

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.75)
            )
            .shadow(color: .black.opacity(0.10), radius: 12, x: 0, y: 4)
    }
}

extension View {
    /// Primary card — flat solid surface. Use for 90% of cards.
    func ascentCard(cornerRadius: CGFloat = DesignSystem.Radius.card) -> some View {
        modifier(AscentCardModifier(cornerRadius: cornerRadius))
    }

    /// Glass card — only over images/photos. Otherwise use `ascentCard`.
    func glassCard(tint: Color = .white) -> some View {
        modifier(GlassCardModifier(tint: tint))
    }

    /// Glass card with custom corner radius.
    func liquidGlass(tint: Color = .white, cornerRadius: CGFloat = DesignSystem.Radius.card) -> some View {
        modifier(GlassCardModifier(tint: tint, cornerRadius: cornerRadius))
    }

    /// Section card — Apple-Health-style content surface.
    func sectionCard(
        padding: CGFloat = DesignSystem.Spacing.cardPadding,
        cornerRadius: CGFloat = DesignSystem.Radius.lg
    ) -> some View {
        self
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(DesignSystem.Colors.surfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(DesignSystem.Colors.cardBorder, lineWidth: 0.75)
            )
            .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 3)
    }

    /// Subtle blue-tinted card for accent emphasis (premium hero in light mode,
    /// soft glow in dark mode).
    func ascentAccentCard(cornerRadius: CGFloat = DesignSystem.Radius.card) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(DesignSystem.Colors.accentSoft)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(DesignSystem.Colors.accent.opacity(0.18), lineWidth: 0.75)
            )
            .shadow(color: DesignSystem.Colors.accent.opacity(0.10), radius: 14, x: 0, y: 6)
    }
}

// MARK: - Section Header — Apple-style "Health" header
struct SectionHeader<Trailing: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder let trailing: () -> Trailing

    init(_ title: String, subtitle: String? = nil, @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.app(size: 22, weight: .bold))
                    .foregroundColor(.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(.app(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            trailing()
        }
    }
}

// =========================================
// === BUTTON STYLE: ASCENT BUTTON (subtle press) ===
// =========================================
struct AscentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(DesignSystem.Animations.quick, value: configuration.isPressed)
    }
}

// =========================================
// === BUTTON STYLE: PRIMARY BUTTON ===
// Flat capsule. Solid blue. Single soft shadow. No gradient.
// =========================================
struct PrimaryButtonStyle: ButtonStyle {
    var fillColor: Color = DesignSystem.Colors.accent
    var cornerRadius: CGFloat = DesignSystem.Radius.full

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.app(size: 17, weight: .bold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fillColor)
            )
            .shadow(
                color: fillColor.opacity(configuration.isPressed ? 0.12 : 0.28),
                radius: configuration.isPressed ? 4 : 12,
                x: 0,
                y: configuration.isPressed ? 1 : 6
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .brightness(configuration.isPressed ? -0.05 : 0)
            .animation(DesignSystem.Animations.quick, value: configuration.isPressed)
    }
}

// =========================================
// === EXTENSION: COLOR (System-Farben) ===
// =========================================
extension Color {
    static let systemGreen  = Color(.systemGreen)
    static let systemOrange = Color(.systemOrange)
    static let systemRed    = Color(.systemRed)
}

// =========================================
// === BUTTON STYLE: SECONDARY (Outline) ===
// Flat secondary button — outlined, transparent fill.
// =========================================
struct SecondaryButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = DesignSystem.Radius.full

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.app(size: 16, weight: .semibold))
            .foregroundColor(DesignSystem.Colors.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(DesignSystem.Colors.accentSoft)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(DesignSystem.Colors.accent.opacity(0.20), lineWidth: 0.75)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(DesignSystem.Animations.quick, value: configuration.isPressed)
    }
}

// =========================================
// === BUTTON STYLE: LIQUID GLASS BUTTON ===
// Flat material chip — used for icon buttons, pills, secondary actions.
// =========================================
struct LiquidGlassButtonStyle: ButtonStyle {
    var tint: Color = .white
    var cornerRadius: CGFloat = DesignSystem.Radius.lg

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.75)
            )
            .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(DesignSystem.Animations.quick, value: configuration.isPressed)
    }
}

// =========================================
// === GLOBAL ROUNDED FONT MODIFIER (no-op) ===
// Pass-through. Was overriding CabinetGrotesk/Satoshi — now disabled.
// Kept for back-compat with existing call sites.
// =========================================
struct RoundedFontDesignModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
    }
}

extension View {
    func roundedFontDesign() -> some View {
        modifier(RoundedFontDesignModifier())
    }
}

// MARK: - Adaptive sheet glass background
extension View {
    @ViewBuilder
    func adaptiveSheetBackground() -> some View {
        if #available(iOS 26, *) {
            self
        } else {
            self.presentationBackground(.ultraThinMaterial)
        }
    }

    /// One-call sheet polish.
    @ViewBuilder
    func ascentSheet(detents: Set<PresentationDetent> = [.large]) -> some View {
        self
            .presentationDetents(detents)
            .presentationCornerRadius(28)
            .adaptiveSheetBackground()
            .presentationBackgroundInteraction(.enabled(upThrough: .large))
    }
}

// MARK: - Polished sheet header
struct AscentSheetHeader: View {
    let title: String
    var subtitle: String?
    var onClose: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.app(size: 22, weight: .bold))
                if let subtitle {
                    Text(subtitle)
                        .font(.app(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(.secondary)
                    .frame(width: 30, height: 30)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.top, DesignSystem.Spacing.md)
        .padding(.bottom, DesignSystem.Spacing.sm)
    }
}

// MARK: - Polished section divider
struct AscentDivider: View {
    var body: some View {
        Rectangle()
            .fill(DesignSystem.Colors.cardBorder)
            .frame(height: 0.5)
    }
}
