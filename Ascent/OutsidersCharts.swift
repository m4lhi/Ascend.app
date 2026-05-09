//
//  OutsidersCharts.swift
//  Ascent
//
//  Outsiders-style chart components using Swift Charts.
//  Minimal, dark-background, thin lines, subtle grids.
//

import SwiftUI
import Charts

// MARK: - Sparkline Chart (small inline trend)

struct SparklineChart: View {
    let data: [HealthDataPoint]
    var color: Color = DesignSystem.Colors.accent
    var height: CGFloat = 50
    var showDot: Bool = true
    var showGradientFill: Bool = true

    var body: some View {
        if data.isEmpty {
            RoundedRectangle(cornerRadius: 8)
                .fill(DesignSystem.Colors.cardBackground)
                .frame(height: height)
        } else {
            Chart(data) { point in
                if showGradientFill {
                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [color.opacity(0.3), color.opacity(0.0)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }

                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [color, color.opacity(0.6)],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .lineStyle(StrokeStyle(lineWidth: 1.5))
                .interpolationMethod(.catmullRom)

                if showDot, let last = data.last, point.id == last.id {
                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(color)
                    .symbolSize(24)
                    .annotation(position: .top, spacing: 4) {
                        Circle()
                            .fill(color.opacity(0.3))
                            .frame(width: 10, height: 10)
                            .blur(radius: 3)
                    }
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartYScale(domain: .automatic(includesZero: false))
            .frame(height: height)
        }
    }
}

// MARK: - Trend Line Chart (full-width with axis labels)

struct TrendLineChart: View {
    let data: [HealthDataPoint]
    let title: String
    var unit: String = ""
    var color: Color = DesignSystem.Colors.accent
    var height: CGFloat = 180

    private var latestValue: String {
        guard let last = data.last else { return "–" }
        return String(format: "%.0f", last.value)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.app(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                HStack(spacing: 3) {
                    Text(latestValue)
                        .font(.appMono(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.appMono(size: 12, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }
                }
            }

            if data.isEmpty {
                HStack {
                    Spacer()
                    Text("Keine Daten")
                        .font(.app(size: 15, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                    Spacer()
                }
                .frame(height: height)
            } else {
                Chart(data) { point in
                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [color.opacity(0.25), color.opacity(0.0)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(color)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.catmullRom)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: data.count > 14 ? 7 : 1)) { value in
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                            .foregroundStyle(DesignSystem.Colors.tertiaryText)
                            .font(.appMono(size: 9, weight: .medium))
                    }
                    AxisMarks(values: .stride(by: .day, count: data.count > 14 ? 7 : 1)) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                            .foregroundStyle(Color.white.opacity(0.06))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing) { value in
                        AxisValueLabel()
                            .foregroundStyle(DesignSystem.Colors.tertiaryText)
                            .font(.appMono(size: 9, weight: .medium))
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                            .foregroundStyle(Color.white.opacity(0.06))
                    }
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: height)
            }
        }
        .padding(DesignSystem.Spacing.cardPadding)
        .ascentCard()
    }
}

// MARK: - Bar Chart (daily values)

struct DailyBarChart: View {
    let data: [HealthDataPoint]
    let title: String
    var unit: String = ""
    var color: Color = DesignSystem.Colors.accent
    var height: CGFloat = 160

    private var todayValue: String {
        let today = Calendar.current.startOfDay(for: Date())
        if let point = data.first(where: { Calendar.current.isDate($0.date, inSameDayAs: today) }) {
            return String(format: "%.0f", point.value)
        }
        return data.last.map { String(format: "%.0f", $0.value) } ?? "–"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.app(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                HStack(spacing: 3) {
                    Text(todayValue)
                        .font(.appMono(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.appMono(size: 12, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }
                }
            }

            if data.isEmpty {
                HStack {
                    Spacer()
                    Text("Keine Daten")
                        .font(.app(size: 15, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                    Spacer()
                }
                .frame(height: height)
            } else {
                Chart(data) { point in
                    let isToday = Calendar.current.isDateInToday(point.date)
                    BarMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: isToday
                                ? [color, color.opacity(0.6)]
                                : [color.opacity(0.4), color.opacity(0.15)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .cornerRadius(4)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: data.count > 14 ? 7 : 1)) { value in
                        AxisValueLabel(format: .dateTime.weekday(.narrow))
                            .foregroundStyle(DesignSystem.Colors.tertiaryText)
                            .font(.appMono(size: 9, weight: .medium))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
                        AxisValueLabel()
                            .foregroundStyle(DesignSystem.Colors.tertiaryText)
                            .font(.appMono(size: 9, weight: .medium))
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                            .foregroundStyle(Color.white.opacity(0.06))
                    }
                }
                .frame(height: height)
            }
        }
        .padding(DesignSystem.Spacing.cardPadding)
        .ascentCard()
    }
}

// MARK: - Heart Rate Zone Bar (horizontal stacked)

struct HeartRateZoneBar: View {
    let zones: [HeartRateZoneData]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(DesignSystem.Colors.metricHeart)
                    .font(.system(size: 14, weight: .semibold))
                Text("Herzfrequenzzonen")
                    .font(.app(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
            }

            GeometryReader { geo in
                ZStack {
                    HStack(spacing: 2) {
                        ForEach(zones) { zone in
                            let width = max(2, geo.size.width * zone.percentage)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(
                                    LinearGradient(
                                        colors: [zone.color, zone.color.opacity(0.6)],
                                        startPoint: .top, endPoint: .bottom
                                    )
                                )
                                .frame(width: width)
                        }
                    }
                    HStack(spacing: 2) {
                        ForEach(zones) { zone in
                            let width = max(2, geo.size.width * zone.percentage)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(zone.color.opacity(0.3))
                                .frame(width: width)
                                .blur(radius: 4)
                                .offset(y: 2)
                        }
                    }
                }
            }
            .frame(height: 14)
            .clipShape(Capsule())

            HStack(spacing: 0) {
                ForEach(zones) { zone in
                    VStack(spacing: 3) {
                        Circle()
                            .fill(zone.color)
                            .frame(width: 6, height: 6)
                        Text("\(Int(zone.percentage * 100))%")
                            .font(.appMono(size: 10, weight: .bold))
                            .foregroundColor(.white)
                        Text("Z\(zone.zone)")
                            .font(.appMono(size: 8, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(DesignSystem.Spacing.cardPadding)
        .ascentCard()
    }
}

// MARK: - Sleep Stage Chart (horizontal timeline)

struct SleepStageChart: View {
    let stages: [SleepStage]
    var height: CGFloat = 100

    private var totalDuration: TimeInterval {
        guard let first = stages.first, let last = stages.last else { return 1 }
        return last.end.timeIntervalSince(first.start)
    }

    private var stageDurations: [(SleepStageType, TimeInterval)] {
        var result: [SleepStageType: TimeInterval] = [:]
        for stage in stages {
            result[stage.stage, default: 0] += stage.end.timeIntervalSince(stage.start)
        }
        return SleepStageType.allCases.compactMap { type in
            guard let dur = result[type] else { return nil }
            return (type, dur)
        }
    }

    private var totalSleepHours: Double {
        let asleep = stages.filter { $0.stage != .awake }
            .reduce(0.0) { $0 + $1.end.timeIntervalSince($1.start) }
        return asleep / 3600.0
    }

    private var sleepQuality: String {
        if totalSleepHours >= 7.5 { return "Gut" }
        if totalSleepHours >= 6.0 { return "Okay" }
        return "Niedrig"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "moon.fill")
                    .foregroundColor(DesignSystem.Colors.metricSleep)
                    .font(.system(size: 14, weight: .semibold))
                Text("Schlaf")
                    .font(.app(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                if let first = stages.first {
                    Text(first.start, format: .dateTime.day().month())
                        .font(.appMono(size: 12, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
            }

            if stages.isEmpty {
                HStack {
                    Spacer()
                    Text("Keine Daten")
                        .font(.app(size: 15, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                    Spacer()
                }
                .frame(height: 60)
            } else {
                // Quality + Duration
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(sleepQuality)
                        .font(.app(size: 32, weight: .black))
                        .foregroundColor(.white)
                    Text(String(format: "%.0fh %.0fmin", totalSleepHours, (totalSleepHours.truncatingRemainder(dividingBy: 1)) * 60))
                        .font(.appMono(size: 14, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }

                // Timeline bar
                GeometryReader { geo in
                    HStack(spacing: 0.5) {
                        ForEach(stages) { stage in
                            let dur = stage.end.timeIntervalSince(stage.start)
                            let width = max(1, geo.size.width * (dur / totalDuration))
                            Rectangle()
                                .fill(stage.stage.color)
                                .frame(width: width)
                        }
                    }
                }
                .frame(height: 20)
                .clipShape(RoundedRectangle(cornerRadius: 4))

                // Legend
                HStack(spacing: 12) {
                    ForEach(stageDurations, id: \.0) { (type, dur) in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(type.color)
                                .frame(width: 6, height: 6)
                            Text(type.label)
                                .font(.appMono(size: 9, weight: .bold))
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                            Text(String(format: "%.0fh", dur / 3600))
                                .font(.appMono(size: 9, weight: .medium))
                                .foregroundColor(DesignSystem.Colors.tertiaryText)
                        }
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.cardPadding)
        .ascentCard()
    }
}

// MARK: - Training Load Chart (Outsiders-style weekly bar with comparison)

struct TrainingLoadChart: View {
    let data: [DailyMetric]
    var color: Color = DesignSystem.Colors.metricLoad

    private var weeklyTotal: Double {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return data.filter { $0.date >= weekAgo }.reduce(0) { $0 + $1.value }
    }

    private var prevWeekTotal: Double {
        let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return data.filter { $0.date >= twoWeeksAgo && $0.date < weekAgo }.reduce(0) { $0 + $1.value }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundColor(color)
                    .font(.system(size: 14, weight: .semibold))
                Text("Trainingsbelastung")
                    .font(.app(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(comparison)
                    .font(.appMono(size: 14, weight: .bold))
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                Text(String(format: "%.0f", weeklyTotal))
                    .font(.app(size: 32, weight: .black))
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
            }

            Text(String(format: "%.0f letzte Woche", prevWeekTotal))
                .font(.appMono(size: 11, weight: .medium))
                .foregroundColor(DesignSystem.Colors.tertiaryText)

            if !data.isEmpty {
                Chart(data) { metric in
                    BarMark(
                        x: .value("Date", metric.date, unit: .day),
                        y: .value("Load", metric.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [color, color.opacity(0.4)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .cornerRadius(4)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.narrow))
                            .foregroundStyle(DesignSystem.Colors.tertiaryText)
                            .font(.appMono(size: 9, weight: .medium))
                    }
                }
                .chartYAxis(.hidden)
                .frame(height: 80)
            }
        }
        .padding(DesignSystem.Spacing.cardPadding)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                    .fill(DesignSystem.Colors.cardBackground)
                RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.04), .clear],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [color.opacity(0.1), Color.white.opacity(0.05)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
    }

    private var comparison: String {
        if prevWeekTotal < 1 { return "=" }
        let diff = weeklyTotal - prevWeekTotal
        if diff > 0 { return "↑" }
        if diff < 0 { return "↓" }
        return "="
    }
}

// MARK: - Workout List Item

struct WorkoutListItem: View {
    let workout: WorkoutSummary

    private var dateLabel: String {
        let fmt = RelativeDateTimeFormatter()
        fmt.unitsStyle = .short
        return fmt.localizedString(for: workout.date, relativeTo: Date())
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: workout.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(DesignSystem.Colors.accent)
                .frame(width: 40, height: 40)
                .background(DesignSystem.Colors.accent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(workout.type)
                    .font(.app(size: 15, weight: .bold))
                    .foregroundColor(.white)
                Text(dateLabel)
                    .font(.appMono(size: 11, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.secondaryText)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(workout.durationMinutes) min")
                    .font(.appMono(size: 14, weight: .bold))
                    .foregroundColor(.white)
                if workout.elevationGain > 0 {
                    Text("↑ \(workout.elevationGain) m")
                        .font(.appMono(size: 11, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.metricElevation)
                } else if workout.distanceKm > 0.1 {
                    Text(String(format: "%.1f km", workout.distanceKm))
                        .font(.appMono(size: 11, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.metricDistance)
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, DesignSystem.Spacing.cardPadding)
    }
}

// MARK: - VO2max Trend Widget

struct VO2maxTrendCard: View {
    let data: [HealthDataPoint]

    private var current: Double? { data.last?.value }
    private var fitnessLevel: String {
        guard let v = current else { return "–" }
        if v >= 50 { return "Exzellent" }
        if v >= 42 { return "Gut" }
        if v >= 35 { return "Durchschnitt" }
        return "Niedrig"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lungs.fill")
                    .foregroundColor(DesignSystem.Colors.metricOxygen)
                    .font(.system(size: 14, weight: .semibold))
                Text("Ausdauerfitness")
                    .font(.app(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
            }

            if let v = current {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(String(format: "%.1f", v))
                        .font(.app(size: 36, weight: .black))
                        .foregroundColor(.white)
                    Text("ml/kg/min")
                        .font(.appMono(size: 12, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
                Text(fitnessLevel)
                    .font(.app(size: 14, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.metricOxygen)
            } else {
                Text("Keine Daten")
                    .font(.app(size: 18, weight: .bold))
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
            }

            SparklineChart(data: data, color: DesignSystem.Colors.metricOxygen, height: 50, showGradientFill: true)
        }
        .padding(DesignSystem.Spacing.cardPadding)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                    .fill(DesignSystem.Colors.cardBackground)
                RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [DesignSystem.Colors.metricOxygen.opacity(0.06), .clear],
                            center: .topTrailing,
                            startRadius: 0,
                            endRadius: 200
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [DesignSystem.Colors.metricOxygen.opacity(0.1), Color.white.opacity(0.05)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
    }
}

// MARK: - Donut Chart

struct DonutSlice: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
    let color: Color
}

struct DonutChart: View {
    let slices: [DonutSlice]
    var size: CGFloat = 120
    var lineWidth: CGFloat = 14

    private var total: Double {
        slices.reduce(0) { $0 + $1.value }
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.04), lineWidth: lineWidth)

            if total > 0 {
                ForEach(Array(slices.enumerated()), id: \.element.id) { index, slice in
                    let startFrac = angleFraction(for: index)
                    let endFrac = startFrac + (slice.value / total)

                    Circle()
                        .trim(from: startFrac, to: endFrac)
                        .stroke(slice.color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                        .rotationEffect(.degrees(-90))

                    Circle()
                        .trim(from: startFrac, to: endFrac)
                        .stroke(slice.color.opacity(0.25), style: StrokeStyle(lineWidth: lineWidth + 6, lineCap: .butt))
                        .rotationEffect(.degrees(-90))
                        .blur(radius: 4)
                }
            }
        }
        .frame(width: size, height: size)
    }

    private func angleFraction(for index: Int) -> Double {
        let preceding = slices.prefix(index).reduce(0.0) { $0 + $1.value }
        return preceding / max(1, total)
    }
}
