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

                    // MARK: - AI Coach & Goals
                    aiCoachSection
                        .padding(.horizontal, DesignSystem.Spacing.screenInset)

                    // MARK: - Intensity Distribution
                    intensityDistribution
                        .padding(.horizontal, DesignSystem.Spacing.screenInset)

                    // MARK: - Sport Breakdown (Donut)
                    if let sports = analysisEngine.result?.sports, !sports.isEmpty {
                        sportDonutSection(sports)
                            .padding(.horizontal, DesignSystem.Spacing.screenInset)
                    }

                    // MARK: - Fitness Trends
                    if let trend = analysisEngine.result?.trend {
                        fitnessTrends(trend)
                            .padding(.horizontal, DesignSystem.Spacing.screenInset)
                    }

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
        .metricAtmosphere(metricColor, intensity: 0.10)
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
}
