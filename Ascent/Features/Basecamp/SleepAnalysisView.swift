//
//  SleepAnalysisView.swift
//  Ascent
//
//  Outsiders-style sleep analysis detail view.
//  Sleep stages timeline, duration history, quality rating.
//

import SwiftUI
import Charts

struct SleepAnalysisView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var healthData = HealthDataProvider.shared
    @Environment(\.dismiss) private var dismiss

    private var totalSleepHours: Double {
        let asleep = healthData.sleepStages.filter { $0.stage != .awake }
            .reduce(0.0) { $0 + $1.end.timeIntervalSince($1.start) }
        return asleep / 3600.0
    }

    private var qualityLabel: String {
        if totalSleepHours >= 8.0 { return "Sehr gut" }
        if totalSleepHours >= 7.0 { return "Gut" }
        if totalSleepHours >= 6.0 { return "Okay" }
        if totalSleepHours >= 4.0 { return "Niedrig" }
        return "Unzureichend"
    }

    private var sleepStart: String {
        guard let first = healthData.sleepStages.first else { return "–" }
        return first.start.formatted(.dateTime.hour().minute())
    }

    private var sleepEnd: String {
        guard let last = healthData.sleepStages.last else { return "–" }
        return last.end.formatted(.dateTime.hour().minute())
    }

    private var stageDurations: [(SleepStageType, TimeInterval)] {
        var result: [SleepStageType: TimeInterval] = [:]
        for stage in healthData.sleepStages {
            result[stage.stage, default: 0] += stage.end.timeIntervalSince(stage.start)
        }
        return SleepStageType.allCases.compactMap { type in
            guard let dur = result[type] else { return nil }
            return (type, dur)
        }
    }

    var body: some View {
        ZStack {
            DesignSystem.Colors.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {

                    AscentSheetHeader(title: "Schlafanalyse", subtitle: "Letzte Nacht") {
                        dismiss()
                    }

                    // MARK: - Quality Hero
                    VStack(spacing: 8) {
                        Text(qualityLabel)
                            .font(.app(size: 42, weight: .black))
                            .foregroundColor(.white)

                        Text(String(format: "%.0fh %.0fmin", floor(totalSleepHours), (totalSleepHours.truncatingRemainder(dividingBy: 1)) * 60))
                            .font(.appMono(size: 16, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .ascentCard()
                    .padding(.horizontal, DesignSystem.Spacing.screenInset)

                    // MARK: - Time Window
                    HStack(spacing: 24) {
                        MetricCard(
                            icon: "moon.fill",
                            label: "Eingeschlafen",
                            value: sleepStart,
                            unit: "",
                            metricColor: DesignSystem.Colors.metricSleep
                        )
                        MetricCard(
                            icon: "sun.max.fill",
                            label: "Aufgewacht",
                            value: sleepEnd,
                            unit: "",
                            metricColor: DesignSystem.Colors.metricEnergy
                        )
                    }
                    .padding(.horizontal, DesignSystem.Spacing.screenInset)

                    // MARK: - Stage Timeline
                    stageTimeline
                        .padding(.horizontal, DesignSystem.Spacing.screenInset)

                    // MARK: - Stage Breakdown
                    stageBreakdown
                        .padding(.horizontal, DesignSystem.Spacing.screenInset)

                    // MARK: - Sleep Duration History
                    sleepHistoryChart
                        .padding(.horizontal, DesignSystem.Spacing.screenInset)

                    // MARK: - Disclaimer
                    Text("WICHTIG: Deine Gesundheitsdaten stammen von einer Smartwatch, nicht einem medizinischen Gerät. Betrachte die Messwerte nur als Referenz.")
                        .font(.app(size: 11, weight: .regular))
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                        .padding(.horizontal, DesignSystem.Spacing.screenInset)
                        .padding(.top, 8)

                    Spacer().frame(height: 40)
                }
            }
        }
        .metricAtmosphere(DesignSystem.Colors.metricSleep, intensity: 0.08)
        .task {
            if healthData.sleepStages.isEmpty {
                await healthData.fetchAll()
            }
        }
    }

    // MARK: - Stage Timeline Chart

    private var stageTimeline: some View {
        VStack(alignment: .leading, spacing: 14) {
            OutsidersSectionLabel(text: "Schlafphasen")

            if healthData.sleepStages.isEmpty {
                HStack {
                    Spacer()
                    Text("Keine Daten")
                        .font(.app(size: 15, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                    Spacer()
                }
                .frame(height: 120)
                .ascentCard()
            } else {
                Chart(healthData.sleepStages) { stage in
                    BarMark(
                        xStart: .value("Start", stage.start),
                        xEnd: .value("End", stage.end),
                        y: .value("Stage", stage.stage.label)
                    )
                    .foregroundStyle(stage.stage.color)
                    .cornerRadius(3)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .hour, count: 1)) { value in
                        AxisValueLabel(format: .dateTime.hour())
                            .foregroundStyle(DesignSystem.Colors.tertiaryText)
                            .font(.appMono(size: 9, weight: .medium))
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                            .foregroundStyle(Color.white.opacity(0.06))
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisValueLabel()
                            .foregroundStyle(DesignSystem.Colors.secondaryText)
                            .font(.appMono(size: 10, weight: .medium))
                    }
                }
                .frame(height: 140)
                .padding(DesignSystem.Spacing.cardPadding)
                .ascentCard()
            }
        }
    }

    // MARK: - Stage Breakdown

    private var stageBreakdown: some View {
        VStack(alignment: .leading, spacing: 14) {
            OutsidersSectionLabel(text: "Phasenverteilung")

            VStack(spacing: 10) {
                ForEach(stageDurations, id: \.0) { (type, duration) in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(type.color)
                            .frame(width: 10, height: 10)
                        Text(type.label)
                            .font(.app(size: 14, weight: .medium))
                            .foregroundColor(.white)
                        Spacer()
                        Text(formatDuration(duration))
                            .font(.appMono(size: 14, weight: .bold))
                            .foregroundColor(.white)
                        Text(String(format: "%.0f%%", (duration / max(1, totalSleepHours * 3600)) * 100))
                            .font(.appMono(size: 12, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                            .frame(width: 40, alignment: .trailing)
                    }
                    if type != stageDurations.last?.0 {
                        AscentDivider()
                    }
                }
            }
            .padding(DesignSystem.Spacing.cardPadding)
            .ascentCard()
        }
    }

    // MARK: - Sleep Duration History

    private var sleepHistoryChart: some View {
        VStack(alignment: .leading, spacing: 14) {
            OutsidersSectionLabel(text: "Schlafverlauf")

            if healthData.sleepDurationHistory.isEmpty {
                HStack {
                    Spacer()
                    Text("Keine Daten")
                        .font(.app(size: 15, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                    Spacer()
                }
                .frame(height: 120)
                .ascentCard()
            } else {
                Chart(healthData.sleepDurationHistory) { point in
                    BarMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Hours", point.value)
                    )
                    .foregroundStyle(
                        point.value >= 7 ? DesignSystem.Colors.metricSleep :
                        point.value >= 6 ? DesignSystem.Colors.metricSleep.opacity(0.6) :
                        DesignSystem.Colors.metricSleep.opacity(0.3)
                    )
                    .cornerRadius(3)

                    RuleMark(y: .value("Target", 7))
                        .foregroundStyle(Color.white.opacity(0.15))
                        .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                        .annotation(position: .trailing, alignment: .trailing) {
                            Text("7h")
                                .font(.appMono(size: 8, weight: .medium))
                                .foregroundColor(DesignSystem.Colors.tertiaryText)
                        }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 1)) { _ in
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
                .frame(height: 140)
                .padding(DesignSystem.Spacing.cardPadding)
                .ascentCard()
            }
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        return "\(h)h \(m)m"
    }
}
