import SwiftUI

// =========================================
// === DATEI: AscentGlyphs.swift ===
// === Custom 24x24 topographic glyphs ===
// =========================================
//
// All glyphs:
// * 24×24pt frame, scale via .frame(width:height:) — never .font(.system(size:))
// * Outline-only stroke, 1.5pt, lineCap/lineJoin round, optional center accent dot
// * Color via .foregroundStyle(DesignSystem.Colors.inkOn...) matched to card family
// * Replace SF Symbols (heart.fill / mountain.2.fill / etc.) inside widget headers

// MARK: - Readiness (concentric rings — hero language miniature)

struct ReadinessGlyph: View {
    var body: some View {
        ZStack {
            Circle().stroke(lineWidth: 1.5).frame(width: 20, height: 20)
            Circle().stroke(lineWidth: 1.5).frame(width: 11, height: 11)
            Circle().fill().frame(width: 3.5, height: 3.5)
        }
        .frame(width: 24, height: 24)
    }
}

// MARK: - Activity (altitude-profile wave)

struct ActivityGlyph: View {
    var body: some View {
        Path { p in
            p.move(to: CGPoint(x: 3, y: 17))
            p.addQuadCurve(to: CGPoint(x: 9, y: 11), control: CGPoint(x: 5, y: 9))
            p.addQuadCurve(to: CGPoint(x: 14, y: 15), control: CGPoint(x: 11, y: 19))
            p.addQuadCurve(to: CGPoint(x: 21, y: 5),  control: CGPoint(x: 17, y: 9))
        }
        .stroke(style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        .frame(width: 24, height: 24)
    }
}

// MARK: - Weather (three abstract wind / cloud ribbons)

struct WeatherGlyph: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 3.5) {
            WeatherWaveShape().stroke(style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .frame(width: 18, height: 3)
            WeatherWaveShape().stroke(style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .frame(width: 14, height: 3)
            WeatherWaveShape().stroke(style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .frame(width: 16, height: 3)
        }
        .frame(width: 24, height: 24, alignment: .center)
    }
}

private struct WeatherWaveShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let mid = rect.midY
        let amp: CGFloat = 1.3
        p.move(to: CGPoint(x: 0, y: mid))
        p.addQuadCurve(to: CGPoint(x: rect.maxX * 0.5, y: mid),
                       control: CGPoint(x: rect.maxX * 0.25, y: mid - amp))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: mid),
                       control: CGPoint(x: rect.maxX * 0.75, y: mid + amp))
        return p
    }
}

// MARK: - Elevation (rising stepped line)

struct ElevationGlyph: View {
    var body: some View {
        Path { p in
            p.move(to: CGPoint(x: 3, y: 19))
            p.addLine(to: CGPoint(x: 9, y: 19))
            p.addLine(to: CGPoint(x: 9, y: 14))
            p.addLine(to: CGPoint(x: 15, y: 14))
            p.addLine(to: CGPoint(x: 15, y: 9))
            p.addLine(to: CGPoint(x: 21, y: 9))
            p.addLine(to: CGPoint(x: 21, y: 5))
        }
        .stroke(style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        .frame(width: 24, height: 24)
    }
}

// MARK: - Goal / Target (bullseye, topographic flavor)

struct GoalGlyph: View {
    var body: some View {
        ZStack {
            Circle().stroke(lineWidth: 1.5).frame(width: 20, height: 20)
            Circle().stroke(lineWidth: 1.5).frame(width: 13, height: 13)
            Circle().stroke(lineWidth: 1.5).frame(width: 6, height: 6)
            Circle().fill().frame(width: 2.5, height: 2.5)
        }
        .frame(width: 24, height: 24)
    }
}

// MARK: - Coach (speech bubble with mini topography inside)

struct CoachGlyph: View {
    var body: some View {
        ZStack {
            BubbleShape()
                .stroke(style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                .frame(width: 22, height: 18)
            Path { p in
                p.move(to: CGPoint(x: 6, y: 11))
                p.addQuadCurve(to: CGPoint(x: 12, y: 8), control: CGPoint(x: 9, y: 6))
                p.addQuadCurve(to: CGPoint(x: 18, y: 10), control: CGPoint(x: 15, y: 9))
            }
            .stroke(style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
            .opacity(0.6)
        }
        .frame(width: 24, height: 24)
    }
}

private struct BubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r: CGFloat = 5
        p.addRoundedRect(in: CGRect(x: 1, y: 1, width: rect.width - 2, height: rect.height - 4),
                         cornerSize: CGSize(width: r, height: r))
        p.move(to: CGPoint(x: 5, y: rect.height - 3))
        p.addLine(to: CGPoint(x: 4, y: rect.height))
        p.addLine(to: CGPoint(x: 8, y: rect.height - 3))
        return p
    }
}

// MARK: - Rank / Tier (stylised twin summit)

struct RankGlyph: View {
    var body: some View {
        Path { p in
            p.move(to: CGPoint(x: 3, y: 19))
            p.addLine(to: CGPoint(x: 9, y: 8))
            p.addLine(to: CGPoint(x: 12, y: 13))
            p.addLine(to: CGPoint(x: 15, y: 8))
            p.addLine(to: CGPoint(x: 21, y: 19))
        }
        .stroke(style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        .frame(width: 24, height: 24)
    }
}

// MARK: - Route (dotted wave with endpoint markers)

struct RouteGlyph: View {
    var body: some View {
        ZStack {
            Path { p in
                p.move(to: CGPoint(x: 4, y: 17))
                p.addQuadCurve(to: CGPoint(x: 12, y: 11), control: CGPoint(x: 8, y: 7))
                p.addQuadCurve(to: CGPoint(x: 20, y: 7), control: CGPoint(x: 16, y: 17))
            }
            .stroke(style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))

            Circle().fill().frame(width: 3, height: 3)
                .position(x: 4, y: 17)
            Circle().fill().frame(width: 3, height: 3)
                .position(x: 20, y: 7)
        }
        .frame(width: 24, height: 24)
    }
}

// MARK: - Mountain (free-standing triangle with snow cap)

struct MountainGlyph: View {
    var body: some View {
        ZStack {
            Path { p in
                p.move(to: CGPoint(x: 12, y: 4))
                p.addQuadCurve(to: CGPoint(x: 20, y: 19),
                               control: CGPoint(x: 18, y: 14))
                p.addLine(to: CGPoint(x: 4, y: 19))
                p.addQuadCurve(to: CGPoint(x: 12, y: 4),
                               control: CGPoint(x: 6, y: 14))
                p.closeSubpath()
            }
            .stroke(style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))

            // Snow cap accent — short top wedge.
            Path { p in
                p.move(to: CGPoint(x: 9.5, y: 9.5))
                p.addLine(to: CGPoint(x: 12, y: 7))
                p.addLine(to: CGPoint(x: 14.5, y: 9.5))
            }
            .stroke(style: StrokeStyle(lineWidth: 1.3, lineCap: .round, lineJoin: .round))
        }
        .frame(width: 24, height: 24)
    }
}

// MARK: - Fist-bump (heart — outline or filled)

struct FistBumpGlyph: View {
    var filled: Bool = false

    private var path: Path {
        Path { p in
            p.move(to: CGPoint(x: 12, y: 7))
            p.addQuadCurve(to: CGPoint(x: 7, y: 5), control: CGPoint(x: 9, y: 4))
            p.addQuadCurve(to: CGPoint(x: 4, y: 9), control: CGPoint(x: 4, y: 6.5))
            p.addQuadCurve(to: CGPoint(x: 12, y: 19), control: CGPoint(x: 4, y: 14))
            p.addQuadCurve(to: CGPoint(x: 20, y: 9), control: CGPoint(x: 20, y: 14))
            p.addQuadCurve(to: CGPoint(x: 17, y: 5), control: CGPoint(x: 20, y: 6.5))
            p.addQuadCurve(to: CGPoint(x: 12, y: 7), control: CGPoint(x: 15, y: 4))
        }
    }

    var body: some View {
        Group {
            if filled {
                path.fill()
            } else {
                path.stroke(style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            }
        }
        .frame(width: 24, height: 24)
    }
}

// MARK: - Comment (speech bubble with tail)

struct CommentGlyph: View {
    var body: some View {
        Path { p in
            p.addRoundedRect(
                in: CGRect(x: 3, y: 5, width: 18, height: 12),
                cornerSize: CGSize(width: 4, height: 4)
            )
            p.move(to: CGPoint(x: 8, y: 17))
            p.addLine(to: CGPoint(x: 7, y: 20))
            p.addLine(to: CGPoint(x: 11, y: 17))
        }
        .stroke(style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        .frame(width: 24, height: 24)
    }
}

// MARK: - Bookmark (rounded top, V-cut bottom)

struct BookmarkGlyph: View {
    var filled: Bool = false

    private var path: Path {
        Path { p in
            p.move(to: CGPoint(x: 6, y: 4))
            p.addLine(to: CGPoint(x: 18, y: 4))
            p.addLine(to: CGPoint(x: 18, y: 20))
            p.addLine(to: CGPoint(x: 12, y: 15))
            p.addLine(to: CGPoint(x: 6, y: 20))
            p.closeSubpath()
        }
    }

    var body: some View {
        Group {
            if filled {
                path.fill()
            } else {
                path.stroke(style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            }
        }
        .frame(width: 24, height: 24)
    }
}
