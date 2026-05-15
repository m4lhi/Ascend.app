import SwiftUI

struct HealthDashboardView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var profileVM: ProfileViewModel
    @EnvironmentObject var feedVM: FeedViewModel
    @StateObject private var healthData = HealthDataProvider.shared
    @ObservedObject private var weather = WeatherManager.shared
    @State private var showSettings = false
    @State private var showArena = false
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
        let me = profileVM.userHandle.lowercased()
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

                    readinessHeroCard
                        .padding(.horizontal, DesignSystem.Spacing.screenInset)

                    rankCard
                        .padding(.horizontal, DesignSystem.Spacing.screenInset)

                    dashboardGrid
                        .padding(.horizontal, DesignSystem.Spacing.screenInset)

                    alpineWeatherWidget
                        .padding(.horizontal, DesignSystem.Spacing.screenInset)

                    trophyAccessCard
                        .padding(.horizontal, DesignSystem.Spacing.screenInset)

                    if !appState.suggestedRoutes.isEmpty {
                        suggestedRoutesSection
                    }

                    Spacer().frame(height: 120)
                }
            }
        }
        .cornerGlow(readinessGlowColor, intensity: 0.12, corner: .topLeading)
        .cornerGlow(.blue.opacity(0.5), intensity: 0.06, corner: .bottomTrailing)
        .task {
            await healthData.fetchAll()
            feedVM.fetchFeed()
            appState.fetchRecommendedPeaks()
            appState.refreshReadiness()
            let lat = appState.activeMountain?.latitude ?? 45.8326
            let lon = appState.activeMountain?.longitude ?? 6.8652
            Task { await weather.fetchWeather(latitude: lat, longitude: lon) }
            withAnimation { phase = true }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView().environmentObject(appState)
        }
        .sheet(isPresented: $showArena) {
            ArenaView()
                .environmentObject(appState)
                .presentationDetents([.large])
                .presentationCornerRadius(36)
                .adaptiveSheetBackground()
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

    private var readinessGlowColor: Color {
        let score = appState.readiness?.totalScore ?? 0
        return readinessColorFor(score)
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
                    if let urlString = profileVM.avatarURL, let url = URL(string: urlString) {
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

    // MARK: - Readiness Hero Card (full-width, top of page)

    private var readinessHeroCard: some View {
        let score = appState.readiness?.totalScore ?? 0
        let label = appState.readiness?.status ?? "Keine Daten"
        let ratio = min(1.0, Double(score) / 100.0)
        let barColor = readinessColorFor(score)

        return Button {
            HapticManager.shared.light()
            showExtendedReadiness = true
        } label: {
            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "mountain.2.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(barColor.opacity(0.8))
                            Text("SUMMIT READINESS")
                                .font(.appMono(size: 9, weight: .bold))
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                                .tracking(1.4)
                        }

                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(score)")
                                .font(.system(size: 64, weight: .black, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.white, .white.opacity(0.65)],
                                        startPoint: .top, endPoint: .bottom
                                    )
                                )
                                .contentTransition(.numericText())
                            Text("%")
                                .font(.appMono(size: 24, weight: .bold))
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 6) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                        Spacer()
                        Text(label)
                            .font(.app(size: 18, weight: .black))
                            .foregroundColor(barColor)
                    }
                }
                .padding(.bottom, 16)

                GeometryReader { geo in
                    let barWidth = phase ? geo.size.width * ratio : 0
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.06))
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    colors: [barColor, barColor.opacity(0.6)],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .frame(width: barWidth)
                            .neonSweep(barColor)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(alignment: .trailing) {
                                if phase && score > 0 {
                                    Circle()
                                        .fill(.white)
                                        .frame(width: 8, height: 8)
                                        .shadow(color: barColor.opacity(0.9), radius: 8)
                                        .padding(.trailing, 6)
                                }
                            }
                            .animation(.spring(response: 1.2, dampingFraction: 0.7), value: phase)
                    }
                    RoundedRectangle(cornerRadius: 8)
                        .fill(barColor.opacity(phase ? 0.2 : 0))
                        .frame(width: barWidth)
                        .blur(radius: 10)
                        .offset(y: 3)
                        .animation(.spring(response: 1.2, dampingFraction: 0.7), value: phase)
                }
                .frame(height: 16)

                if let readiness = appState.readiness {
                    HStack(spacing: 8) {
                        readinessSubPill(label: "Physio", score: readiness.physiologicalScore)
                        readinessSubPill(label: "Load", score: readiness.workloadScore)
                        readinessSubPill(label: "Altitude", score: readiness.altitudeScore)
                    }
                    .padding(.top, 16)
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "hand.tap.fill")
                            .font(.system(size: 12))
                        Text("Tap to assess your summit readiness")
                            .font(.app(size: 13, weight: .medium))
                    }
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .padding(.top, 14)
                }
            }
            .padding(DesignSystem.Spacing.cardPadding)
            .padding(.vertical, 6)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.xl, style: .continuous)
                        .fill(DesignSystem.Colors.cardBackground)
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.xl, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [barColor.opacity(0.08), .clear],
                                center: .topLeading,
                                startRadius: 0,
                                endRadius: 350
                            )
                        )
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.xl, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [barColor.opacity(0.04), .clear],
                                center: .bottomTrailing,
                                startRadius: 0,
                                endRadius: 250
                            )
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.xl, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [barColor.opacity(0.2), Color.white.opacity(0.05), barColor.opacity(0.08)],
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

    // MARK: - Rank Card

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

    // MARK: - Dashboard Grid

    private var dashboardGrid: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
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
                            Text("\(feedVM.recentTours.filter { $0.isCurrentUser }.count)")
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

    // MARK: - Alpine Weather

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
