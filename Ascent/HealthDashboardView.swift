import SwiftUI

struct HealthDashboardView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var healthData = HealthDataProvider.shared
    @ObservedObject private var weather = WeatherManager.shared
    @State private var showSleepDetail = false
    @State private var showBodyMetrics = false
    @State private var showBodyMetricTab: BodyMetricsView.MetricCategory = .heartRate
    @State private var showSettings = false
    @State private var showArena = false
    @State private var showXPDetails = false
    @State private var showExtendedReadiness = false
    @State private var showAlpineWeather = false
    @State private var showCoachingGateway = false
    @State private var showGoalsList = false
    @State private var showElevationDetail = false
    @State private var showAllActivities = false
    @State private var showTrophyRoom = false
    @State private var phase = false

    private let accent = DesignSystem.Colors.accent

    private var weekdayLabel: String {
        Date().formatted(.dateTime.weekday(.wide))
    }

    private var dateLabel: String {
        Date().formatted(.dateTime.day().month(.wide))
    }

    private var tierColor: Color {
        guard let profile = appState.ascendProfile else { return Color(red: 0.55, green: 0.37, blue: 0.22) }
        switch profile.ascend_tier.lowercased() {
        case "bronze":   return Color(red: 0.55, green: 0.37, blue: 0.22)
        case "silver":   return Color(red: 0.62, green: 0.66, blue: 0.72)
        case "gold":     return Color(red: 0.86, green: 0.68, blue: 0.18)
        case "platinum": return Color(red: 0.55, green: 0.40, blue: 0.85)
        case "obsidian": return Color(red: 0.18, green: 0.12, blue: 0.26)
        default:         return Color(red: 0.55, green: 0.37, blue: 0.22)
        }
    }

    private var tierColorDeep: Color {
        guard let profile = appState.ascendProfile else { return Color(red: 0.32, green: 0.20, blue: 0.10) }
        switch profile.ascend_tier.lowercased() {
        case "bronze":   return Color(red: 0.32, green: 0.20, blue: 0.10)
        case "silver":   return Color(red: 0.36, green: 0.40, blue: 0.46)
        case "gold":     return Color(red: 0.55, green: 0.40, blue: 0.08)
        case "platinum": return Color(red: 0.30, green: 0.15, blue: 0.55)
        case "obsidian": return Color(red: 0.08, green: 0.05, blue: 0.14)
        default:         return Color(red: 0.32, green: 0.20, blue: 0.10)
        }
    }

    private var tierLabel: String {
        (appState.ascendProfile?.ascend_tier ?? "Bronze").capitalized
    }

    private var globalRank: Int? {
        let me = appState.userHandle.lowercased()
        guard !me.isEmpty else { return nil }
        guard let idx = appState.globalLeaderboard.firstIndex(where: { $0.handle.lowercased() == me }) else { return nil }
        return idx + 1
    }

    var body: some View {
        ZStack {
            DesignSystem.Colors.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 20) {

                    header
                        .padding(.horizontal, DesignSystem.Spacing.screenInset)
                        .padding(.top, 4)

                    // MARK: Rank Card
                    rankCard
                        .padding(.horizontal, DesignSystem.Spacing.screenInset)

                    // MARK: Readiness
                    readinessBar
                        .padding(.horizontal, DesignSystem.Spacing.screenInset)

                    // MARK: Dashboard Grid (AI Coach, Activity, Elevation, Goals)
                    dashboardGrid
                        .padding(.horizontal, DesignSystem.Spacing.screenInset)

                    // MARK: Alpine Weather
                    alpineWeatherWidget
                        .padding(.horizontal, DesignSystem.Spacing.screenInset)

                    // MARK: Training Data
                    trainingDataRow

                    // MARK: Body Data
                    bodyDataRow

                    // MARK: Sleep & Energy
                    sleepEnergyCard
                        .padding(.horizontal, DesignSystem.Spacing.screenInset)

                    // MARK: Steps Chart
                    DailyBarChart(
                        data: healthData.stepHistory,
                        title: "Schritte",
                        color: DesignSystem.Colors.metricSteps
                    )
                    .padding(.horizontal, DesignSystem.Spacing.screenInset)

                    // MARK: Trophies & Achievements
                    trophyAccessCard
                        .padding(.horizontal, DesignSystem.Spacing.screenInset)

                    // MARK: Suggested Routes
                    if !appState.suggestedRoutes.isEmpty {
                        suggestedRoutesSection
                    }

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
            appState.fetchFeed()
            appState.fetchRecommendedPeaks()
            appState.refreshReadiness()
            let lat = appState.activeMountain?.latitude ?? 45.8326
            let lon = appState.activeMountain?.longitude ?? 6.8652
            Task { await weather.fetchWeather(latitude: lat, longitude: lon) }
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
        .sheet(isPresented: $showArena) {
            ArenaView()
                .environmentObject(appState)
                .presentationDetents([.large])
                .presentationCornerRadius(36)
                .adaptiveSheetBackground()
        }
        .sheet(isPresented: $showXPDetails) {
            XPDetailView()
                .presentationDetents([.medium, .large])
                .presentationCornerRadius(36)
                .adaptiveSheetBackground()
                .presentationBackgroundInteraction(.enabled(upThrough: .large))
        }
        .sheet(isPresented: $showExtendedReadiness) {
            SummitReadinessExtendedView()
                .environmentObject(appState)
                .presentationCornerRadius(36)
                .adaptiveSheetBackground()
                .presentationBackgroundInteraction(.enabled(upThrough: .large))
        }
        .sheet(isPresented: $showAlpineWeather) {
            AlpineWeatherMapView()
                .environmentObject(appState)
                .presentationCornerRadius(36)
                .adaptiveSheetBackground()
                .presentationBackgroundInteraction(.enabled(upThrough: .large))
        }
        .sheet(isPresented: $showCoachingGateway) {
            AICoachingGatewayView()
                .environmentObject(appState)
                .presentationDetents([.large])
                .presentationCornerRadius(36)
                .adaptiveSheetBackground()
                .presentationBackgroundInteraction(.enabled(upThrough: .large))
        }
        .sheet(isPresented: $showGoalsList) {
            GoalsListView()
                .environmentObject(appState)
                .presentationDetents([.large])
                .presentationCornerRadius(36)
                .adaptiveSheetBackground()
        }
        .sheet(isPresented: $showElevationDetail) {
            ObjectiveDetailView(
                title: "Weekly Altitude",
                icon: "arrow.up.right",
                current: appState.weeklyElevation,
                target: 5000,
                unit: "m"
            )
            .presentationDetents([.medium, .large])
            .presentationCornerRadius(36)
            .adaptiveSheetBackground()
            .presentationBackgroundInteraction(.enabled(upThrough: .large))
        }
        .sheet(isPresented: $showAllActivities) {
            AllActivitiesView()
                .presentationCornerRadius(36)
                .adaptiveSheetBackground()
                .presentationBackgroundInteraction(.enabled(upThrough: .large))
        }
        .sheet(isPresented: $showTrophyRoom) {
            TrophyRoomView()
                .environmentObject(appState)
                .presentationDetents([.large])
                .presentationCornerRadius(36)
                .adaptiveSheetBackground()
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
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.15), lineWidth: 2)
                        .frame(width: 42, height: 42)
                    Circle()
                        .trim(from: 0, to: phase ? Double(appState.currentLevelProgressXP) / Double(max(appState.xpNeededForNextLevel, 1)) : 0)
                        .stroke(accent, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .frame(width: 42, height: 42)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 1.1).delay(0.35), value: phase)
                    if let urlString = appState.avatarURL, let url = URL(string: urlString) {
                        CachedAsyncImage(url: url) { img in img.resizable().scaledToFill() }
                            placeholder: { Circle().fill(Color.white.opacity(0.12)) }
                            .frame(width: 34, height: 34)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.white.opacity(0.12))
                            .frame(width: 34, height: 34)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(DesignSystem.Colors.secondaryText)
                            )
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Rank Card (opens Arena)

    private var rankCard: some View {
        Button {
            HapticManager.shared.light()
            showArena = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [tierColor, tierColorDeep],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 46, height: 46)
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.white.opacity(0.45), .clear],
                                center: UnitPoint(x: 0.30, y: 0.20),
                                startRadius: 0,
                                endRadius: 20
                            )
                        )
                        .frame(width: 46, height: 46)
                        .blendMode(.plusLighter)
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 17, weight: .black))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(tierLabel.uppercased())
                        .font(.appMono(size: 9, weight: .bold))
                        .tracking(1.6)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                    if let rank = globalRank {
                        Text("Global Rank #\(rank)")
                            .font(.app(size: 16, weight: .heavy))
                            .foregroundColor(.white)
                    } else {
                        Text("\(appState.currentXP) XP · Lvl \(appState.currentLevel)")
                            .font(.app(size: 16, weight: .heavy))
                            .foregroundColor(.white)
                    }
                }
                Spacer()

                HStack(spacing: 6) {
                    Text("ARENA")
                        .font(.appMono(size: 9, weight: .bold))
                        .tracking(1.4)
                        .foregroundColor(accent)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(accent)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .ascentCard(cornerRadius: DesignSystem.Radius.xl)
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Hero Readiness Bar (premium, glowing, tappable)

    private var readinessBar: some View {
        let score = appState.readiness?.totalScore ?? 0
        let label = appState.readiness?.status ?? "Keine Daten"
        let ratio = min(1.0, Double(score) / 100.0)
        let barColor = readinessColorFor(score)

        return Button {
            HapticManager.shared.light()
            showExtendedReadiness = true
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("SUMMIT READINESS")
                        .font(.appMono(size: 9, weight: .bold))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .tracking(1.4)
                    Spacer()
                    Image(systemName: "info.circle")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                }

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

                if let readiness = appState.readiness {
                    HStack(spacing: 8) {
                        readinessSubPill(label: "Physio", score: readiness.physiologicalScore)
                        readinessSubPill(label: "Load", score: readiness.workloadScore)
                        readinessSubPill(label: "Altitude", score: readiness.altitudeScore)
                    }
                } else {
                    Text("Tap to assess readiness")
                        .font(.app(size: 13, weight: .regular))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
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
        .buttonStyle(PressableButtonStyle())
    }

    private func readinessSubPill(label: String, score: Int) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.appMono(size: 7, weight: .bold))
                .foregroundColor(DesignSystem.Colors.tertiaryText)
                .tracking(0.8)
            Text("\(score)")
                .font(.appMono(size: 16, weight: .black))
                .foregroundColor(.white)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    private func readinessColorFor(_ score: Int) -> Color {
        if score >= 80 { return DesignSystem.Colors.success }
        if score >= 60 { return DesignSystem.Colors.metricDuration }
        if score >= 40 { return DesignSystem.Colors.warning }
        if score > 0 { return DesignSystem.Colors.error }
        return DesignSystem.Colors.accent
    }

    // MARK: - Dashboard Grid (AI Coach, Activity, Elevation, Goals)

    private var dashboardGrid: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                // AI Coach
                Button {
                    HapticManager.shared.light()
                    showCoachingGateway = true
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "sparkles")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(accent)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(accent.opacity(0.6))
                        }
                        Text("AI Coach")
                            .font(.app(size: 15, weight: .black))
                            .foregroundColor(.white)
                        Text("Training · Recovery")
                            .font(.appMono(size: 9, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .ascentCard()
                }
                .buttonStyle(PressableButtonStyle())

                // Activity
                Button {
                    HapticManager.shared.light()
                    showAllActivities = true
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "figure.hiking")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.orange)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(DesignSystem.Colors.tertiaryText)
                        }
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text("\(appState.recentTours.filter { $0.isCurrentUser }.count)")
                                .font(.appMono(size: 24, weight: .black))
                                .foregroundColor(.white)
                                .contentTransition(.numericText())
                            Text("Sessions")
                                .font(.appMono(size: 10, weight: .bold))
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .ascentCard()
                }
                .buttonStyle(PressableButtonStyle())
            }

            HStack(spacing: 14) {
                // Elevation
                Button {
                    HapticManager.shared.light()
                    showElevationDetail = true
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "mountain.2.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(DesignSystem.Colors.metricElevation)
                            Spacer()
                        }
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text("\(appState.weeklyElevation)")
                                .font(.appMono(size: 24, weight: .black))
                                .foregroundColor(.white)
                                .contentTransition(.numericText())
                            Text("m")
                                .font(.appMono(size: 12, weight: .bold))
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                        }
                        Text("Höhenmeter diese Woche")
                            .font(.appMono(size: 9, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .ascentCard()
                }
                .buttonStyle(PressableButtonStyle())

                // Goals
                Button {
                    HapticManager.shared.light()
                    showGoalsList = true
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: appState.goals.isEmpty ? "plus" : "flag.2.crossed.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(accent)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(DesignSystem.Colors.tertiaryText)
                        }
                        Text(appState.goals.first?.mountainName ?? "Ziel setzen")
                            .font(.app(size: 15, weight: .black))
                            .foregroundColor(.white)
                            .lineLimit(2)
                        if let r = appState.readiness {
                            Text("\(r.totalScore)% ready")
                                .font(.appMono(size: 10, weight: .bold))
                                .foregroundColor(accent)
                        } else {
                            Text("Tap to plan")
                                .font(.appMono(size: 10, weight: .bold))
                                .foregroundColor(accent)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .ascentCard()
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
    }

    // MARK: - Alpine Weather Widget

    private var alpineWeatherWidget: some View {
        let safetyColor: Color = {
            guard let w = weather.currentWeather else { return .blue }
            switch w.safetyLevel {
            case .good:    return .green
            case .caution: return .yellow
            case .warning: return .orange
            case .danger:  return .red
            }
        }()

        return Button {
            HapticManager.shared.light()
            showAlpineWeather = true
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "cloud.sun.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .symbolRenderingMode(.multicolor)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("ALPINE SAFETY")
                                .font(.appMono(size: 9, weight: .bold))
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                                .tracking(1.4)
                            if let w = weather.currentWeather {
                                Text(w.safetyLevel.label)
                                    .font(.app(size: 13, weight: .black))
                                    .foregroundColor(safetyColor)
                            }
                        }
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        LivePulse()
                        Text("LIVE")
                            .font(.appMono(size: 8, weight: .bold))
                            .foregroundColor(.red)
                            .tracking(0.8)
                    }
                }

                HStack(spacing: 0) {
                    WeatherMetric(
                        icon: "wind",
                        value: weather.currentWeather.map { "\(Int($0.windSpeed))" } ?? "–",
                        label: "km/h"
                    )
                    WeatherMetric(
                        icon: "thermometer.low",
                        value: weather.currentWeather.map { "\(Int($0.temperature))°" } ?? "–",
                        label: "Temp"
                    )
                    WeatherMetric(
                        icon: "drop.fill",
                        value: weather.currentWeather.map { "\(Int($0.precipitationChance * 100))%" } ?? "–",
                        label: "Precip"
                    )
                    WeatherMetric(
                        icon: "eye",
                        value: weather.currentWeather.map { String(format: "%.0fkm", $0.visibility) } ?? "–",
                        label: "Vis."
                    )
                }
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                HStack(spacing: 6) {
                    Image(systemName: "map.fill")
                        .font(.system(size: 10))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                    Text("Open live weather map")
                        .font(.app(size: 12))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                }
            }
            .padding(DesignSystem.Spacing.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .ascentCard()
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Training Data Row

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
                    BodyDataTile(icon: "heart.fill", label: "BPM", value: appState.healthProfile?.restingHeartRate.map { "\($0)" }, color: DesignSystem.Colors.metricHeart)
                        .onTapGesture { showBodyMetricTab = .heartRate; showBodyMetrics = true }
                    BodyDataTile(icon: "waveform.path.ecg", label: "HRV", value: appState.healthProfile?.heartRateVariability.map { String(format: "%.0f", $0) }, color: DesignSystem.Colors.metricHRV)
                        .onTapGesture { showBodyMetricTab = .hrv; showBodyMetrics = true }
                    BodyDataTile(icon: "drop.fill", label: "SpO2", value: appState.healthProfile?.bloodOxygenSaturation.map { String(format: "%.0f%%", $0) }, color: DesignSystem.Colors.metricOxygen)
                        .onTapGesture { showBodyMetricTab = .oxygen; showBodyMetrics = true }
                    BodyDataTile(icon: "thermometer.medium", label: "TEMP", value: appState.healthProfile?.bodyTemperatureCelsius.map { String(format: "%.1f°", $0) }, color: DesignSystem.Colors.metricEnergy)
                        .onTapGesture { showBodyMetricTab = .temp; showBodyMetrics = true }
                    BodyDataTile(icon: "wind", label: "RESP", value: appState.healthProfile?.respiratoryRate.map { String(format: "%.0f", $0) }, color: DesignSystem.Colors.metricDistance)
                        .onTapGesture { showBodyMetricTab = .resp; showBodyMetrics = true }
                }
                .padding(.horizontal, DesignSystem.Spacing.screenInset)
            }
        }
    }

    // MARK: - Sleep & Energy Card

    private var sleepEnergyCard: some View {
        HStack(spacing: 12) {
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
                    if !healthData.sleepStages.isEmpty { sleepMiniBar }
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

    // MARK: - Trophy Room Access

    private var trophyAccessCard: some View {
        Button {
            HapticManager.shared.light()
            showTrophyRoom = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "medal.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.prestige)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Achievements & Trophies")
                        .font(.app(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Text("Badges, Milestones, Collections")
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

    // MARK: - Suggested Routes

    private var suggestedRoutesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            OutsidersSectionLabel(text: "Vorgeschlagene Routen")
                .padding(.horizontal, DesignSystem.Spacing.screenInset)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(appState.suggestedRoutes) { mountain in
                        RouteCard(mountain: mountain) {}
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.screenInset)
            }
        }
    }

    // MARK: - Helpers

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
