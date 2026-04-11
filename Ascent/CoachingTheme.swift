import SwiftUI

// =========================================
// === DATEI: CoachingTheme.swift ===
// === Summit Gradient Design Tokens ===
// =========================================
//
// Single source of truth for colors, radius, shadows, springs, typography
// used by the AI Coaching Gateway and its map. Prefixed with `CT` to avoid
// clashing with the existing DesignSystem tokens elsewhere in the app.

enum CT {
    // MARK: Colors
    enum Colors {
        static let accent       = Color(red: 0.15, green: 0.50, blue: 1.00) // #2680FF logo mid
        static let accentDeep   = Color(red: 0.06, green: 0.33, blue: 0.80) // #0F54CC logo deep
        static let accentSoft   = Color(red: 0.87, green: 0.94, blue: 1.00) // cloud blue
        static let summit       = Color(red: 0.98, green: 0.99, blue: 1.00)
        static let surface      = Color(red: 0.96, green: 0.97, blue: 0.99)
        static let surfaceRaised = Color.white
        static let textPrimary  = Color.primary
        static let textSecondary = Color.secondary
        static let gold         = Color(red: 1.00, green: 0.78, blue: 0.25) // real-tour marker
        static let danger       = Color(red: 0.95, green: 0.45, blue: 0.30)

        static let locked       = Color(red: 0.70, green: 0.75, blue: 0.82)
    }

    // MARK: Gradients
    enum Gradients {
        static let summit = LinearGradient(
            colors: [Colors.accentSoft, Colors.accent, Colors.accentDeep],
            startPoint: .top, endPoint: .bottom
        )
        static let sky = LinearGradient(
            colors: [Color(red: 0.94, green: 0.97, blue: 1.0), Color(red: 0.86, green: 0.92, blue: 1.0)],
            startPoint: .top, endPoint: .bottom
        )
        static let cta = LinearGradient(
            colors: [Colors.accent, Colors.accentDeep],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    // MARK: Radius
    enum Radius {
        static let pill: CGFloat = 999
        static let card: CGFloat = 18
        static let modal: CGFloat = 28
        static let chip: CGFloat = 12
    }

    // MARK: Shadows
    struct ShadowStyle {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }
    enum Shadows {
        static let card  = ShadowStyle(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
        static let raise = ShadowStyle(color: .black.opacity(0.10), radius: 18, x: 0, y: 8)
        static let glow  = ShadowStyle(color: Colors.accent.opacity(0.35), radius: 22, x: 0, y: 0)
    }

    // MARK: Springs — animation profile aware
    enum Springs {
        private static var profile: AnimationProfile {
            AnimationProfile(rawValue: UserDefaults.standard.string(forKey: "animationProfile") ?? "")
                ?? .alpine
        }
        static var soft: Animation {
            switch profile {
            case .alpine:      return .spring(response: 0.55, dampingFraction: 0.82)
            case .minimal:     return .easeInOut(duration: 0.28)
            case .futuristic:  return .spring(response: 0.42, dampingFraction: 0.70)
            }
        }
        static var snappy: Animation {
            switch profile {
            case .alpine:      return .spring(response: 0.32, dampingFraction: 0.72)
            case .minimal:     return .easeOut(duration: 0.22)
            case .futuristic:  return .spring(response: 0.26, dampingFraction: 0.58)
            }
        }
        static var bouncy: Animation {
            switch profile {
            case .alpine:      return .spring(response: 0.38, dampingFraction: 0.55)
            case .minimal:     return .spring(response: 0.30, dampingFraction: 0.85)
            case .futuristic:  return .spring(response: 0.30, dampingFraction: 0.42)
            }
        }
    }

    // MARK: Typography
    enum Typo {
        static func display(_ size: CGFloat = 30) -> Font { .system(size: size, weight: .bold, design: .rounded) }
        static func title(_ size: CGFloat = 22) -> Font { .system(size: size, weight: .bold, design: .rounded) }
        static func body(_ size: CGFloat = 15) -> Font { .system(size: size, weight: .regular, design: .rounded) }
        static func label(_ size: CGFloat = 12) -> Font { .system(size: size, weight: .semibold, design: .rounded) }
        static func micro(_ size: CGFloat = 10) -> Font { .system(size: size, weight: .bold, design: .rounded) }
    }
}

extension View {
    func ctShadow(_ s: CT.ShadowStyle) -> some View {
        self.shadow(color: s.color, radius: s.radius, x: s.x, y: s.y)
    }

    func ctCard() -> some View {
        self.background(CT.Colors.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: CT.Radius.card, style: .continuous))
            .ctShadow(CT.Shadows.card)
    }
}

// MARK: - Region Theme (particles + colors per mountain region)

enum MountainRegion: String, Codable, CaseIterable {
    case alps, andes, himalaya, rockies, eastAfrica

    static func infer(from location: String) -> MountainRegion {
        let l = location.lowercased()
        if l.contains("peru") || l.contains("chile") || l.contains("argentin") || l.contains("bolivia") { return .andes }
        if l.contains("usa") || l.contains("colorado") || l.contains("wash") || l.contains("canada") { return .rockies }
        if l.contains("nepal") || l.contains("tibet") || l.contains("bhutan") { return .himalaya }
        if l.contains("kenya") || l.contains("tanz") { return .eastAfrica }
        return .alps
    }

    var displayName: String {
        switch self {
        case .alps: return "Alps"
        case .andes: return "Andes"
        case .himalaya: return "Himalaya"
        case .rockies: return "Cascades & Rockies"
        case .eastAfrica: return "East Africa"
        }
    }

    var skyGradient: LinearGradient {
        switch self {
        case .alps:
            return LinearGradient(colors: [Color(red: 0.90, green: 0.95, blue: 1.00), Color(red: 0.80, green: 0.88, blue: 0.97)], startPoint: .top, endPoint: .bottom)
        case .andes:
            return LinearGradient(colors: [Color(red: 1.00, green: 0.94, blue: 0.86), Color(red: 0.98, green: 0.82, blue: 0.68)], startPoint: .top, endPoint: .bottom)
        case .himalaya:
            return LinearGradient(colors: [Color(red: 0.94, green: 0.97, blue: 1.00), Color(red: 0.78, green: 0.86, blue: 0.96)], startPoint: .top, endPoint: .bottom)
        case .rockies:
            return LinearGradient(colors: [Color(red: 0.92, green: 0.97, blue: 0.95), Color(red: 0.78, green: 0.88, blue: 0.82)], startPoint: .top, endPoint: .bottom)
        case .eastAfrica:
            return LinearGradient(colors: [Color(red: 1.00, green: 0.96, blue: 0.88), Color(red: 0.96, green: 0.83, blue: 0.62)], startPoint: .top, endPoint: .bottom)
        }
    }

    var ridgeColors: [Color] {
        switch self {
        case .alps:       return [Color(red: 0.38, green: 0.48, blue: 0.62), Color(red: 0.55, green: 0.65, blue: 0.78), Color(red: 0.72, green: 0.80, blue: 0.90)]
        case .andes:      return [Color(red: 0.55, green: 0.32, blue: 0.22), Color(red: 0.72, green: 0.45, blue: 0.30), Color(red: 0.85, green: 0.60, blue: 0.42)]
        case .himalaya:   return [Color(red: 0.35, green: 0.42, blue: 0.58), Color(red: 0.55, green: 0.62, blue: 0.78), Color(red: 0.78, green: 0.85, blue: 0.95)]
        case .rockies:    return [Color(red: 0.25, green: 0.38, blue: 0.32), Color(red: 0.40, green: 0.52, blue: 0.42), Color(red: 0.55, green: 0.68, blue: 0.55)]
        case .eastAfrica: return [Color(red: 0.48, green: 0.32, blue: 0.20), Color(red: 0.65, green: 0.45, blue: 0.28), Color(red: 0.82, green: 0.62, blue: 0.38)]
        }
    }

    var particleKind: ParticleKind {
        switch self {
        case .alps, .himalaya: return .snow
        case .andes, .eastAfrica: return .dust
        case .rockies: return .cloud
        }
    }
}

enum ParticleKind { case snow, dust, cloud }

// MARK: - Animation Profile

enum AnimationProfile: String, CaseIterable, Identifiable {
    case alpine, minimal, futuristic
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .alpine: return "Alpine"
        case .minimal: return "Minimal"
        case .futuristic: return "Futuristic"
        }
    }
    var subtitle: String {
        switch self {
        case .alpine: return "Natural springs, organic motion"
        case .minimal: return "Apple-style restraint, no bounce"
        case .futuristic: return "Sharp springs, glow accents"
        }
    }
    var icon: String {
        switch self {
        case .alpine: return "mountain.2.fill"
        case .minimal: return "circle.dashed"
        case .futuristic: return "sparkles"
        }
    }
}

// MARK: - Ambient particles layer

struct AmbientParticlesLayer: View {
    let region: MountainRegion
    @State private var animate = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<14, id: \.self) { i in
                    particle(index: i, size: geo.size)
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear { animate = true }
    }

    @ViewBuilder
    private func particle(index: Int, size: CGSize) -> some View {
        let seed = Double(index)
        let xStart = CGFloat((seed * 73).truncatingRemainder(dividingBy: Double(size.width == 0 ? 1 : size.width)))
        let xEnd = xStart + CGFloat((seed * 19).truncatingRemainder(dividingBy: 40) - 20)
        let delay = Double(index) * 0.5
        let duration = 8.0 + (seed * 1.3).truncatingRemainder(dividingBy: 5)

        Group {
            switch region.particleKind {
            case .snow:
                Circle()
                    .fill(Color.white.opacity(0.7))
                    .frame(width: 3.5, height: 3.5)
                    .blur(radius: 0.4)
            case .dust:
                Circle()
                    .fill(Color(red: 0.95, green: 0.82, blue: 0.55).opacity(0.45))
                    .frame(width: 2.5, height: 2.5)
            case .cloud:
                Capsule()
                    .fill(Color.white.opacity(0.55))
                    .frame(width: 26, height: 6)
                    .blur(radius: 1.5)
            }
        }
        .position(x: animate ? xEnd : xStart, y: animate ? size.height + 30 : -30)
        .animation(
            .linear(duration: duration).repeatForever(autoreverses: false).delay(delay),
            value: animate
        )
    }
}
