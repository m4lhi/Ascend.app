//
//  BodyMetricsView.swift
//  Ascent
//
//  Outsiders-style body metrics detail view.
//  Heart rate, HRV, SpO2, body temperature, respiratory rate trends.
//

import SwiftUI

struct BodyMetricsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var healthData = HealthDataProvider.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMetric: MetricCategory = .heartRate

    enum MetricCategory: String, CaseIterable, Hashable {
        case heartRate = "Herz"
        case hrv       = "HRV"
        case oxygen    = "SpO2"
        case temp      = "Temp"
        case resp      = "Atmung"
    }

    private var metricColor: Color {
        switch selectedMetric {
        case .heartRate: return DesignSystem.Colors.metricHeart
        case .hrv:       return DesignSystem.Colors.metricHRV
        case .oxygen:    return DesignSystem.Colors.metricOxygen
        case .temp:      return DesignSystem.Colors.metricEnergy
        case .resp:      return DesignSystem.Colors.metricDistance
        }
    }

    var body: some View {
        ZStack {
            DesignSystem.Colors.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {

                    AscentSheetHeader(title: "Körperdaten") {
                        dismiss()
                    }

                    // MARK: - Metric Selector
                    PillSegmentedControl(
                        items: MetricCategory.allCases.map { ($0.rawValue, $0) },
                        selected: $selectedMetric,
                        accentColor: metricColor
                    )
                    .padding(.horizontal, DesignSystem.Spacing.screenInset)

                    // MARK: - Hero Value
                    heroValue
                        .padding(.horizontal, DesignSystem.Spacing.screenInset)

                    // MARK: - Chart
                    chartForSelected
                        .padding(.horizontal, DesignSystem.Spacing.screenInset)

                    // MARK: - HR Zones (only for heart rate)
                    if selectedMetric == .heartRate {
                        HeartRateZoneBar(zones: healthData.hrZoneData)
                            .padding(.horizontal, DesignSystem.Spacing.screenInset)
                    }

                    // MARK: - All Metrics Summary
                    allMetricsSummary
                        .padding(.horizontal, DesignSystem.Spacing.screenInset)

                    Spacer().frame(height: 40)
                }
            }
        }
        .metricAtmosphere(metricColor, intensity: 0.10)
        .animation(DesignSystem.Animations.standard, value: selectedMetric)
        .task {
            if healthData.heartRateHistory.isEmpty {
                await healthData.fetchAll()
            }
        }
    }

    // MARK: - Hero Value

    private var heroValue: some View {
        VStack(spacing: 8) {
            switch selectedMetric {
            case .heartRate:
                metricHero(
                    value: appState.healthProfile?.restingHeartRate.map { "\($0)" } ?? "–",
                    unit: "bpm",
                    label: "Ruheherzfrequenz"
                )
            case .hrv:
                metricHero(
                    value: appState.healthProfile?.heartRateVariability.map { String(format: "%.0f", $0) } ?? "–",
                    unit: "ms",
                    label: "Herzfrequenzvariabilität"
                )
            case .oxygen:
                metricHero(
                    value: appState.healthProfile?.bloodOxygenSaturation.map { String(format: "%.0f", $0) } ?? "–",
                    unit: "%",
                    label: "Blutsauerstoff"
                )
            case .temp:
                metricHero(
                    value: appState.healthProfile?.bodyTemperatureCelsius.map { String(format: "%.1f", $0) } ?? "–",
                    unit: "°C",
                    label: "Körpertemperatur"
                )
            case .resp:
                metricHero(
                    value: appState.healthProfile?.respiratoryRate.map { String(format: "%.0f", $0) } ?? "–",
                    unit: "/min",
                    label: "Atemfrequenz"
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .ascentCard()
    }

    private func metricHero(value: String, unit: String, label: String) -> some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.app(size: 48, weight: .black))
                    .foregroundColor(.white)
                Text(unit)
                    .font(.appMono(size: 18, weight: .bold))
                    .foregroundColor(DesignSystem.Colors.secondaryText)
            }
            Text(label)
                .font(.app(size: 14, weight: .medium))
                .foregroundColor(DesignSystem.Colors.secondaryText)
        }
    }

    // MARK: - Chart

    @ViewBuilder
    private var chartForSelected: some View {
        switch selectedMetric {
        case .heartRate:
            TrendLineChart(
                data: healthData.heartRateHistory,
                title: "Herzfrequenz (7 Tage)",
                unit: "bpm",
                color: DesignSystem.Colors.metricHeart
            )
        case .hrv:
            TrendLineChart(
                data: healthData.hrvHistory,
                title: "HRV (30 Tage)",
                unit: "ms",
                color: DesignSystem.Colors.metricHRV
            )
        case .oxygen:
            TrendLineChart(
                data: healthData.spo2History,
                title: "SpO2 (14 Tage)",
                unit: "%",
                color: DesignSystem.Colors.metricOxygen
            )
        case .temp:
            TrendLineChart(
                data: healthData.bodyTempHistory,
                title: "Körpertemperatur (14 Tage)",
                unit: "°C",
                color: DesignSystem.Colors.metricEnergy
            )
        case .resp:
            TrendLineChart(
                data: healthData.respiratoryRateHistory,
                title: "Atemfrequenz (14 Tage)",
                unit: "/min",
                color: DesignSystem.Colors.metricDistance
            )
        }
    }

    // MARK: - All Metrics Summary

    private var allMetricsSummary: some View {
        VStack(alignment: .leading, spacing: 14) {
            OutsidersSectionLabel(text: "Übersicht")

            VStack(spacing: 0) {
                summaryRow(icon: "heart.fill", label: "Ruheherzfrequenz",
                          value: appState.healthProfile?.restingHeartRate.map { "\($0) bpm" } ?? "–",
                          color: DesignSystem.Colors.metricHeart)
                AscentDivider()
                summaryRow(icon: "waveform.path.ecg", label: "HRV",
                          value: appState.healthProfile?.heartRateVariability.map { String(format: "%.0f ms", $0) } ?? "–",
                          color: DesignSystem.Colors.metricHRV)
                AscentDivider()
                summaryRow(icon: "drop.fill", label: "SpO2",
                          value: appState.healthProfile?.bloodOxygenSaturation.map { String(format: "%.0f%%", $0) } ?? "–",
                          color: DesignSystem.Colors.metricOxygen)
                AscentDivider()
                summaryRow(icon: "thermometer.medium", label: "Körpertemperatur",
                          value: appState.healthProfile?.bodyTemperatureCelsius.map { String(format: "%.1f°C", $0) } ?? "–",
                          color: DesignSystem.Colors.metricEnergy)
                AscentDivider()
                summaryRow(icon: "wind", label: "Atemfrequenz",
                          value: appState.healthProfile?.respiratoryRate.map { String(format: "%.0f /min", $0) } ?? "–",
                          color: DesignSystem.Colors.metricDistance)
                AscentDivider()
                summaryRow(icon: "figure.walk", label: "Geh-Herzfrequenz",
                          value: appState.healthProfile?.walkingHeartRateAvg.map { "\($0) bpm" } ?? "–",
                          color: DesignSystem.Colors.metricHeart.opacity(0.7))
            }
            .padding(.vertical, 4)
            .ascentCard()
        }
    }

    private func summaryRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 24)
            Text(label)
                .font(.app(size: 14, weight: .medium))
                .foregroundColor(.white)
            Spacer()
            Text(value)
                .font(.appMono(size: 14, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, DesignSystem.Spacing.cardPadding)
        .padding(.vertical, 12)
    }
}
