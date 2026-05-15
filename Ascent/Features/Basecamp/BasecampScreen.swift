import SwiftUI

// =========================================
// === DATEI: BasecampScreen.swift ===
// === Gentler-Streak-flavoured main entry ===
// =========================================
//
// Parallel rebuild of the Basecamp main screen following the new
// design system (Tokens+Ascent.swift). Lives alongside the original
// BasecampView (Basecamp.swift) which stays functional and unchanged.
// Switch in the RootTabView happens once this screen sits.
//
// Iteration 1 — everything inline. Glyphs are local Shapes,
// components live in this file. Extraction into
// Design/Components/* happens after the look is locked in.

struct BasecampScreen: View {
    @EnvironmentObject var profileVM: ProfileViewModel
    @EnvironmentObject var readinessVM: ReadinessViewModel
    @EnvironmentObject var discoveryVM: DiscoveryViewModel
    @ObservedObject private var weather = WeatherManager.shared

    var body: some View {
        ZStack(alignment: .top) {
            DesignSystem.Colors.paperWarm.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        .padding(.bottom, 4)

                    HeroTopography(mood: heroMood)
                        .frame(height: 220)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)

                    editorialBlock
                        .padding(.horizontal, 24)
                        .padding(.top, 32)

                    bentoGrid
                        .padding(.horizontal, 24)
                        .padding(.top, 32)

                    featuredBlock
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                        .padding(.bottom, 48)
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            avatarButton
            Spacer()
            roundIconButton(systemName: "bell")
        }
    }

    private var avatarButton: some View {
        Button(action: {}) {
            Group {
                if let urlString = profileVM.avatarURL, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            avatarFallback
                        }
                    }
                } else {
                    avatarFallback
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(DesignSystem.Colors.glacierDeep.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var avatarFallback: some View {
        ZStack {
            DesignSystem.Colors.glacierDeep.opacity(0.18)
            Text(String(profileVM.userName.prefix(1)))
                .font(DesignSystem.Typography.bodyEmphasisInter)
                .foregroundStyle(DesignSystem.Colors.glacierDeep)
        }
    }

    private func roundIconButton(systemName: String) -> some View {
        Button(action: {}) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(DesignSystem.Colors.inkWarm)
                .frame(width: 40, height: 40)
                .background(
                    Circle().fill(DesignSystem.Colors.paperWarm)
                )
                .overlay(
                    Circle().stroke(DesignSystem.Colors.glacierDeep.opacity(0.15), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Editorial block

    private var editorialBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(kickerDate)
                .font(DesignSystem.Typography.kickerInter)
                .tracking(0.5)
                .foregroundStyle(DesignSystem.Colors.inkFaintWarm)

            Text(editorialTitle)
                .font(DesignSystem.Typography.title1Inter)
                .foregroundStyle(DesignSystem.Colors.inkWarm)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)

            Text(narrativeBody)
                .font(DesignSystem.Typography.bodyInter)
                .foregroundStyle(DesignSystem.Colors.inkWarm.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Bento grid

    private var bentoGrid: some View {
        HStack(spacing: 12) {
            BentoCard(
                background: DesignSystem.Colors.sageCard,
                inkColor: DesignSystem.Colors.inkOnSage,
                kicker: "Erholung",
                title: erholungTitle,
                trailing: { ErholungSparkline().frame(width: 56, height: 28) }
            )

            BentoCard(
                background: DesignSystem.Colors.iceGlacierCard,
                inkColor: DesignSystem.Colors.inkOnIce,
                kicker: "Wetter",
                title: wetterTitle,
                trailing: { WeatherWaveGlyph().frame(width: 36, height: 28) }
            )
        }
    }

    // MARK: - Featured block

    private var featuredBlock: some View {
        ZStack(alignment: .topLeading) {
            // Sand background
            RoundedRectangle(cornerRadius: DesignSystem.Radius.cardSoft, style: .continuous)
                .fill(DesignSystem.Colors.sandCard)

            // Faded topo pattern bottom-right
            FadedTopo()
                .stroke(DesignSystem.Colors.inkOnSand.opacity(0.10), lineWidth: 1)
                .frame(width: 180, height: 180)
                .offset(x: 200, y: 60)
                .clipped()

            VStack(alignment: .leading, spacing: 12) {
                Text("Heute empfohlen")
                    .font(DesignSystem.Typography.kickerInter)
                    .tracking(0.5)
                    .foregroundStyle(DesignSystem.Colors.inkOnSand.opacity(0.65))

                Text(featuredMountain?.name ?? "Großglockner")
                    .font(DesignSystem.Typography.title2Inter)
                    .foregroundStyle(DesignSystem.Colors.inkOnSand)

                Text(featuredStats)
                    .font(DesignSystem.Typography.subheadInter)
                    .foregroundStyle(DesignSystem.Colors.inkOnSand.opacity(0.72))
                    .monospacedDigit()

                Button(action: {}) {
                    HStack(spacing: 8) {
                        Text("Tour starten")
                            .font(DesignSystem.Typography.bodyEmphasisInter)
                        Text("→")
                            .font(DesignSystem.Typography.bodyEmphasisInter)
                    }
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule().fill(DesignSystem.Colors.alpenglow)
                    )
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .padding(20)
        }
    }

    // MARK: - Derived data

    private var heroMood: HeroTopography.Mood {
        guard let score = readinessVM.readiness?.totalScore else { return .ready }
        if score > 70 { return .ready }
        if score > 45 { return .caution }
        return .rest
    }

    private var kickerDate: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "EEEE · d. MMMM"
        return f.string(from: Date())
    }

    private var editorialTitle: String {
        guard let score = readinessVM.readiness?.totalScore else {
            return "Beobachte deinen Tag — kein Druck."
        }
        if score > 70 { return "Du bist heute bereit für den Berg." }
        if score > 45 { return "Ein vorsichtiger Tag in den Bergen." }
        return "Heute lieber unten bleiben."
    }

    private var narrativeBody: String {
        guard let r = readinessVM.readiness else {
            return "Sobald deine Werte da sind, sehen wir wie sich der Tag anfühlt."
        }
        let weatherSnippet: String = {
            if let w = weather.currentWeather, let mt = featuredMountain {
                let temp = Int(w.temperature.rounded())
                return "Am \(mt.name) zeigt sich ein Fenster bei \(temp)°."
            }
            return "Das Wetter checken wir gleich am Berg."
        }()
        switch heroMood {
        case .ready:
            return "Dein Körper hat sich erholt. \(r.recommendation) \(weatherSnippet)"
        case .caution:
            return "Du bist solide unterwegs, aber nicht in Topform. \(weatherSnippet)"
        case .rest:
            return "Dein System braucht heute Ruhe. \(weatherSnippet)"
        }
    }

    private var erholungTitle: String {
        guard let r = readinessVM.readiness else { return "Beobachten" }
        switch r.physiologicalScore {
        case 80...: return "Stark"
        case 60...: return "Solide"
        case 40...: return "Verhalten"
        default:    return "Ruhig"
        }
    }

    private var wetterTitle: String {
        guard let w = weather.currentWeather else { return "Bewölkt" }
        let temp = Int(w.temperature.rounded())
        return "\(temp)° · klar"
    }

    private var featuredMountain: Mountain? {
        discoveryVM.recommendedPeaks.first
    }

    private var featuredStats: String {
        guard let m = featuredMountain else { return "3.798 m · 8 km · 1.250 hm" }
        return "\(m.elevation) m · \(m.region)"
    }
}

// =========================================
// MARK: - Bento Card (local)
// =========================================

private struct BentoCard<Trailing: View>: View {
    let background: Color
    let inkColor: Color
    let kicker: String
    let title: String
    let trailing: () -> Trailing

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Text(kicker)
                    .font(DesignSystem.Typography.kickerInter)
                    .tracking(0.5)
                    .foregroundStyle(inkColor.opacity(0.62))
                Spacer()
                trailing()
                    .foregroundStyle(inkColor.opacity(0.78))
            }
            Text(title)
                .font(DesignSystem.Typography.title3Inter)
                .foregroundStyle(inkColor)
            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 124, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.cardSoft, style: .continuous)
                .fill(background)
        )
    }
}

// =========================================
// MARK: - Hero Topography
// =========================================

struct HeroTopography: View {
    enum Mood { case ready, caution, rest }

    let mood: Mood

    private var centerColor: Color {
        switch mood {
        case .ready:   return DesignSystem.Colors.alpenglow
        case .caution: return DesignSystem.Colors.glacierDeep
        case .rest:    return DesignSystem.Colors.inkFaintWarm
        }
    }

    private let ringCount: Int = 7

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<ringCount, id: \.self) { i in
                    TopoRing(seed: i)
                        .stroke(DesignSystem.Colors.glacierDeep.opacity(opacity(for: i)),
                                style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round))
                        .scaleEffect(scale(for: i, in: geo.size))
                }
                centerGlow(in: geo.size)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private func opacity(for i: Int) -> Double {
        let t = Double(i) / Double(max(ringCount - 1, 1))
        return 0.14 + t * 0.58
    }

    private func scale(for i: Int, in size: CGSize) -> CGFloat {
        let t = CGFloat(i) / CGFloat(max(ringCount - 1, 1))
        return 1.0 - t * 0.78
    }

    private func centerGlow(in size: CGSize) -> some View {
        ZStack {
            RadialGradient(
                colors: [centerColor.opacity(0.55), centerColor.opacity(0.0)],
                center: .center,
                startRadius: 4,
                endRadius: 70
            )
            .frame(width: 140, height: 140)
            .blendMode(.plusLighter)

            Circle()
                .fill(centerColor)
                .frame(width: 14, height: 14)
        }
    }
}

private struct TopoRing: Shape {
    let seed: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius = min(rect.width, rect.height) * 0.45
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let steps = 14
        let jitter = CGFloat((seed % 3)) * 0.06 + 0.05

        var points: [CGPoint] = []
        for i in 0..<steps {
            let angle = Double(i) / Double(steps) * .pi * 2
            let drift = sin(angle * 3 + Double(seed)) * jitter
            let r = radius * (1.0 + CGFloat(drift))
            let p = CGPoint(
                x: center.x + cos(CGFloat(angle)) * r,
                y: center.y + sin(CGFloat(angle)) * r * 0.62
            )
            points.append(p)
        }

        guard let first = points.first else { return path }
        path.move(to: first)
        for i in 0..<points.count {
            let next = points[(i + 1) % points.count]
            let mid = CGPoint(x: (points[i].x + next.x) / 2, y: (points[i].y + next.y) / 2)
            path.addQuadCurve(to: mid, control: points[i])
        }
        path.closeSubpath()
        return path
    }
}

// =========================================
// MARK: - Small inline glyphs / decoration
// =========================================

private struct ErholungSparkline: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let points: [CGFloat] = [0.5, 0.4, 0.6, 0.35, 0.55, 0.30, 0.45, 0.25]
        let stepX = rect.width / CGFloat(points.count - 1)
        for (i, y) in points.enumerated() {
            let p = CGPoint(x: CGFloat(i) * stepX, y: rect.height * y)
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        return path.strokedPath(.init(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
    }
}

private struct WeatherWaveGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        // two stacked sine ribbons
        for offset in [CGFloat(0), rect.height * 0.45] {
            path.move(to: CGPoint(x: 0, y: rect.height * 0.5 + offset * 0.5))
            for x in stride(from: CGFloat(0), to: rect.width, by: 1) {
                let y = sin(x / rect.width * .pi * 2) * 4 + rect.height * 0.3 + offset
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        return path.strokedPath(.init(lineWidth: 1.4, lineCap: .round))
    }
}

private struct FadedTopo: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        for i in 1...4 {
            let r = CGFloat(i) * (min(rect.width, rect.height) / 10)
            path.addEllipse(in: CGRect(x: center.x - r, y: center.y - r * 0.65,
                                      width: r * 2, height: r * 1.3))
        }
        return path
    }
}

// =========================================
// MARK: - Preview
// =========================================

#if DEBUG
private enum BasecampScreenPreviews {
    @MainActor
    static func make(scheme: ColorScheme) -> some View {
        let profile = ProfileViewModel()
        profile.userName = "Harwin"
        let readiness = ReadinessViewModel()
        let discovery = DiscoveryViewModel()
        return BasecampScreen()
            .environmentObject(profile)
            .environmentObject(readiness)
            .environmentObject(discovery)
            .preferredColorScheme(scheme)
    }
}

#Preview("Light · Ready") { BasecampScreenPreviews.make(scheme: .light) }
#Preview("Dark · Ready")  { BasecampScreenPreviews.make(scheme: .dark) }
#endif
