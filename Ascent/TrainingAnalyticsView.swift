import SwiftUI
import Charts

struct TrainingAnalyticsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var healthData = HealthDataProvider.shared
    @ObservedObject private var analysisEngine = HealthAnalysisEngine.shared
    @State private var selectedPeriod: Period = .week
    @State private var selectedMetric: TrainingMetric = .load
    @State private var showCoachingGateway = false
    @State private var showGoalsList = false
    @State private var showSleepDetail = false
    @State private var showBodyMetrics = false
    @State private var showBodyMetricTab: BodyMetricsView.MetricCategory = .heartRate

    enum Period: String, CaseIterable, Hashable {
        case week  = "Woche"
        case month = "Monat"
        case year  = "Jahr"
    }

    enum TrainingMetric: String, CaseIterable, Hashable {
        case load     = "Belastung"
        case duration = "Dauer"
        case distance = "Distanz"
        case elevation = "Höhe"
    }

    private var metricColor: Color {
        switch selectedMetric {
        case .load:      return DesignSystem.Colors.metricLoad
        case .duration:  return DesignSystem.Colors.metricDuration
        case .distance:  return DesignSystem.Colors.metricDistance
        case .elevation: return DesignSystem.Colors.metricElevation
        }
    }

    var body: some View {
        ZStack {
            DesignSystem.Colors.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {

                    // MARK: - Header
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Fortschritt")
                                .font(.app(size: 30, weight: .black))
                                .foregroundColor(.white)
                            Text("\(healthData.recentWorkouts.count) Workouts")
                                .font(.appMono(size: 13, weight: .medium))
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, DesignSystem.Spacing.screenInset)
                    .padding(.top, DesignSystem.Spacing.md)

                    // MARK: - Period Selector
                    PillSegmentedControl(
                        items: Period.allCases.map { ($0.rawValue, $0) },
                        selected: $selectedPeriod
                    )
                    .padding(.horizontal, DesignSystem.Spacing.screenInset)

                    // MARK: - Metric Selector
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(TrainingMetric.allCases, id: \.self) { metric in
                                let isActive = metric == selectedMetric
                                Button {
                                    withAnimation(DesignSystem.Animations.quick) {
                                        selectedMetric = metric
                                    }
                                } label: {
                                    Text(metric.rawValue)
                                        .font(.app(size: 14, weight: isActive ? .bold : .medium))
                                        .foregroundColor(isActive ? .white : DesignSystem.Colors.secondaryText)
                                        .padding(.horizontal, 18)
                                        .padding(.vertical, 9)
                                        .background(
                                            Capsule().fill(isActive ? metricColor : Color.white.opacity(0.06))
                                        )
                                        .overlay(
                                            Capsule().strokeBorder(
                                                isActive ? Color.clear : Color.white.opacity(0.07),
                                                lineWidth: 0.5
                                            )
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, DesignSystem.Spacing.screenInset)
                    }

                    // MARK: - Summary Grid
                    summaryGrid
                        .padding(.horizontal, DesignSystem.Spacing.screenInset)

                    // MARK: - Training Load Chart
                    TrainingLoadChart(
                        data: healthData.weeklyTrainingLoad,
                        color: metricColor
                    )
                    .padding(.horizontal, DesignSystem.Spacing.screenInset)

                    // MARK: - Heart Rate Chart (Apple Health style)
                    heartRateChart
                        .padding(.horizontal, DesignSystem.Spacing.screenInset)

                    // MARK: - Steps Chart (Apple Health style)
                    stepsChart
                        .padding(.horizontal, DesignSystem.Spacing.screenInset)

                    // MARK: - Sleep Chart (Apple Health style)
                    sleepChart
                        .padding(.horizontal, DesignSystem.Spacing.screenInset)

                    // MARK: - Body Data
                    bodyDataSection
                        .padding(.horizontal, DesignSystem.Spacing.screenInset)

                    // MARK: - Intensity Distribution
                    intensityDistribution
                        .padding(.horizontal, DesignSystem.Spacing.screenInset)

                    // MARK: - Sport Breakdown
                    if let sports = analysisEngine.result?.sports, !sports.isEmpty {
                        sportDonutSection(sports)
                            .padding(.horizontal, DesignSystem.Spacing.screenInset)
                    }

                    // MARK: - Fitness Trends
                    if let trend = analysisEngine.result?.trend {
                        fitnessTrends(trend)
                            .padding(.horizontal, DesignSystem.Spacing.screenInset)
                    }

                    // MARK: - AI Coach & Goals
                    aiCoachSection
                        .padding(.horizontal, DesignSystem.Spacing.screenInset)

                    // MARK: - Recent Workouts
                    recentWorkoutsList
                        .padding(.horizontal, DesignSystem.Spacing.screenInset)

                    // MARK: - VO2max
                    VO2maxTrendCard(data: healthData.vo2maxHistory)
                        .padding(.horizontal, DesignSystem.Spacing.screenInset)

                    Spacer().frame(height: 120)
                }
            }
        }
        .cornerGlow(metricColor, intensity: 0.10, corner: .topLeading)
        .animation(DesignSystem.Animations.standard, value: selectedMetric)
        .task {
            if healthData.recentWorkouts.isEmpty {
                await healthData.fetchAll()
            }
        }
        .sheet(isPresented: $showCoachingGateway) {
            AICoachingGatewayView().environmentObject(appState)
        }
        .sheet(isPresented: $showGoalsList) {
            GoalsListView().environmentObject(appState)
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
    }

    // MARK: - Summary Grid

    private var summaryGrid: some View {
        let totalDuration = healthData.recentWorkouts.reduce(0) { $0 + $1.durationMinutes }
        let totalDistance = healthData.recentWorkouts.reduce(0.0) { $0 + $1.distanceKm }
        let totalElevation = healthData.recentWorkouts.reduce(0) { $0 + $1.elevationGain }
        let totalCalories = healthData.recentWorkouts.reduce(0) { $0 + $1.calories }

        return LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 12) {
            MetricCard(
                icon: "flame.fill",
                label: "Belastung",
                value: String(format: "%.0f", healthData.weeklyTrainingLoad.suffix(7).reduce(0) { $0 + $1.value }),
                unit: "",
                comparison: "=",
                metricColor: DesignSystem.Colors.metricLoad
            )
            MetricCard(
                icon: "clock.fill",
                label: "Dauer",
                value: "\(totalDuration)",
                unit: "min",
                metricColor: DesignSystem.Colors.metricDuration
            )
            MetricCard(
                icon: "location.fill",
                label: "Distanz",
                value: String(format: "%.1f", totalDistance),
                unit: "km",
                metricColor: DesignSystem.Colors.metricDistance
            )
            MetricCard(
                icon: "mountain.2.fill",
                label: "Höhenmeter",
                value: "\(totalElevation)",
                unit: "m",
                metricColor: DesignSystem.Colors.metricElevation
            )
            MetricCard(
                icon: "bolt.fill",
                label: "Energie",
                value: "\(totalCalories)",
                unit: "kcal",
                metricColor: DesignSystem.Colors.metricEnergy
            )
        }
    }

    // MARK: - Heart Rate Chart (Apple Health style)

    private var heartRateChart: some View {
        VStack(alignment: .leading, spacing: 14) {
            OutsidersSectionLabel(text: "Herzfrequenz")

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.metricHeart)
                    if let latest = healthData.heartRateHistory.last {
                        Text("\(Int(latest.value))")
                            .font(.app(size: 28, weight: .black))
                            .foregroundColor(.white)
                        Text("BPM")
                            .font(.appMono(size: 12, weight: .bold))
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    } else {
                        Text("–")
                            .font(.app(size: 28, weight: .black))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    if let rhr = healthData.restingHRHistory.last {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Ruhe")
                                .font(.appMono(size: 9, weight: .bold))
                                .foregroundColor(DesignSystem.Colors.tertiaryText)
                            Text("\(Int(rhr.value)) BPM")
                                .font(.appMono(size: 13, weight: .bold))
                                .foregroundColor(DesignSystem.Colors.metricHeart.opacity(0.8))
                        }
                    }
                }

                if !healthData.heartRateHistory.isEmpty {
                    Chart(healthData.heartRateHistory) { dp in
                        AreaMark(
                            x: .value("Time", dp.date),
                            yStart: .value("Min", healthData.heartRateHistory.map(\.value).min() ?? 40),
                            yEnd: .value("HR", dp.value)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [DesignSystem.Colors.metricHeart.opacity(0.3), .clear],
                                startPoint: .top, endPoint: .bottom
                            )
                        )

                        LineMark(
                            x: .value("Time", dp.date),
                            y: .value("HR", dp.value)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(DesignSystem.Colors.metricHeart)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .hour, count: 6)) { _ in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                                .foregroundStyle(Color.white.opacity(0.06))
                            AxisValueLabel(format: .dateTime.hour())
                                .foregroundStyle(DesignSystem.Colors.tertiaryText)
                                .font(.appMono(size: 9, weight: .medium))
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .trailing) { _ in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                                .foregroundStyle(Color.white.opacity(0.06))
                            AxisValueLabel()
                                .foregroundStyle(DesignSystem.Colors.tertiaryText)
                                .font(.appMono(size: 9, weight: .medium))
                        }
                    }
                    .frame(height: 180)
                } else {
                    emptyChartPlaceholder
                }
            }
            .padding(DesignSystem.Spacing.cardPadding)
            .ascentCard()
        }
    }

    // MARK: - Steps Chart (Apple Health style)

    private var stepsChart: some View {
        VStack(alignment: .leading, spacing: 14) {
            OutsidersSectionLabel(text: "Schritte")

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.metricSteps)
                    if let today = healthData.stepHistory.last {
                        Text("\(Int(today.value))")
                            .font(.app(size: 28, weight: .black))
                            .foregroundColor(.white)
                    } else {
                        Text("–")
                            .font(.app(size: 28, weight: .black))
                            .foregroundColor(.white)
                    }
                    Text("heute")
                        .font(.appMono(size: 12, weight: .bold))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                    Spacer()
                    let avg = healthData.stepHistory.isEmpty ? 0 : healthData.stepHistory.reduce(0.0) { $0 + $1.value } / Double(healthData.stepHistory.count)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("⌀ 7 Tage")
                            .font(.appMono(size: 9, weight: .bold))
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                        Text("\(Int(avg))")
                            .font(.appMono(size: 13, weight: .bold))
                            .foregroundColor(DesignSystem.Colors.metricSteps.opacity(0.8))
                    }
                }

                if !healthData.stepHistory.isEmpty {
                    Chart(healthData.stepHistory) { dp in
                        BarMark(
                            x: .value("Tag", dp.date, unit: .day),
                            y: .value("Schritte", dp.value)
                        )
                        .foregroundStyle(
                            Calendar.current.isDateInToday(dp.date)
                                ? LinearGradient(
                                    colors: [DesignSystem.Colors.metricSteps, DesignSystem.Colors.metricSteps.opacity(0.6)],
                                    startPoint: .top, endPoint: .bottom
                                )
                                : LinearGradient(
                                    colors: [DesignSystem.Colors.metricSteps.opacity(0.4), DesignSystem.Colors.metricSteps.opacity(0.15)],
                                    startPoint: .top, endPoint: .bottom
                                )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day)) { val in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                                .foregroundStyle(Color.white.opacity(0.06))
                            AxisValueLabel {
                                if let date = val.as(Date.self) {
                                    Text(date.formatted(.dateTime.weekday(.narrow)))
                                        .foregroundStyle(DesignSystem.Colors.tertiaryText)
                                        .font(.appMono(size: 9, weight: .medium))
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                                .foregroundStyle(Color.white.opacity(0.06))
                            AxisValueLabel()
                                .foregroundStyle(DesignSystem.Colors.tertiaryText)
                                .font(.appMono(size: 9, weight: .medium))
                        }
                    }
                    .frame(height: 160)
                } else {
                    emptyChartPlaceholder
                }
            }
            .padding(DesignSystem.Spacing.cardPadding)
            .ascentCard()
        }
    }

    // MARK: - Sleep Chart (Apple Health style)

    private var sleepChart: some View {
        VStack(alignment: .leading, spacing: 14) {
            OutsidersSectionLabel(text: "Schlaf")

            Button { showSleepDetail = true } label: {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Image(systemName: "moon.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.metricSleep)

                        let hours = sleepHours
                        if hours > 0 {
                            Text(String(format: "%.0fh %.0fm", floor(hours), (hours - floor(hours)) * 60))
                                .font(.app(size: 28, weight: .black))
                                .foregroundColor(.white)
                        } else {
                            Text("–")
                                .font(.app(size: 28, weight: .black))
                                .foregroundColor(.white)
                        }

                        Text("letzte Nacht")
                            .font(.appMono(size: 12, weight: .bold))
                            .foregroundColor(DesignSystem.Colors.secondaryText)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                    }

                    if !healthData.sleepStages.isEmpty {
                        sleepStageTimeline
                    }

                    if !healthData.sleepDurationHistory.isEmpty {
                        Chart(healthData.sleepDurationHistory) { dp in
                            BarMark(
                                x: .value("Tag", dp.date, unit: .day),
                                y: .value("Stunden", dp.value)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [DesignSystem.Colors.metricSleep.opacity(0.7), DesignSystem.Colors.metricSleep.opacity(0.25)],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .day)) { val in
                                AxisValueLabel {
                                    if let date = val.as(Date.self) {
                                        Text(date.formatted(.dateTime.weekday(.narrow)))
                                            .foregroundStyle(DesignSystem.Colors.tertiaryText)
                                            .font(.appMono(size: 9, weight: .medium))
                                    }
                                }
                            }
                        }
                        .chartYAxis {
                            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
                                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                                    .foregroundStyle(Color.white.opacity(0.06))
                                AxisValueLabel()
                                    .foregroundStyle(DesignSystem.Colors.tertiaryText)
                                    .font(.appMono(size: 9, weight: .medium))
                            }
                        }
                        .frame(height: 120)
                    } else if healthData.sleepStages.isEmpty {
                        emptyChartPlaceholder
                    }

                    HStack(spacing: 12) {
                        sleepLegendDot(color: SleepStageType.deep.color, label: "Tief")
                        sleepLegendDot(color: SleepStageType.core.color, label: "Leicht")
                        sleepLegendDot(color: SleepStageType.rem.color, label: "REM")
                        sleepLegendDot(color: SleepStageType.awake.color, label: "Wach")
                    }
                }
                .padding(DesignSystem.Spacing.cardPadding)
                .ascentCard()
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    private var sleepStageTimeline: some View {
        let totalDur = healthData.sleepStages.reduce(0.0) { $0 + $1.end.timeIntervalSince($1.start) }
        return GeometryReader { geo in
            HStack(spacing: 0.5) {
                ForEach(healthData.sleepStages) { stage in
                    let dur = stage.end.timeIntervalSince(stage.start)
                    let w = max(1, geo.size.width * (dur / max(1, totalDur)))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [stage.stage.color, stage.stage.color.opacity(0.5)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .frame(width: w)
                }
            }
        }
        .frame(height: 12)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func sleepLegendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.appMono(size: 9, weight: .medium))
                .foregroundColor(DesignSystem.Colors.tertiaryText)
        }
    }

    private var sleepHours: Double {
        let asleep = healthData.sleepStages.filter { $0.stage != .awake }
            .reduce(0.0) { $0 + $1.end.timeIntervalSince($1.start) }
        return asleep / 3600.0
    }

    // MARK: - Body Data Section

    private var bodyDataSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            OutsidersSectionLabel(text: "Körperdaten")

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                bodyMetricTile(
                    icon: "heart.fill",
                    label: "Ruhepuls",
                    value: healthData.restingHRHistory.last.map { "\(Int($0.value))" } ?? "–",
                    unit: "BPM",
                    color: DesignSystem.Colors.metricHeart,
                    data: healthData.restingHRHistory,
                    category: .heartRate
                )
                bodyMetricTile(
                    icon: "waveform.path.ecg",
                    label: "HRV",
                    value: healthData.hrvHistory.last.map { "\(Int($0.value))" } ?? "–",
                    unit: "ms",
                    color: DesignSystem.Colors.metricHRV,
                    data: healthData.hrvHistory,
                    category: .hrv
                )
                bodyMetricTile(
                    icon: "drop.fill",
                    label: "SpO₂",
                    value: healthData.spo2History.last.map { "\(Int($0.value))%" } ?? "–",
                    unit: "",
                    color: DesignSystem.Colors.metricOxygen,
                    data: healthData.spo2History,
                    category: .oxygen
                )
            }

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                bodyMetricTile(
                    icon: "thermometer.medium",
                    label: "Temperatur",
                    value: healthData.bodyTempHistory.last.map { String(format: "%.1f°", $0.value) } ?? "–",
                    unit: "",
                    color: DesignSystem.Colors.metricEnergy,
                    data: healthData.bodyTempHistory,
                    category: .temp
                )
                bodyMetricTile(
                    icon: "wind",
                    label: "Atemfrequenz",
                    value: healthData.respiratoryRateHistory.last.map { "\(Int($0.value))" } ?? "–",
                    unit: "/min",
                    color: DesignSystem.Colors.metricDistance,
                    data: healthData.respiratoryRateHistory,
                    category: .resp
                )
            }
        }
    }

    private func bodyMetricTile(icon: String, label: String, value: String, unit: String, color: Color, data: [HealthDataPoint], category: BodyMetricsView.MetricCategory) -> some View {
        Button {
            showBodyMetricTab = category
            showBodyMetrics = true
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(color)
                    Text(label)
                        .font(.appMono(size: 9, weight: .bold))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.app(size: 20, weight: .black))
                        .foregroundColor(.white)
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.appMono(size: 9, weight: .bold))
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                    }
                }

                if data.count > 2 {
                    SparklineChart(data: data, color: color, height: 28, showDot: false, showGradientFill: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                        .fill(DesignSystem.Colors.cardBackground)
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.04), .clear],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [color.opacity(0.1), Color.white.opacity(0.04)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - AI Coach & Goals

    private var aiCoachSection: some View {
        VStack(spacing: 12) {
            Button { showCoachingGateway = true } label: {
                HStack(spacing: 12) {
                    Image(systemName: "brain.head.profile.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("AI Coach")
                            .font(.app(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        Text("Trainingsplan & Empfehlungen")
                            .font(.appMono(size: 11, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                }
                .padding(DesignSystem.Spacing.cardPadding)
                .ascentCard()
            }
            .buttonStyle(PressableButtonStyle())

            Button { showGoalsList = true } label: {
                HStack(spacing: 12) {
                    Image(systemName: "target")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.metricElevation)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ziele")
                            .font(.app(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        Text("Ziel hinzufügen & verfolgen")
                            .font(.appMono(size: 11, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                }
                .padding(DesignSystem.Spacing.cardPadding)
                .ascentCard()
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    // MARK: - Intensity Distribution

    private var intensityDistribution: some View {
        VStack(alignment: .leading, spacing: 14) {
            OutsidersSectionLabel(text: "Intensitätsverteilung")
            HeartRateZoneBar(zones: healthData.hrZoneData)
        }
    }

    // MARK: - Sport Donut Section

    private func sportDonutSection(_ sports: [SportActivitySummary]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            OutsidersSectionLabel(text: "Trainingsfokus")

            HStack(spacing: 16) {
                let slices = sports.prefix(4).enumerated().map { (i, s) in
                    DonutSlice(
                        label: s.sport,
                        value: Double(s.totalMinutes),
                        color: sportColor(index: i)
                    )
                }
                DonutChart(slices: slices, size: 120)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(sports.prefix(4).enumerated()), id: \.offset) { i, sport in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(sportColor(index: i))
                                .frame(width: 8, height: 8)
                            Text(sport.sport)
                                .font(.app(size: 13, weight: .medium))
                                .foregroundColor(.white)
                            Spacer()
                            Text("\(sport.totalMinutes) min")
                                .font(.appMono(size: 12, weight: .bold))
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                        }
                    }
                }
            }
            .padding(DesignSystem.Spacing.cardPadding)
            .ascentCard()
        }
    }

    private func sportColor(index: Int) -> Color {
        let colors: [Color] = [
            DesignSystem.Colors.accent,
            DesignSystem.Colors.metricElevation,
            DesignSystem.Colors.metricDistance,
            DesignSystem.Colors.metricDuration
        ]
        return colors[index % colors.count]
    }

    // MARK: - Fitness Trends

    private func fitnessTrends(_ trend: FitnessTrend) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            OutsidersSectionLabel(text: "Fitness")

            VStack(spacing: 0) {
                trendRow(label: "Ausdauerfitness", trend: trend.vo2MaxTrend)
                AscentDivider()
                trendRow(label: "Cardiofitness", trend: trend.restingHRTrend)
                AscentDivider()
                trendRow(label: "Schritte", trend: trend.stepsTrend)
                AscentDivider()
                trendRow(label: "Aktive Kalorien", trend: trend.activeCaloriesTrend)
            }
            .padding(.vertical, 4)
            .ascentCard()
        }
    }

    private func trendRow(label: String, trend: TrendDirection) -> some View {
        HStack {
            Text(label)
                .font(.app(size: 14, weight: .medium))
                .foregroundColor(.white)
            Spacer()
            HStack(spacing: 6) {
                Text(trend.rawValue)
                    .font(.appMono(size: 12, weight: .bold))
                    .foregroundColor(trend.color)
                Image(systemName: trend.icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(trend.color)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.cardPadding)
        .padding(.vertical, 12)
    }

    // MARK: - Recent Workouts

    private var recentWorkoutsList: some View {
        VStack(alignment: .leading, spacing: 14) {
            OutsidersSectionLabel(text: "Letzte Workouts")

            VStack(spacing: 0) {
                ForEach(healthData.recentWorkouts.prefix(5)) { workout in
                    WorkoutListItem(workout: workout)
                    if workout.id != healthData.recentWorkouts.prefix(5).last?.id {
                        AscentDivider()
                            .padding(.horizontal, DesignSystem.Spacing.cardPadding)
                    }
                }

                if healthData.recentWorkouts.isEmpty {
                    HStack {
                        Spacer()
                        Text("Keine Workouts")
                            .font(.app(size: 15, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                        Spacer()
                    }
                    .padding(.vertical, 24)
                }
            }
            .ascentCard()
        }
    }

    // MARK: - Empty Chart Placeholder

    private var emptyChartPlaceholder: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "chart.line.downtrend.xyaxis")
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
                Text("Keine Daten")
                    .font(.app(size: 13, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
            }
            Spacer()
        }
        .frame(height: 120)
    }
}
