//
//  DesignSystem.swift
//  Ascent
//
//  Dark-first, pink accent, metric-specific atmosphere colors.
//  Inspired by The Outsiders. No shadows. Ultra-thin borders. Flat surfaces.
//

import SwiftUI

// === Design System ===
enum DesignSystem {

    // =========================================
    // === FARBEN ===
    // =========================================
    enum Colors {

        // --- BRAND PINK / MAGENTA (Outsiders-inspired) ---
        static let accent      = Color(red: 1.00, green: 0.18, blue: 0.33) // #FF2D55
        static let accentLight = Color(red: 1.00, green: 0.42, blue: 0.55) // lighter for highlights
        static let accentDeep  = Color(red: 0.75, green: 0.10, blue: 0.22) // darker for depth
        static let accentSoft  = Color(red: 0.15, green: 0.05, blue: 0.08) // dark-mode pink tint
        static let accentTint  = Color(red: 0.10, green: 0.03, blue: 0.05) // ultra-subtle wash

        static let accentGlow  = Color(red: 1.00, green: 0.30, blue: 0.45)

        // Prestige-Gold
        static let prestige = Color(red: 0.95, green: 0.74, blue: 0.22)

        // --- METRIC ATMOSPHERE COLORS (Outsiders signature) ---
        static let metricLoad      = Color(red: 0.00, green: 0.78, blue: 1.00) // Cyan — Training Load
        static let metricDuration  = Color(red: 1.00, green: 0.84, blue: 0.04) // Gold — Duration
        static let metricDistance  = Color(red: 0.19, green: 0.82, blue: 0.35) // Green — Distance
        static let metricElevation = Color(red: 0.39, green: 0.82, blue: 0.69) // Teal — Elevation
        static let metricEnergy    = Color(red: 1.00, green: 0.62, blue: 0.04) // Orange — Energy
        static let metricHeart     = Color(red: 1.00, green: 0.27, blue: 0.27) // Red — Heart Rate
        static let metricSleep     = Color(red: 0.55, green: 0.36, blue: 0.96) // Purple — Sleep
        static let metricOxygen    = Color(red: 0.35, green: 0.68, blue: 1.00) // Blue — SpO2
        static let metricHRV       = Color(red: 0.40, green: 0.85, blue: 0.55) // Mint — HRV
        static let metricSteps     = Color(red: 0.98, green: 0.75, blue: 0.18) // Amber — Steps
        static let metricReadiness = accent                                     // Pink — Readiness

        // --- SURFACES (true black dark-first) ---
        static let background       = Color.black
        static let surface          = Color(white: 0.08)  // #141414
        static let surfaceElevated  = Color(white: 0.11)  // #1C1C1C
        static let surfaceMuted     = Color(white: 0.04)  // #0A0A0A

        static let cardBackground     = Color(white: 0.09)  // #171717
        static let elevatedBackground = surfaceElevated

        // Ultra-thin border
        static let cardBorder = Color.white.opacity(0.07)

        // Text
        static let primaryText   = Color.white
        static let secondaryText = Color(white: 0.55)
        static let tertiaryText  = Color(white: 0.35)

        // Status
        static let success = Color(red: 0.19, green: 0.82, blue: 0.35)
        static let warning = Color(red: 1.00, green: 0.62, blue: 0.04)
        static let error   = Color(red: 1.00, green: 0.27, blue: 0.27)

        // Gradient tokens
        static let mountainGradient = LinearGradient(
            colors: [accent, accentDeep],
            startPoint: .top, endPoint: .bottom
        )

        static let logoGradient = LinearGradient(
            colors: [accent, accentDeep],
            startPoint: .top, endPoint: .bottom
        )

        // Heart Rate Zones (5-zone model)
        static let zone1 = Color(red: 0.35, green: 0.68, blue: 1.00) // Recovery
        static let zone2 = Color(red: 0.19, green: 0.82, blue: 0.35) // Aerobic
        static let zone3 = Color(red: 1.00, green: 0.84, blue: 0.04) // Tempo
        static let zone4 = Color(red: 1.00, green: 0.52, blue: 0.04) // Threshold
        static let zone5 = Color(red: 1.00, green: 0.22, blue: 0.22) // VO2max

        static func difficultyColor(_ difficulty: String) -> Color {
            switch difficulty {
            case "Leicht":  return success
            case "Mittel":  return warning
            case "Schwer":  return Color(red: 0.85, green: 0.2, blue: 0.2)
            case "Extrem":  return Color(red: 0.55, green: 0.0, blue: 0.55)
            default:        return secondaryText
            }
        }
    }

    // =========================================
    // === ABSTÄNDE ===
    // =========================================
    enum Spacing {
        static let xs:   CGFloat = 4
        static let sm:   CGFloat = 8
        static let md:   CGFloat = 16
        static let lg:   CGFloat = 24
        static let xl:   CGFloat = 32
        static let xxl:  CGFloat = 48
        static let xxxl: CGFloat = 64

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
        static let xl:   CGFloat = 20
        static let xxl:  CGFloat = 24
        static let card: CGFloat = 20
        static let full: CGFloat = 999
    }

    // =========================================
    // === SCHATTEN — eliminated for Outsiders style ===
    // =========================================
    enum Shadow {
        static let card       = ShadowStyle(color: .clear, radius: 0, x: 0, y: 0)
        static let subtle     = ShadowStyle(color: .clear, radius: 0, x: 0, y: 0)
        static let accent     = ShadowStyle(color: .clear, radius: 0, x: 0, y: 0)
        static let liquidGlow = ShadowStyle(color: .clear, radius: 0, x: 0, y: 0)
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
        static let metricHero     = Font.app(size: 56, weight: .black)
        static let metricLarge    = Font.app(size: 42, weight: .black)
        static let heroTitle      = Font.app(size: 34, weight: .black)
        static let title          = Font.app(size: 26, weight: .bold)
        static let subtitle       = Font.app(size: 18, weight: .semibold)
        static let body           = Font.app(size: 16, weight: .regular)
        static let bodySecondary  = Font.app(size: 15, weight: .regular)
        static let caption        = Font.app(size: 13, weight: .medium)
        static let micro          = Font.app(size: 11, weight: .semibold)
        static let sectionLabel   = Font.appMono(size: 11, weight: .bold)
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
// Flat dark surface. No shadow. Ultra-thin border. Outsiders style.
// =========================================
struct AscentCardModifier: ViewModifier {
    var cornerRadius: CGFloat = DesignSystem.Radius.card

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(DesignSystem.Colors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(DesignSystem.Colors.cardBorder, lineWidth: 0.5)
            )
    }
}

// =========================================
// === VIEW MODIFIER: GLASS CARD ===
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
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5)
            )
    }
}

extension View {
    func ascentCard(cornerRadius: CGFloat = DesignSystem.Radius.card) -> some View {
        modifier(AscentCardModifier(cornerRadius: cornerRadius))
    }

    func glassCard(tint: Color = .white) -> some View {
        modifier(GlassCardModifier(tint: tint))
    }

    func liquidGlass(tint: Color = .white, cornerRadius: CGFloat = DesignSystem.Radius.card) -> some View {
        modifier(GlassCardModifier(tint: tint, cornerRadius: cornerRadius))
    }

    func sectionCard(
        padding: CGFloat = DesignSystem.Spacing.cardPadding,
        cornerRadius: CGFloat = DesignSystem.Radius.lg
    ) -> some View {
        self
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(DesignSystem.Colors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(DesignSystem.Colors.cardBorder, lineWidth: 0.5)
            )
    }

    func ascentAccentCard(cornerRadius: CGFloat = DesignSystem.Radius.card) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(DesignSystem.Colors.accentSoft)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(DesignSystem.Colors.accent.opacity(0.15), lineWidth: 0.5)
            )
    }
}

// MARK: - Section Header
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
                    .foregroundColor(.white)
                if let subtitle {
                    Text(subtitle)
                        .font(.app(size: 13, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
            }
            Spacer()
            trailing()
        }
    }
}

// MARK: - Outsiders-style Section Label (uppercase, small, gray)
struct OutsidersSectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.appMono(size: 11, weight: .bold))
            .foregroundColor(DesignSystem.Colors.secondaryText)
            .tracking(1.2)
    }
}

// =========================================
// === BUTTON STYLES ===
// =========================================

struct AscentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(DesignSystem.Animations.quick, value: configuration.isPressed)
    }
}

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
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .brightness(configuration.isPressed ? -0.08 : 0)
            .animation(DesignSystem.Animations.quick, value: configuration.isPressed)
    }
}

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
                    .strokeBorder(DesignSystem.Colors.accent.opacity(0.15), lineWidth: 0.5)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(DesignSystem.Animations.quick, value: configuration.isPressed)
    }
}

struct LiquidGlassButtonStyle: ButtonStyle {
    var tint: Color = .white
    var cornerRadius: CGFloat = DesignSystem.Radius.lg

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(DesignSystem.Animations.quick, value: configuration.isPressed)
    }
}

// =========================================
// === SYSTEM COLOR EXTENSIONS ===
// =========================================
extension Color {
    static let systemGreen  = Color(.systemGreen)
    static let systemOrange = Color(.systemOrange)
    static let systemRed    = Color(.systemRed)
}

// =========================================
// === ROUNDED FONT MODIFIER (no-op) ===
// =========================================
struct RoundedFontDesignModifier: ViewModifier {
    func body(content: Content) -> some View { content }
}

extension View {
    func roundedFontDesign() -> some View {
        modifier(RoundedFontDesignModifier())
    }
}

// MARK: - Sheet backgrounds
extension View {
    @ViewBuilder
    func adaptiveSheetBackground() -> some View {
        if #available(iOS 26, *) {
            self
        } else {
            self.presentationBackground(DesignSystem.Colors.surface)
        }
    }

    @ViewBuilder
    func ascentSheet(detents: Set<PresentationDetent> = [.large]) -> some View {
        self
            .presentationDetents(detents)
            .presentationCornerRadius(24)
            .adaptiveSheetBackground()
            .presentationBackgroundInteraction(.enabled(upThrough: .large))
    }
}

// MARK: - Sheet header
struct AscentSheetHeader: View {
    let title: String
    var subtitle: String?
    var onClose: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.app(size: 22, weight: .bold))
                    .foregroundColor(.white)
                if let subtitle {
                    Text(subtitle)
                        .font(.app(size: 13, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
            }
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .frame(width: 30, height: 30)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.top, DesignSystem.Spacing.md)
        .padding(.bottom, DesignSystem.Spacing.sm)
    }
}

// MARK: - Divider
struct AscentDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.07))
            .frame(height: 0.5)
    }
}

// MARK: - Pill Segmented Control (Outsiders-style)
struct PillSegmentedControl<T: Hashable>: View {
    let items: [(label: String, value: T)]
    @Binding var selected: T
    var accentColor: Color = DesignSystem.Colors.accent
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 6) {
            ForEach(items.indices, id: \.self) { i in
                let item = items[i]
                let isActive = item.value == selected
                Button {
                    withAnimation(DesignSystem.Animations.quick) {
                        selected = item.value
                    }
                } label: {
                    Text(item.label)
                        .font(.app(size: 14, weight: isActive ? .bold : .medium))
                        .foregroundColor(isActive ? .white : DesignSystem.Colors.secondaryText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background {
                            if isActive {
                                Capsule()
                                    .fill(accentColor)
                                    .matchedGeometryEffect(id: "pill", in: ns)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            Capsule().fill(Color.white.opacity(0.06))
        )
        .overlay(
            Capsule().strokeBorder(Color.white.opacity(0.07), lineWidth: 0.5)
        )
    }
}

// MARK: - Metric Atmosphere Modifier
struct MetricAtmosphereModifier: ViewModifier {
    let color: Color
    var intensity: CGFloat = 0.10

    func body(content: Content) -> some View {
        content.background(alignment: .top) {
            ZStack {
                Circle()
                    .fill(color.opacity(intensity))
                    .frame(width: 500, height: 500)
                    .blur(radius: 100)
                    .offset(y: -280)
                Circle()
                    .fill(color.opacity(intensity * 0.3))
                    .frame(width: 300, height: 300)
                    .blur(radius: 60)
                    .offset(x: 100, y: -180)
            }
            .allowsHitTesting(false)
        }
    }
}

extension View {
    func metricAtmosphere(_ color: Color, intensity: CGFloat = 0.10) -> some View {
        modifier(MetricAtmosphereModifier(color: color, intensity: intensity))
    }
}

// MARK: - Glow Card Modifier (premium depth for hero sections)
struct GlowCardModifier: ViewModifier {
    let glowColor: Color
    var intensity: CGFloat = 0.08
    var cornerRadius: CGFloat = DesignSystem.Radius.card

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius + 4, style: .continuous)
                    .fill(glowColor.opacity(intensity))
                    .blur(radius: 12)
                    .offset(y: 4)
            )
    }
}

extension View {
    func glowEffect(_ color: Color, intensity: CGFloat = 0.08) -> some View {
        modifier(GlowCardModifier(glowColor: color, intensity: intensity))
    }
}

// MARK: - Pressable Button Style
struct PressableButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.96
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .opacity(configuration.isPressed ? 0.88 : 1.0)
            .animation(DesignSystem.Animations.quick, value: configuration.isPressed)
    }
}

// MARK: - Outsiders Metric Card
struct MetricCard: View {
    let icon: String
    let label: String
    let value: String
    let unit: String
    var comparison: String? = nil
    var previousValue: String? = nil
    var metricColor: Color = DesignSystem.Colors.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(metricColor)
                Text(label)
                    .font(.appMono(size: 10, weight: .bold))
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .tracking(0.8)
            }

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                if let cmp = comparison {
                    Text(cmp)
                        .font(.appMono(size: 13, weight: .bold))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
                Text(value)
                    .font(.app(size: 28, weight: .black))
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
                Text(unit)
                    .font(.appMono(size: 13, weight: .bold))
                    .foregroundColor(DesignSystem.Colors.secondaryText)
            }

            if let prev = previousValue {
                Text(prev)
                    .font(.appMono(size: 11, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                    .fill(DesignSystem.Colors.cardBackground)
                RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [metricColor.opacity(0.04), .clear],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [metricColor.opacity(0.1), Color.white.opacity(0.05)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
    }
}

// MARK: - Body Data Tile (small rounded rect like Outsiders)
struct BodyDataTile: View {
    let icon: String
    let label: String
    let value: String?
    var locked: Bool = false
    var color: Color = DesignSystem.Colors.accent

    private var hasValue: Bool { value != nil && !locked }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                if hasValue {
                    Circle()
                        .fill(color.opacity(0.12))
                        .frame(width: 28, height: 28)
                }
                Image(systemName: locked ? "lock.fill" : icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(locked ? DesignSystem.Colors.tertiaryText : color)
            }
            if let v = value, !locked {
                Text(v)
                    .font(.appMono(size: 14, weight: .bold))
                    .foregroundColor(.white)
            } else {
                Text(locked ? "" : "–")
                    .font(.appMono(size: 14, weight: .bold))
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
            }
            Text(label)
                .font(.appMono(size: 8, weight: .bold))
                .foregroundColor(DesignSystem.Colors.tertiaryText)
                .tracking(0.6)
                .lineLimit(1)
        }
        .frame(width: 64, height: 80)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(DesignSystem.Colors.cardBackground)
                if hasValue {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.04), .clear],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    hasValue
                        ? LinearGradient(colors: [color.opacity(0.12), Color.white.opacity(0.04)], startPoint: .top, endPoint: .bottom)
                        : LinearGradient(colors: [Color.white.opacity(0.06), Color.white.opacity(0.06)], startPoint: .top, endPoint: .bottom),
                    lineWidth: 0.5
                )
        )
    }
}

// MARK: - Corner Glow Background (Outsiders-style ambient page glow)
struct CornerGlowModifier: ViewModifier {
    let color: Color
    let intensity: Double
    let corner: UnitPoint

    func body(content: Content) -> some View {
        content.background(
            ZStack {
                DesignSystem.Colors.background.ignoresSafeArea()
                RadialGradient(
                    colors: [color.opacity(intensity), .clear],
                    center: corner,
                    startRadius: 0,
                    endRadius: 400
                )
                .ignoresSafeArea()
                .blur(radius: 60)
            }
        )
    }
}

extension View {
    func cornerGlow(_ color: Color, intensity: Double = 0.15, corner: UnitPoint = .topLeading) -> some View {
        modifier(CornerGlowModifier(color: color, intensity: intensity, corner: corner))
    }
}

// MARK: - Neon Sweep Animation
struct NeonSweepModifier: ViewModifier {
    let color: Color
    @State private var sweep = false

    func body(content: Content) -> some View {
        content.overlay(
            GeometryReader { geo in
                LinearGradient(
                    colors: [.clear, color.opacity(0.08), color.opacity(0.15), color.opacity(0.08), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: geo.size.width * 0.4)
                .offset(x: sweep ? geo.size.width * 1.2 : -geo.size.width * 0.5)
                .animation(
                    .easeInOut(duration: 3.0).repeatForever(autoreverses: false),
                    value: sweep
                )
            }
            .clipped()
            .allowsHitTesting(false)
            .onAppear { sweep = true }
        )
    }
}

extension View {
    func neonSweep(_ color: Color = .white) -> some View {
        modifier(NeonSweepModifier(color: color))
    }
}

// MARK: - Readiness Ring (Outsiders-style progress ring)
struct ReadinessRing: View {
    let progress: Double
    var lineWidth: CGFloat = 10
    var size: CGFloat = 120
    var color: Color = DesignSystem.Colors.accent

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 1.0), value: progress)
        }
        .frame(width: size, height: size)
    }
}
