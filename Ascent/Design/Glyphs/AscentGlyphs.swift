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

// MARK: - Equipment Slot Glyphs

/// Mountaineering helmet — domed silhouette with chin strap
struct HeadGlyph: View {
    var body: some View {
        Path { p in
            p.move(to: CGPoint(x: 4, y: 16))
            p.addQuadCurve(to: CGPoint(x: 20, y: 16),
                          control: CGPoint(x: 12, y: 3))
            p.move(to: CGPoint(x: 4, y: 16))
            p.addLine(to: CGPoint(x: 20, y: 16))
            p.move(to: CGPoint(x: 8, y: 12))
            p.addLine(to: CGPoint(x: 16, y: 12))
        }
        .stroke(style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        .frame(width: 24, height: 24)
    }
}

/// Alpine jacket — silhouette with V-collar and zipper
struct JacketGlyph: View {
    var body: some View {
        Path { p in
            p.move(to: CGPoint(x: 8, y: 7))
            p.addLine(to: CGPoint(x: 4, y: 11))
            p.addLine(to: CGPoint(x: 4, y: 20))
            p.addLine(to: CGPoint(x: 20, y: 20))
            p.addLine(to: CGPoint(x: 20, y: 11))
            p.addLine(to: CGPoint(x: 16, y: 7))
            p.move(to: CGPoint(x: 8, y: 7))
            p.addLine(to: CGPoint(x: 12, y: 11))
            p.addLine(to: CGPoint(x: 16, y: 7))
            p.move(to: CGPoint(x: 12, y: 11))
            p.addLine(to: CGPoint(x: 12, y: 20))
        }
        .stroke(style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        .frame(width: 24, height: 24)
    }
}

/// Climbing pants — inverted U with split legs
struct PantsGlyph: View {
    var body: some View {
        Path { p in
            p.move(to: CGPoint(x: 6, y: 5))
            p.addLine(to: CGPoint(x: 18, y: 5))
            p.addLine(to: CGPoint(x: 17, y: 20))
            p.addLine(to: CGPoint(x: 13, y: 20))
            p.addLine(to: CGPoint(x: 12, y: 10))
            p.addLine(to: CGPoint(x: 11, y: 20))
            p.addLine(to: CGPoint(x: 7, y: 20))
            p.closeSubpath()
        }
        .stroke(style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        .frame(width: 24, height: 24)
    }
}

/// Backpack — rounded rectangle with top handle and pocket divider
struct PackGlyph: View {
    var body: some View {
        Path { p in
            p.addRoundedRect(in: CGRect(x: 6, y: 6, width: 12, height: 14),
                            cornerSize: CGSize(width: 2.5, height: 2.5))
            p.move(to: CGPoint(x: 10, y: 6))
            p.addLine(to: CGPoint(x: 10, y: 4))
            p.addLine(to: CGPoint(x: 14, y: 4))
            p.addLine(to: CGPoint(x: 14, y: 6))
            p.move(to: CGPoint(x: 8, y: 13))
            p.addLine(to: CGPoint(x: 16, y: 13))
        }
        .stroke(style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        .frame(width: 24, height: 24)
    }
}

/// Mountaineering boots — L-shape with shaft and sole
struct BootsGlyph: View {
    var body: some View {
        Path { p in
            p.move(to: CGPoint(x: 8, y: 4))
            p.addLine(to: CGPoint(x: 13, y: 4))
            p.addLine(to: CGPoint(x: 13, y: 13))
            p.addLine(to: CGPoint(x: 20, y: 13))
            p.addQuadCurve(to: CGPoint(x: 20, y: 17),
                          control: CGPoint(x: 22, y: 15))
            p.addLine(to: CGPoint(x: 8, y: 17))
            p.closeSubpath()
            p.move(to: CGPoint(x: 7, y: 19))
            p.addLine(to: CGPoint(x: 21, y: 19))
        }
        .stroke(style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        .frame(width: 24, height: 24)
    }
}

/// Carabiner — D-shape with gate notch (Extras slot)
struct ExtrasGlyph: View {
    var body: some View {
        ZStack {
            Path { p in
                p.move(to: CGPoint(x: 8, y: 5))
                p.addLine(to: CGPoint(x: 13, y: 5))
                p.addQuadCurve(to: CGPoint(x: 19, y: 12),
                              control: CGPoint(x: 19, y: 5))
                p.addQuadCurve(to: CGPoint(x: 13, y: 19),
                              control: CGPoint(x: 19, y: 19))
                p.addLine(to: CGPoint(x: 8, y: 19))
                p.closeSubpath()
            }
            .stroke(style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))

            Path { p in
                p.move(to: CGPoint(x: 8, y: 11))
                p.addLine(to: CGPoint(x: 10, y: 13))
            }
            .stroke(style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        }
        .frame(width: 24, height: 24)
    }
}

/// Generic equipment icon — reused for section header
struct EquipmentGlyph: View {
    var body: some View {
        PackGlyph()
    }
}

/// Trophy/cup — Achievements preview
struct TrophyGlyph: View {
    var body: some View {
        Path { p in
            p.move(to: CGPoint(x: 7, y: 5))
            p.addLine(to: CGPoint(x: 17, y: 5))
            p.addQuadCurve(to: CGPoint(x: 14, y: 14),
                          control: CGPoint(x: 18, y: 11))
            p.addLine(to: CGPoint(x: 10, y: 14))
            p.addQuadCurve(to: CGPoint(x: 7, y: 5),
                          control: CGPoint(x: 6, y: 11))
            p.move(to: CGPoint(x: 17, y: 7))
            p.addQuadCurve(to: CGPoint(x: 17, y: 11),
                          control: CGPoint(x: 20, y: 9))
            p.move(to: CGPoint(x: 7, y: 7))
            p.addQuadCurve(to: CGPoint(x: 7, y: 11),
                          control: CGPoint(x: 4, y: 9))
            p.move(to: CGPoint(x: 12, y: 14))
            p.addLine(to: CGPoint(x: 12, y: 18))
            p.move(to: CGPoint(x: 9, y: 18))
            p.addLine(to: CGPoint(x: 15, y: 18))
        }
        .stroke(style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        .frame(width: 24, height: 24)
    }
}

// MARK: - Milestone (5-point star outline)

struct MilestoneGlyph: View {
    var body: some View {
        Path { p in
            let center = CGPoint(x: 12, y: 12)
            let outerR: CGFloat = 8.5
            let innerR: CGFloat = 3.6
            for i in 0..<10 {
                let radius = i.isMultiple(of: 2) ? outerR : innerR
                let angle = CGFloat(i) * .pi / 5 - .pi / 2
                let x = center.x + cos(angle) * radius
                let y = center.y + sin(angle) * radius
                if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
                else      { p.addLine(to: CGPoint(x: x, y: y)) }
            }
            p.closeSubpath()
        }
        .stroke(style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        .frame(width: 24, height: 24)
    }
}

// MARK: - Weekly (flame outline)

struct WeeklyGlyph: View {
    var body: some View {
        Path { p in
            p.move(to: CGPoint(x: 12, y: 4))
            p.addQuadCurve(to: CGPoint(x: 6, y: 12), control: CGPoint(x: 8, y: 7))
            p.addQuadCurve(to: CGPoint(x: 12, y: 20), control: CGPoint(x: 4, y: 16))
            p.addQuadCurve(to: CGPoint(x: 18, y: 12), control: CGPoint(x: 20, y: 16))
            p.addQuadCurve(to: CGPoint(x: 12, y: 4), control: CGPoint(x: 14, y: 9))
            p.closeSubpath()
            // Inner ember
            p.move(to: CGPoint(x: 12, y: 11))
            p.addQuadCurve(to: CGPoint(x: 10, y: 16), control: CGPoint(x: 9, y: 13))
            p.addQuadCurve(to: CGPoint(x: 12, y: 17), control: CGPoint(x: 11, y: 17))
            p.addQuadCurve(to: CGPoint(x: 14, y: 14), control: CGPoint(x: 14, y: 17))
            p.addQuadCurve(to: CGPoint(x: 12, y: 11), control: CGPoint(x: 13, y: 12))
        }
        .stroke(style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        .frame(width: 24, height: 24)
    }
}

// MARK: - Social (two overlapping circles representing crew)

struct SocialGlyph: View {
    var body: some View {
        ZStack {
            Circle().stroke(lineWidth: 1.5).frame(width: 9, height: 9).offset(x: -3)
            Circle().stroke(lineWidth: 1.5).frame(width: 9, height: 9).offset(x: 3)
            // Small dots inside for "heads"
            Circle().fill().frame(width: 2.2, height: 2.2).offset(x: -3, y: -1)
            Circle().fill().frame(width: 2.2, height: 2.2).offset(x: 3, y: -1)
        }
        .frame(width: 24, height: 24)
    }
}

// MARK: - Explorer (map pin outline)

struct ExplorerGlyph: View {
    var body: some View {
        ZStack {
            Path { p in
                p.move(to: CGPoint(x: 12, y: 21))
                p.addLine(to: CGPoint(x: 6, y: 10))
                p.addArc(center: CGPoint(x: 12, y: 10), radius: 6,
                         startAngle: .degrees(180), endAngle: .degrees(0),
                         clockwise: false)
                p.addLine(to: CGPoint(x: 12, y: 21))
                p.closeSubpath()
            }
            .stroke(style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            Circle().stroke(lineWidth: 1.3).frame(width: 4, height: 4).offset(y: -2)
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
