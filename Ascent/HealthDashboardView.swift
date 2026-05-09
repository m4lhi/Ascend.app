import SwiftUI

struct HealthDashboardView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var healthData = HealthDataProvider.shared
    @State private var showSleepDetail = false
    @State private var showBodyMetrics = false
    @State private var showBodyMetricTab: BodyMetricsView.MetricCategory = .heartRate
    @State private var showSettings = false
    @State private var phase = false

    private var weekdayLabel: String {
        Date().formatted(.dateTime.weekday(.wide))
    }

    private var dateLabel: String {
        Date().formatted(.dateTime.day().month(.wide))
    }

    var body: some View {
        ZStack {
            DesignSystem.Colors.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 20) {

                    header
                        .padding(.horizontal, DesignSystem.Spacing.screenInset)
                        .padding(.top, 4)

                    readinessBar
                        .padding(.horizontal, DesignSystem.Spacing.screenInset)

                    trainingDataRow

                    bodyDataRow

                    sleepEnergyCard
                        .padding(.horizontal, DesignSystem.Spacing.screenInset)

                    DailyBarChart(
                        data: healthData.stepHistory,
                        title: "Schritte",
                        color: DesignSystem.Colors.metricSteps
                    )
                    .padding(.horizontal, DesignSystem.Spacing.screenInset)

                    Button {} label: {
                        HStack {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 14, weight: .medium))
                            Text("Anpassen")
                                .font(.app(size: 14, weight: .medium))
                        }
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Color.white.opacity(0.06)))
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.07), lineWidth: 0.5))
                    }
                    .padding(.top, 8)

                    Spacer().frame(height: 120)
                }
            }
        }
        .metricAtmosphere(DesignSystem.Colors.accent, intensity: 0.06)
        .task {
            await healthData.fetchAll()
            withAnimation { phase = true }
        }
        .sheet(isPresented: $showSleepDetail) {
            SleepAnalysisView()
                .environmentObject(appState)
                .ascentSheet()
        }
        .sheet(isPresented: $showBodyMetrics) {
            BodyMetricsView()
                .environmentObject(appState)
                .ascentSheet()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(appState)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(weekdayLabel), \(dateLabel)")
                    .font(.appMono(size: 12, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                Text("Heute")
                    .font(.app(size: 30, weight: .black))
                    .foregroundColor(.white)
            }
            Spacer()
            Button { showSettings = true } label: {
                if let urlString = appState.avatarURL, let url = URL(string: urlString) {
                    CachedAsyncImage(url: url) { img in img.resizable().scaledToFill() }
                        placeholder: { Circle().fill(Color.white.opacity(0.12)) }
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
                } else {
                    Circle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 16))
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                        )
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Hero Readiness Bar (premium, glowing)

    private var readinessBar: some View {
        let score = appState.readiness?.totalScore ?? 0
        let label = appState.readiness?.status ?? "Keine Daten"
        let ratio = min(1.0, Double(score) / 100.0)
        let barColor = readinessColor(score)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(score)")
                    .font(.app(size: 56, weight: .black))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.7)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .contentTransition(.numericText())
                Text("%")
                    .font(.appMono(size: 22, weight: .bold))
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .offset(y: -2)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("READINESS")
                        .font(.appMono(size: 9, weight: .bold))
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                        .tracking(1.5)
                    Text(label)
                        .font(.app(size: 16, weight: .bold))
                        .foregroundColor(barColor)
                }
            }

            GeometryReader { geo in
                let barWidth = phase ? geo.size.width * ratio : 0

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color.white.opacity(0.06))

                    RoundedRectangle(cornerRadius: 7)
                        .fill(
                            LinearGradient(
                                colors: [barColor, barColor.opacity(0.7)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: barWidth)
                        .overlay(alignment: .trailing) {
                            if phase && score > 0 {
                                Circle()
                                    .fill(.white)
                                    .frame(width: 6, height: 6)
                                    .shadow(color: barColor.opacity(0.8), radius: 6)
                                    .padding(.trailing, 5)
                            }
                        }
                        .animation(.spring(response: 1.2, dampingFraction: 0.7), value: phase)
                }

                RoundedRectangle(cornerRadius: 7)
                    .fill(barColor.opacity(phase ? 0.15 : 0))
                    .frame(width: barWidth)
                    .blur(radius: 8)
                    .offset(y: 2)
                    .animation(.spring(response: 1.2, dampingFraction: 0.7), value: phase)
            }
            .frame(height: 14)

            if let rec = appState.readiness?.recommendation {
                Text(rec)
                    .font(.app(size: 13, weight: .regular))
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .lineLimit(2)
            }
        }
        .padding(DesignSystem.Spacing.cardPadding)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                .fill(DesignSystem.Colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [barColor.opacity(0.06), .clear],
                                center: .leading,
                                startRadius: 0,
                                endRadius: 300
                            )
                        )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [barColor.opacity(0.15), Color.white.opacity(0.05)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
    }

    private func readinessColor(_ score: Int) -> Color {
        if score >= 80 { return DesignSystem.Colors.success }
        if score >= 60 { return DesignSystem.Colors.metricDuration }
        if score >= 40 { return DesignSystem.Colors.warning }
        if score > 0 { return DesignSystem.Colors.error }
        return DesignSystem.Colors.accent
    }

    // MARK: - Training Data Row (sparkline cards, horizontal scroll)

    private var trainingDataRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            OutsidersSectionLabel(text: "Training")
                .padding(.horizontal, DesignSystem.Spacing.screenInset)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    TrainingSparkCard(
                        label: "Aktivität",
                        value: "\(healthData.recentWorkouts.first?.durationMinutes ?? 0)",
                        unit: "min",
                        data: healthData.calorieHistory,
                        color: DesignSystem.Colors.metricLoad
                    )
                    TrainingSparkCard(
                        label: "Höhenmeter",
                        value: formatElevation(),
                        unit: "m",
                        data: healthData.weeklyTrainingLoad.map { HealthDataPoint(date: $0.date, value: $0.value) },
                        color: DesignSystem.Colors.metricElevation
                    )
                    TrainingSparkCard(
                        label: "Distanz",
                        value: formatDistance(),
                        unit: "km",
                        data: healthData.stepHistory,
                        color: DesignSystem.Colors.metricDistance
                    )
                    TrainingSparkCard(
                        label: "VO₂max",
                        value: healthData.vo2maxHistory.last.map { String(format: "%.1f", $0.value) } ?? "–",
                        unit: "",
                        data: healthData.vo2maxHistory,
                        color: DesignSystem.Colors.metricOxygen
                    )
                }
                .padding(.horizontal, DesignSystem.Spacing.screenInset)
            }
        }
    }

    private func formatElevation() -> String {
        let total = healthData.recentWorkouts.prefix(7).reduce(0) { $0 + $1.elevationGain }
        return total > 0 ? "\(total)" : "–"
    }

    private func formatDistance() -> String {
        let total = healthData.recentWorkouts.prefix(7).reduce(0.0) { $0 + $1.distanceKm }
        return total > 0.1 ? String(format: "%.1f", total) : "–"
    }

    // MARK: - Body Data Row

    private var bodyDataRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            OutsidersSectionLabel(text: "Körperdaten")
                .padding(.horizontal, DesignSystem.Spacing.screenInset)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    BodyDataTile(
                        icon: "heart.fill",
                        label: "BPM",
                        value: appState.healthProfile?.restingHeartRate.map { "\($0)" },
                        color: DesignSystem.Colors.metricHeart
                    )
                    .onTapGesture { showBodyMetricTab = .heartRate; showBodyMetrics = true }
                    BodyDataTile(
                        icon: "waveform.path.ecg",
                        label: "HRV",
                        value: appState.healthProfile?.heartRateVariability.map { String(format: "%.0f", $0) },
                        color: DesignSystem.Colors.metricHRV
                    )
                    .onTapGesture { showBodyMetricTab = .hrv; showBodyMetrics = true }
                    BodyDataTile(
                        icon: "drop.fill",
                        label: "SpO2",
                        value: appState.healthProfile?.bloodOxygenSaturation.map { String(format: "%.0f%%", $0) },
                        color: DesignSystem.Colors.metricOxygen
                    )
                    .onTapGesture { showBodyMetricTab = .oxygen; showBodyMetrics = true }
                    BodyDataTile(
                        icon: "thermometer.medium",
                        label: "TEMP",
                        value: appState.healthProfile?.bodyTemperatureCelsius.map { String(format: "%.1f°", $0) },
                        color: DesignSystem.Colors.metricEnergy
                    )
                    .onTapGesture { showBodyMetricTab = .temp; showBodyMetrics = true }
                    BodyDataTile(
                        icon: "wind",
                        label: "RESP",
                        value: appState.healthProfile?.respiratoryRate.map { String(format: "%.0f", $0) },
                        color: DesignSystem.Colors.metricDistance
                    )
                    .onTapGesture { showBodyMetricTab = .resp; showBodyMetrics = true }
                }
                .padding(.horizontal, DesignSystem.Spacing.screenInset)
            }
        }
    }

    // MARK: - Sleep & Energy Card (side by side)

    private var sleepEnergyCard: some View {
        HStack(spacing: 12) {
            // Sleep half
            Button { showSleepDetail = true } label: {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "moon.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.metricSleep)
                        Text("Schlaf")
                            .font(.app(size: 13, weight: .bold))
                            .foregroundColor(.white)
                    }

                    let hours = sleepHours
                    Text(hours > 0 ? String(format: "%.0fh %.0fm", hours, (hours.truncatingRemainder(dividingBy: 1)) * 60) : "–")
                        .font(.app(size: 24, weight: .black))
                        .foregroundColor(.white)

                    Text(sleepQuality)
                        .font(.appMono(size: 11, weight: .bold))
                        .foregroundColor(DesignSystem.Colors.metricSleep)

                    // Mini sleep stage bar
                    if !healthData.sleepStages.isEmpty {
                        sleepMiniBar
                    }

                    if let readiness = appState.readiness {
                        Text("Readiness: \(readiness.physiologicalScore)%")
                            .font(.appMono(size: 10, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(DesignSystem.Spacing.cardPadding)
                .ascentCard()
            }
            .buttonStyle(PressableButtonStyle())

            // Energy half
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.metricEnergy)
                    Text("Energie")
                        .font(.app(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }

                let cal = healthData.calorieHistory.last?.value ?? 0
                Text(cal > 0 ? "\(Int(cal))" : "–")
                    .font(.app(size: 24, weight: .black))
                    .foregroundColor(.white)

                Text("kcal aktiv")
                    .font(.appMono(size: 11, weight: .bold))
                    .foregroundColor(DesignSystem.Colors.metricEnergy)

                // Mini donut
                EnergyMiniDonut(active: cal, resting: max(cal * 1.2, 800))

                if let readiness = appState.readiness {
                    Text("Readiness: \(readiness.workloadScore)%")
                        .font(.appMono(size: 10, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DesignSystem.Spacing.cardPadding)
            .ascentCard()
        }
    }

    private var sleepHours: Double {
        let asleep = healthData.sleepStages.filter { $0.stage != .awake }
            .reduce(0.0) { $0 + $1.end.timeIntervalSince($1.start) }
        return asleep / 3600.0
    }

    private var sleepQuality: String {
        if sleepHours >= 7.5 { return "Sehr gut" }
        if sleepHours >= 6.5 { return "Gut" }
        if sleepHours >= 5.0 { return "Okay" }
        if sleepHours > 0 { return "Niedrig" }
        return "–"
    }

    private var sleepMiniBar: some View {
        let totalDur = healthData.sleepStages.reduce(0.0) { $0 + $1.end.timeIntervalSince($1.start) }
        return GeometryReader { geo in
            ZStack {
                HStack(spacing: 0.5) {
                    ForEach(healthData.sleepStages) { stage in
                        let dur = stage.end.timeIntervalSince(stage.start)
                        let w = max(1, geo.size.width * (dur / max(1, totalDur)))
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [stage.stage.color, stage.stage.color.opacity(0.6)],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                            .frame(width: w)
                    }
                }
                HStack(spacing: 0.5) {
                    ForEach(healthData.sleepStages) { stage in
                        let dur = stage.end.timeIntervalSince(stage.start)
                        let w = max(1, geo.size.width * (dur / max(1, totalDur)))
                        Rectangle()
                            .fill(stage.stage.color.opacity(0.3))
                            .frame(width: w)
                            .blur(radius: 3)
                    }
                }
                .offset(y: 2)
            }
        }
        .frame(height: 8)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - Training Sparkline Card

struct TrainingSparkCard: View {
    let label: String
    let value: String
    let unit: String
    let data: [HealthDataPoint]
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SparklineChart(data: data, color: color, height: 36, showDot: false, showGradientFill: true)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.appMono(size: 18, weight: .bold))
                    .foregroundColor(.white)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.appMono(size: 10, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                }
            }

            Text(label)
                .font(.appMono(size: 10, weight: .bold))
                .foregroundColor(DesignSystem.Colors.secondaryText)
        }
        .frame(width: 110)
        .padding(12)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                    .fill(DesignSystem.Colors.cardBackground)
                RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.05), .clear],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [color.opacity(0.12), Color.white.opacity(0.05)],
                        startPoint: .top, endPoint: .bottom
                    ),
                    lineWidth: 0.5
                )
        )
    }
}

// MARK: - Energy Mini Donut

struct EnergyMiniDonut: View {
    let active: Double
    let resting: Double

    private var activeRatio: Double {
        let total = active + resting
        return total > 0 ? active / total : 0
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.06), lineWidth: 4)
            Circle()
                .trim(from: 0, to: activeRatio)
                .stroke(
                    AngularGradient(
                        colors: [
                            DesignSystem.Colors.metricEnergy,
                            DesignSystem.Colors.metricEnergy.opacity(0.5),
                            DesignSystem.Colors.metricEnergy
                        ],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(-90 + 360 * activeRatio)
                    ),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Circle()
                .trim(from: 0, to: activeRatio)
                .stroke(DesignSystem.Colors.metricEnergy.opacity(0.3), lineWidth: 8)
                .rotationEffect(.degrees(-90))
                .blur(radius: 4)
        }
        .frame(width: 36, height: 36)
    }
}
