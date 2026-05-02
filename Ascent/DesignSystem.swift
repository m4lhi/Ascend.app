//
//  DesignSystem.swift
//  Ascent
//
//  Zentrale Design-Bibliothek der App.
//  Alle Farben, Abstände, Radien, Schatten und Animationen sind hier definiert.
//  Änderungen hier wirken sich automatisch auf die gesamte App aus.
//

import SwiftUI

// === Design System ===
// Enum ohne Cases = kann nicht instanziiert werden (reiner Namespace)
enum DesignSystem {

    // =========================================
    // === FARBEN ===
    // =========================================
    enum Colors {

        // Hauptakzentfarbe — Ascent Logo Blue
        static let accent = Color(red: 0.15, green: 0.50, blue: 1.00)       // #2680FF
        static let accentLight = Color(red: 0.37, green: 0.72, blue: 1.00)  // #5FB8FF
        static let accentDeep  = Color(red: 0.06, green: 0.33, blue: 0.80)  // #0F54CC

        // Prestige-Gold — für hohe Ränge und besondere Achievements
        static let prestige = Color(red: 0.95, green: 0.74, blue: 0.22)

        // Hintergrundfarben (systemadaptiv — funktioniert in Dark & Light Mode)
        static let background         = Color(.systemBackground)
        static let cardBackground     = Color(.secondarySystemBackground)
        static let elevatedBackground = Color(.tertiarySystemBackground)

        // Textfarben
        static let primaryText   = Color(.label)
        static let secondaryText = Color(.secondaryLabel)
        static let tertiaryText  = Color(.tertiaryLabel)

        // Statusfarben
        static let success = Color(.systemGreen)
        static let warning = Color(.systemOrange)
        static let error   = Color(.systemRed)

        // Gradient für Hero-Bereiche (Level-Karte, Header etc.)
        // Geht von dunklem Bergblau zu hellerem Akzentblau
        static let mountainGradient = LinearGradient(
            colors: [
                Color(red: 0.06, green: 0.33, blue: 0.80),
                Color(red: 0.15, green: 0.50, blue: 1.00),
                Color(red: 0.37, green: 0.72, blue: 1.00)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        // Brand gradient matching the Ascent logo exactly
        static let logoGradient = LinearGradient(
            colors: [
                Color(red: 0.40, green: 0.75, blue: 1.00),
                Color(red: 0.15, green: 0.50, blue: 1.00),
                Color(red: 0.06, green: 0.33, blue: 0.80)
            ],
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
    // =========================================
    // Konsistentes 8pt-Raster (Apple-Standard)
    enum Spacing {
        static let xs:  CGFloat = 4
        static let sm:  CGFloat = 8
        static let md:  CGFloat = 16
        static let lg:  CGFloat = 24
        static let xl:  CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // =========================================
    // === ECKENRADIEN ===
    // Bewusst großzügig — runde Elemente fühlen sich hochwertiger an
    // =========================================
    enum Radius {
        static let sm:   CGFloat = 10
        static let md:   CGFloat = 14
        static let lg:   CGFloat = 18
        static let xl:   CGFloat = 24
        static let xxl:  CGFloat = 32
        static let card: CGFloat = 28
        static let full: CGFloat = 999  // Für Pills / Capsules
    }

    // =========================================
    // === SCHATTEN ===
    // =========================================
    enum Shadow {
        // Karten-Schatten — weich, dezent
        static let card   = ShadowStyle(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
        // Subtiler Schatten — für kleine Elemente
        static let subtle = ShadowStyle(color: .black.opacity(0.05), radius:  6, x: 0, y: 2)
        // Akzent-Schatten — farbig, für Hero-Karten
        static let accent = ShadowStyle(color: Colors.accent.opacity(0.25), radius: 16, x: 0, y: 8)
        // Liquid Glass Glow — luminous halo for glass elements
        static let liquidGlow = ShadowStyle(color: .white.opacity(0.35), radius: 8, x: 0, y: -2)
    }

    // =========================================
    // === ANIMATIONEN ===
    // =========================================
    enum Animations {
        // Standard-Übergang für die meisten Views
        static let standard = Animation.spring(response: 0.4, dampingFraction: 0.82)

        // Schnelle Reaktion beim Antippen von Buttons
        static let quick    = Animation.spring(response: 0.25, dampingFraction: 0.70)

        // Weicher Panel-Übergang (z.B. Sheet öffnet sich)
        static let panel    = Animation.spring(response: 0.50, dampingFraction: 0.88)

        // Fortschrittsbalken füllt sich langsam
        static let progress = Animation.easeOut(duration: 1.2)

        // Pop-Effekt (z.B. Kartenmarker)
        static let pop      = Animation.spring(response: 0.35, dampingFraction: 0.55)
    }

    // =========================================
    // === TYPOGRAFIE ===
    // Einheitliche, weiche Schrift-Hierarchie
    // =========================================
    enum Typography {
        static let heroTitle    = Font.system(size: 34, weight: .bold, design: .rounded)
        static let title        = Font.system(size: 24, weight: .bold, design: .rounded)
        static let subtitle     = Font.system(size: 18, weight: .semibold, design: .rounded)
        static let body         = Font.system(size: 16, weight: .medium, design: .rounded)
        static let bodySecondary = Font.system(size: 15, weight: .regular, design: .rounded)
        static let caption      = Font.system(size: 13, weight: .medium, design: .rounded)
        static let micro        = Font.system(size: 11, weight: .semibold, design: .rounded)
    }
}

// === Schatten-Hilfsstruct ===
// Fasst Schattenparameter zusammen für saubere API
struct ShadowStyle {
    let color:  Color
    let radius: CGFloat
    let x:      CGFloat
    let y:      CGFloat
}

// =========================================
// === VIEW MODIFIER: ASCENT CARD ===
// =========================================
// Liquid Glass card for solid-background contexts — subtle glass with a
// light frosted fill that works over both light and dark backgrounds.
struct AscentCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.card)
                        .fill(.regularMaterial)
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.card)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.45), .white.opacity(0.08)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                    // Top specular strip
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.card)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.50), .clear],
                                startPoint: .top,
                                endPoint: UnitPoint(x: 0.5, y: 0.30)
                            )
                        )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.card)
                    .stroke(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(0.85), location: 0.0),
                                .init(color: .white.opacity(0.35), location: 0.40),
                                .init(color: .white.opacity(0.10), location: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            )
            .shadow(color: .black.opacity(0.08), radius: 14, x: 0, y: 5)
            .shadow(color: .black.opacity(0.04), radius: 3,  x: 0, y: 1)
    }
}

// =========================================
// === VIEW MODIFIER: LIQUID GLASS CARD ===
// =========================================
// Apple-style Liquid Glass — multi-layer frosted glass with specular highlights,
// luminous inner glow, and gradient stroke border.
struct GlassCardModifier: ViewModifier {
    var tint: Color = .white
    var cornerRadius: CGFloat = DesignSystem.Radius.card

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Layer 1: blur material base
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)

                    // Layer 2: luminous glass body
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: .white.opacity(0.30), location: 0.0),
                                    .init(color: tint.opacity(0.06),   location: 0.55),
                                    .init(color: .white.opacity(0.04), location: 1.0)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    // Layer 3: top specular highlight — the key "glass bubble" look
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.60), .white.opacity(0.18), .clear],
                                startPoint: .top,
                                endPoint: UnitPoint(x: 0.5, y: 0.38)
                            )
                        )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                // Gradient border — bright at top-left, fades toward bottom-right
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(0.88), location: 0.0),
                                .init(color: .white.opacity(0.50), location: 0.25),
                                .init(color: .white.opacity(0.20), location: 0.60),
                                .init(color: .white.opacity(0.05), location: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.0
                    )
            )
            .shadow(color: .black.opacity(0.10), radius: 18, x: 0, y: 7)
            .shadow(color: .black.opacity(0.05), radius: 4,  x: 0, y: 2)
    }
}

extension View {
    func ascentCard() -> some View {
        modifier(AscentCardModifier())
    }

    // Liquid Glass card — for elements over gradients/images
    func glassCard(tint: Color = .white) -> some View {
        modifier(GlassCardModifier(tint: tint))
    }

    // Liquid Glass with custom corner radius
    func liquidGlass(tint: Color = .white, cornerRadius: CGFloat = DesignSystem.Radius.card) -> some View {
        modifier(GlassCardModifier(tint: tint, cornerRadius: cornerRadius))
    }

    /// Plain solid card — Apple-Health-style content surface for lists/sections.
    /// Use for content that sits on a neutral background (not over imagery/gradients).
    /// Default radius `Radius.lg` (18), default padding `Spacing.md` (16).
    func sectionCard(
        padding: CGFloat = DesignSystem.Spacing.md,
        cornerRadius: CGFloat = DesignSystem.Radius.lg
    ) -> some View {
        self
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.black.opacity(0.04), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Section Header — Apple-style "Health" header
// Use above grouped content sections. Always title-case, with optional trailing accessory.
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
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            trailing()
        }
    }
}

// =========================================
// === BUTTON STYLE: ASCENT BUTTON ===
// =========================================
// Subtiler Druck-Effekt bei Tap — fühlt sich hochwertig an
struct AscentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.88 : 1.0)
            .animation(DesignSystem.Animations.quick, value: configuration.isPressed)
    }
}

// =========================================
// === BUTTON STYLE: PRIMARY BUTTON (Liquid Glass) ===
// =========================================
// Full-width CTA button with Liquid Glass treatment — gradient fill,
// specular highlight, gradient border, and colored glow shadow.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.app(.headline))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(DesignSystem.Spacing.md)
            .background(
                ZStack {
                    // Gradient fill
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                        .fill(DesignSystem.Colors.mountainGradient)
                    // Specular top shine
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.38), .clear],
                                startPoint: .top,
                                endPoint: UnitPoint(x: 0.5, y: 0.42)
                            )
                        )
                    // Bottom glass reflection
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                        .fill(
                            LinearGradient(
                                colors: [.clear, .white.opacity(0.10)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.75), .white.opacity(0.15)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            )
            .shadow(
                color: DesignSystem.Colors.accent.opacity(configuration.isPressed ? 0.18 : 0.42),
                radius: configuration.isPressed ? 5 : 18,
                x: 0, y: configuration.isPressed ? 2 : 8
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .brightness(configuration.isPressed ? -0.04 : 0)
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
// === BUTTON STYLE: LIQUID GLASS BUTTON ===
// =========================================
// Secondary/tertiary glass button — frosted glass look with specular shine.
// Use for icon buttons, chips, and non-primary actions.
struct LiquidGlassButtonStyle: ButtonStyle {
    var tint: Color = .white
    var cornerRadius: CGFloat = DesignSystem.Radius.lg

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.45), tint.opacity(0.06), .white.opacity(0.05)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.55), .clear],
                                startPoint: .top,
                                endPoint: UnitPoint(x: 0.5, y: 0.35)
                            )
                        )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(0.85), location: 0.0),
                                .init(color: .white.opacity(0.40), location: 0.30),
                                .init(color: .white.opacity(0.10), location: 1.0)
                            ],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            )
            .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .brightness(configuration.isPressed ? -0.04 : 0)
            .animation(DesignSystem.Animations.quick, value: configuration.isPressed)
    }
}

// =========================================
// === GLOBAL ROUNDED FONT MODIFIER ===
// =========================================
// Applies SF Pro Rounded (Gentler Streak style) to ALL text in the view hierarchy.
// Attach once at the app root to affect every screen.

struct RoundedFontDesignModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .environment(\.font, .system(.body, design: .rounded))
    }
}

extension View {
    func roundedFontDesign() -> some View {
        modifier(RoundedFontDesignModifier())
    }
}

// MARK: - Adaptive sheet glass background
// iOS 26: let the system apply native Liquid Glass automatically.
// iOS < 26: apply ultraThinMaterial as fallback.
extension View {
    @ViewBuilder
    func adaptiveSheetBackground() -> some View {
        if #available(iOS 26, *) {
            self
        } else {
            self.presentationBackground(.ultraThinMaterial)
        }
    }

    /// One-call sheet polish: corner radius, adaptive glass background, and
    /// background-interaction enabled so the parent stays alive behind the sheet.
    /// Use as the LAST modifier on any sheet root view for consistent feel.
    @ViewBuilder
    func ascentSheet(detents: Set<PresentationDetent> = [.large]) -> some View {
        self
            .presentationDetents(detents)
            .presentationCornerRadius(36)
            .adaptiveSheetBackground()
            .presentationBackgroundInteraction(.enabled(upThrough: .large))
            .preferredColorScheme(.light)
    }
}

// MARK: - Polished sheet header
// Consistent close button + optional title that all our sheets can use.
// Drop-in replacement for hand-rolled NavigationView toolbar setups.
struct AscentSheetHeader: View {
    let title: String
    var subtitle: String?
    var onClose: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
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

// MARK: - Polished section divider strip
// 1pt translucent rule with a subtle gradient — drops into any list-style content.
struct AscentDivider: View {
    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [Color.black.opacity(0.0), Color.black.opacity(0.08), Color.black.opacity(0.0)],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .frame(height: 0.5)
    }
}
