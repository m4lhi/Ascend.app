import SwiftUI

// =========================================
// === DATEI: ReadinessTrendDisplay.swift ===
// === 30-day readiness sparkline + summary stat pills ===
// =========================================
//
// Replaces the 90-day calendar heatmap in the SummitReadiness
// detail screen. Reads better with sparse data and surfaces three
// at-a-glance numbers (Highest / Average / Streak) instead of
// asking the user to scan a grid.

struct ReadinessTrendDisplay: View {
    /// ISO date string ("yyyy-MM-dd") → score (0–100). Same shape
    /// as readinessVM.readinessHistory.
    let history: [String: Int]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {

            HStack(spacing: DesignSystem.Spacing.xs) {
                ElevationGlyph()
                    .foregroundStyle(DesignSystem.Colors.inkWarm.opacity(0.62))
                    .frame(width: 18, height: 18)
                Text("Your trend")
                    .font(DesignSystem.Typography.title3Inter)
                    .foregroundStyle(DesignSystem.Colors.inkWarm)
                Spacer()
                if !dataPoints.isEmpty {
                    Text("\(dataPoints.count) days")
                        .font(DesignSystem.Typography.kickerInter)
                        .foregroundStyle(DesignSystem.Colors.inkFaintWarm)
                }
            }

            if dataPoints.count >= 2 {
                TrendSparkline(values: dataPoints)
                    .frame(height: 64)
                    .padding(.vertical, DesignSystem.Spacing.xs)
            } else {
                emptyStateView
            }

            HStack(spacing: DesignSystem.Spacing.sm) {
                StatPill(
                    label: "Highest",
                    value: highestScore.map { "\($0)" } ?? "—",
                    accentColor: DesignSystem.Colors.meadow
                )
                StatPill(
                    label: "Average",
                    value: averageScore.map { "\($0)" } ?? "—",
                    accentColor: DesignSystem.Colors.glacierDeep
                )
                StatPill(
                    label: "Streak",
                    value: streakDays > 0 ? "\(streakDays)d" : "—",
                    accentColor: DesignSystem.Colors.alpenglow
                )
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.paperWarm)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardSoft, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.cardSoft, style: .continuous)
                .stroke(DesignSystem.Colors.borderSubtle, lineWidth: 0.5)
        )
    }

    private var emptyStateView: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            Text("Not enough data yet")
                .font(DesignSystem.Typography.bodyInter)
                .foregroundStyle(DesignSystem.Colors.inkWarm.opacity(0.62))
            Text("Your trend appears after a few daily check-ins.")
                .font(DesignSystem.Typography.subheadInter)
                .foregroundStyle(DesignSystem.Colors.inkFaintWarm)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.Spacing.md)
    }

    /// Most recent 30 ISO-keyed scores, sorted chronologically.
    private var dataPoints: [Int] {
        let sortedKeys = history.keys.sorted()
        let lastN = Array(sortedKeys.suffix(30))
        return lastN.compactMap { history[$0] }
    }

    private var highestScore: Int? {
        dataPoints.max()
    }

    private var averageScore: Int? {
        guard !dataPoints.isEmpty else { return nil }
        return dataPoints.reduce(0, +) / dataPoints.count
    }

    /// Consecutive most-recent days at or above 70. Resets on the
    /// first sub-70 score from the end.
    private var streakDays: Int {
        var count = 0
        for score in dataPoints.reversed() {
            if score >= 70 { count += 1 }
            else { break }
        }
        return count
    }
}

// MARK: - Sparkline

struct TrendSparkline: View {
    let values: [Int]

    @State private var lineProgress: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {

                // Faint midpoint reference at y=50.
                Path { p in
                    p.move(to: CGPoint(x: 0, y: geo.size.height * 0.5))
                    p.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height * 0.5))
                }
                .stroke(
                    DesignSystem.Colors.borderSubtle,
                    style: StrokeStyle(lineWidth: 0.5, dash: [3, 4])
                )

                // Filled area under the line.
                trendPath(in: geo.size, fillToBottom: true)
                    .fill(
                        LinearGradient(
                            colors: [
                                DesignSystem.Colors.glacierDeep.opacity(0.18),
                                DesignSystem.Colors.glacierDeep.opacity(0.02)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .mask(
                        Rectangle()
                            .frame(width: geo.size.width * lineProgress)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    )

                // Main trend line.
                trendPath(in: geo.size, fillToBottom: false)
                    .trim(from: 0, to: lineProgress)
                    .stroke(
                        DesignSystem.Colors.glacierDeep,
                        style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
                    )

                // Last point as warm anchor dot.
                if let lastPoint = pointsArray(in: geo.size).last {
                    Circle()
                        .fill(DesignSystem.Colors.alpenglow)
                        .frame(width: 8, height: 8)
                        .position(lastPoint)
                        .opacity(lineProgress)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.2).delay(0.2)) {
                lineProgress = 1.0
            }
        }
    }

    private func pointsArray(in size: CGSize) -> [CGPoint] {
        guard !values.isEmpty else { return [] }
        let stepX = size.width / CGFloat(max(values.count - 1, 1))
        return values.enumerated().map { idx, val in
            CGPoint(
                x: CGFloat(idx) * stepX,
                y: size.height * (1.0 - CGFloat(val) / 100.0)
            )
        }
    }

    private func trendPath(in size: CGSize, fillToBottom: Bool) -> Path {
        var path = Path()
        let points = pointsArray(in: size)
        guard points.count >= 2 else { return path }

        path.move(to: points[0])

        // Smooth cubic curves between adjacent points.
        for i in 1..<points.count {
            let prev = points[i-1]
            let curr = points[i]
            let cp1 = CGPoint(x: prev.x + (curr.x - prev.x) * 0.5, y: prev.y)
            let cp2 = CGPoint(x: prev.x + (curr.x - prev.x) * 0.5, y: curr.y)
            path.addCurve(to: curr, control1: cp1, control2: cp2)
        }

        if fillToBottom, let first = points.first, let last = points.last {
            path.addLine(to: CGPoint(x: last.x, y: size.height))
            path.addLine(to: CGPoint(x: first.x, y: size.height))
            path.closeSubpath()
        }

        return path
    }
}

// MARK: - Stat Pill

struct StatPill: View {
    let label: String
    let value: String
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(DesignSystem.Typography.kickerInter)
                .foregroundStyle(DesignSystem.Colors.inkFaintWarm)
            HStack(spacing: 5) {
                Circle()
                    .fill(accentColor)
                    .frame(width: 6, height: 6)
                Text(value)
                    .font(DesignSystem.Typography.title3Inter)
                    .foregroundStyle(DesignSystem.Colors.inkWarm)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .padding(.horizontal, DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.paperWarm)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous)
                .stroke(DesignSystem.Colors.borderSubtle, lineWidth: 0.5)
        )
    }
}

#if DEBUG
#Preview("Full data") {
    let mockHistory: [String: Int] = [
        "2025-04-15": 65, "2025-04-16": 72, "2025-04-17": 68, "2025-04-18": 80,
        "2025-04-19": 78, "2025-04-20": 71, "2025-04-21": 75, "2025-04-22": 83,
        "2025-04-23": 79, "2025-04-24": 72, "2025-04-25": 65, "2025-04-26": 73,
        "2025-04-27": 81, "2025-04-28": 85, "2025-04-29": 76
    ]
    return ReadinessTrendDisplay(history: mockHistory)
        .padding()
        .background(DesignSystem.Colors.paperWarm)
}

#Preview("Empty") {
    ReadinessTrendDisplay(history: [:])
        .padding()
        .background(DesignSystem.Colors.paperWarm)
}

#Preview("One point") {
    ReadinessTrendDisplay(history: ["2025-04-29": 72])
        .padding()
        .background(DesignSystem.Colors.paperWarm)
}

#Preview("Dark") {
    let mockHistory: [String: Int] = [
        "2025-04-15": 65, "2025-04-16": 72, "2025-04-17": 68, "2025-04-18": 80,
        "2025-04-19": 78, "2025-04-20": 71, "2025-04-21": 75, "2025-04-22": 83
    ]
    return ReadinessTrendDisplay(history: mockHistory)
        .padding()
        .background(DesignSystem.Colors.paperWarm)
        .preferredColorScheme(.dark)
}
#endif
