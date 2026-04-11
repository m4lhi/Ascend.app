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
        static let card: CGFloat = 20
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
// Einheitliches Karten-Styling — einfach .ascentCard() an jede View hängen
struct AscentCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(DesignSystem.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
            .shadow(
                color:  DesignSystem.Shadow.card.color,
                radius: DesignSystem.Shadow.card.radius,
                x:      DesignSystem.Shadow.card.x,
                y:      DesignSystem.Shadow.card.y
            )
    }
}

// =========================================
// === VIEW MODIFIER: GLASS CARD ===
// =========================================
// Glasoptik — moderner Frosted-Glass-Effekt für Karten über farbigen Hintergründen
struct GlassCardModifier: ViewModifier {
    var tint: Color = .white

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.card)
                    .stroke(tint.opacity(0.18), lineWidth: 0.8)
            )
    }
}

extension View {
    func ascentCard() -> some View {
        modifier(AscentCardModifier())
    }

    // Glasoptik-Karte — für Elemente über Gradienten
    func glassCard(tint: Color = .white) -> some View {
        modifier(GlassCardModifier(tint: tint))
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
// === BUTTON STYLE: PRIMARY BUTTON ===
// =========================================
// Gefüllter CTA-Button (z.B. "Tour loggen")
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(DesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                    .fill(DesignSystem.Colors.mountainGradient)
                    .shadow(
                        color:  DesignSystem.Shadow.accent.color,
                        radius: configuration.isPressed ? 4 : DesignSystem.Shadow.accent.radius,
                        x:      DesignSystem.Shadow.accent.x,
                        y:      configuration.isPressed ? 2 : DesignSystem.Shadow.accent.y
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
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
