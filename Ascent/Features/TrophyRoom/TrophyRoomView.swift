import SwiftUI
import PhotosUI
import CoreLocation
import Combine
import SafariServices
import MapKit

// =========================================
// === DATEI: TrophyRoomView.swift ===
// === Profile & Achievements — Premium ===
// =========================================

// =========================================
// MARK: - Achievement System
// =========================================

enum AchievementCategory: String, CaseIterable {
    case milestone = "Milestones"
    case weekly = "Weekly"
    case social = "Social"
    case explorer = "Explorer"
    
    var icon: String {
        switch self {
        case .milestone: return "star.fill"
        case .weekly: return "flame.fill"
        case .social: return "person.2.fill"
        case .explorer: return "map.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .milestone: return Color(red: 0.85, green: 0.65, blue: 0.13)
        case .weekly: return .orange
        case .social: return .cyan
        case .explorer: return .green
        }
    }
}

struct Achievement: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let icon: String
    let category: AchievementCategory
    let isUnlocked: Bool
    let progress: Double // 0.0 to 1.0
    let progressText: String // e.g. "3/5 tours"
}

// Computed achievements from real AppState data
struct AchievementEngine {
    
    static func compute(from appState: AppState) -> [Achievement] {
        let tourCount = appState.recentTours.filter { $0.isCurrentUser }.count
        let totalElevation = appState.recentTours.filter { $0.isCurrentUser }.reduce(0) { $0 + $1.elevationGainMeters }
        let friendCount = appState.friendsLeaderboard.count - 1 // minus self
        let currentLevel = appState.currentLevel
        let weeklyElev = appState.weeklyElevation
        let weeklyTours = appState.weeklyTourCount
        
        var achievements: [Achievement] = []
        
        // === MILESTONE BADGES ===
        achievements.append(Achievement(
            title: "First Summit",
            description: "Complete your first mission",
            icon: "mountain.2.fill",
            category: .milestone,
            isUnlocked: tourCount >= 1,
            progress: min(Double(tourCount) / 1.0, 1.0),
            progressText: "\(min(tourCount, 1))/1"
        ))
        
        achievements.append(Achievement(
            title: "Five Alive",
            description: "Complete 5 missions",
            icon: "hand.raised.fill",
            category: .milestone,
            isUnlocked: tourCount >= 5,
            progress: min(Double(tourCount) / 5.0, 1.0),
            progressText: "\(min(tourCount, 5))/5"
        ))
        
        achievements.append(Achievement(
            title: "Summit Collector",
            description: "Complete 25 missions",
            icon: "trophy.fill",
            category: .milestone,
            isUnlocked: tourCount >= 25,
            progress: min(Double(tourCount) / 25.0, 1.0),
            progressText: "\(min(tourCount, 25))/25"
        ))
        
        achievements.append(Achievement(
            title: "Century Club",
            description: "Complete 100 missions",
            icon: "crown.fill",
            category: .milestone,
            isUnlocked: tourCount >= 100,
            progress: min(Double(tourCount) / 100.0, 1.0),
            progressText: "\(min(tourCount, 100))/100"
        ))
        
        // === LEVEL MILESTONES ===
        achievements.append(Achievement(
            title: "Level 5",
            description: "Reach Mountaineer rank",
            icon: "figure.hiking",
            category: .milestone,
            isUnlocked: currentLevel >= 5,
            progress: min(Double(currentLevel) / 5.0, 1.0),
            progressText: "Lv.\(currentLevel)/5"
        ))
        
        achievements.append(Achievement(
            title: "Level 10",
            description: "Reach seasoned Mountaineer",
            icon: "triangle.fill",
            category: .milestone,
            isUnlocked: currentLevel >= 10,
            progress: min(Double(currentLevel) / 10.0, 1.0),
            progressText: "Lv.\(currentLevel)/10"
        ))
        
        achievements.append(Achievement(
            title: "Level 20",
            description: "Become an Expeditionist",
            icon: "star.circle.fill",
            category: .milestone,
            isUnlocked: currentLevel >= 20,
            progress: min(Double(currentLevel) / 20.0, 1.0),
            progressText: "Lv.\(currentLevel)/20"
        ))
        
        // === EXPLORER BADGES ===
        achievements.append(Achievement(
            title: "Elevation Hunter",
            description: "Gain 10,000m total elevation",
            icon: "arrow.up.right.circle.fill",
            category: .explorer,
            isUnlocked: totalElevation >= 10000,
            progress: min(Double(totalElevation) / 10000.0, 1.0),
            progressText: "\(totalElevation)/10,000m"
        ))
        
        achievements.append(Achievement(
            title: "Sky Walker",
            description: "Gain 50,000m total elevation",
            icon: "cloud.fill",
            category: .explorer,
            isUnlocked: totalElevation >= 50000,
            progress: min(Double(totalElevation) / 50000.0, 1.0),
            progressText: "\(totalElevation)/50,000m"
        ))
        
        achievements.append(Achievement(
            title: "Dawn Patrol",
            description: "Log your first mission",
            icon: "sun.and.horizon.fill",
            category: .explorer,
            isUnlocked: tourCount >= 1,
            progress: min(Double(tourCount) / 1.0, 1.0),
            progressText: tourCount >= 1 ? "Earned" : "Not yet"
        ))
        
        // === WEEKLY BADGES ===
        achievements.append(Achievement(
            title: "Iron Legs",
            description: "Hit 5,000m elevation in one week",
            icon: "bolt.fill",
            category: .weekly,
            isUnlocked: weeklyElev >= 5000,
            progress: min(Double(weeklyElev) / 5000.0, 1.0),
            progressText: "\(weeklyElev)/5,000m"
        ))
        
        achievements.append(Achievement(
            title: "Week Warrior",
            description: "Complete 3 missions in one week",
            icon: "flame.fill",
            category: .weekly,
            isUnlocked: weeklyTours >= 3,
            progress: min(Double(weeklyTours) / 3.0, 1.0),
            progressText: "\(min(weeklyTours, 3))/3"
        ))
        
        // === SOCIAL BADGES ===
        achievements.append(Achievement(
            title: "Social Climber",
            description: "Add 3 friends to your crew",
            icon: "person.2.fill",
            category: .social,
            isUnlocked: friendCount >= 3,
            progress: min(Double(max(friendCount, 0)) / 3.0, 1.0),
            progressText: "\(max(friendCount, 0))/3"
        ))
        
        achievements.append(Achievement(
            title: "Party Leader",
            description: "Add 10 friends to your crew",
            icon: "person.3.fill",
            category: .social,
            isUnlocked: friendCount >= 10,
            progress: min(Double(max(friendCount, 0)) / 10.0, 1.0),
            progressText: "\(max(friendCount, 0))/10"
        ))
        
        return achievements
    }
}

// =========================================
// MARK: - Location Fetcher
// =========================================

class LocationFetcher: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var detectedRegion: String?
    @Published var isFetching = false
    
    override init() {
        super.init()
        manager.delegate = self
    }
    
    func fetchRegion() {
        isFetching = true
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else {
            DispatchQueue.main.async { self.isFetching = false }
            return
        }
        Task {
            do {
                guard let request = MKReverseGeocodingRequest(location: location) else {
                    DispatchQueue.main.async { self.isFetching = false }
                    return
                }
                let mapItems = try await request.mapItems
                DispatchQueue.main.async {
                    self.isFetching = false
                    if let mapItem = mapItems.first {
                        let rep = mapItem.addressRepresentations
                        self.detectedRegion = rep?.regionName ?? rep?.cityName ?? ""
                    }
                }
            } catch {
                DispatchQueue.main.async { self.isFetching = false }
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async { self.isFetching = false }
    }
}

// =========================================
// MARK: - Trophy Room View (Profile)
// =========================================

enum ProfileTab: String, CaseIterable {
    case missions = "Missions"
    case saved = "Saved"
    case collections = "Collections"
}

// =========================================
// MARK: - Profile Widget System
// =========================================

enum ProfileWidget: String, CaseIterable, Identifiable, Codable {
    case rank, equipment, logbook, achievements
    var id: String { rawValue }
    var title: String {
        switch self {
        case .rank: return "Alpinist Rank"
        case .equipment: return "Equipment"
        case .logbook: return "Logbook & Collections"
        case .achievements: return "Achievements"
        }
    }
    var icon: String {
        switch self {
        case .rank: return "rosette"
        case .equipment: return "tshirt.fill"
        case .logbook: return "book.closed.fill"
        case .achievements: return "medal.fill"
        }
    }
}

struct TrophyRoomView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var profileVM: ProfileViewModel

    @State private var showEditProfile = false
    @State private var progressAnimated = false
    @State private var showSettings = false
    @State private var showAscendRank = false
    @State private var animateIn = false
    @State private var selectedCategory: AchievementCategory? = nil
    @State private var selectedAchievement: Achievement? = nil
    @State private var showAllAchievements = false
    @State private var selectedProfileTab: ProfileTab = .missions
    @State private var showAllActivities = false
    @State private var showAllSavedTours = false

    // Persisted widget order
    @AppStorage("profileWidgetOrder") private var widgetOrderRaw: String = "rank,equipment,logbook,achievements"
    @State private var showLayoutEditor = false

    private var widgetOrder: [ProfileWidget] {
        let parts = widgetOrderRaw.split(separator: ",").map(String.init)
        var seen = Set<String>()
        var out: [ProfileWidget] = []
        for p in parts {
            if let w = ProfileWidget(rawValue: p), seen.insert(p).inserted { out.append(w) }
        }
        // Append any missing widgets at the end (forward compatibility)
        for w in ProfileWidget.allCases where !seen.contains(w.rawValue) { out.append(w) }
        return out
    }
    private func setWidgetOrder(_ order: [ProfileWidget]) {
        widgetOrderRaw = order.map { $0.rawValue }.joined(separator: ",")
    }
    
    private let gold = DesignSystem.Colors.accent
    private let cardBg = DesignSystem.Colors.surfaceElevated
    private var bg: some View { DesignSystem.Colors.background }


    private var requiredXP: Int { appState.xpNeededForNextLevel }
    private var xpProgress: Double {
        guard requiredXP > 0 else { return 0 }
        return Double(appState.currentLevelProgressXP) / Double(requiredXP)
    }
    
    private var achievements: [Achievement] {
        AchievementEngine.compute(from: appState)
    }
    
    private var filteredAchievements: [Achievement] {
        if let cat = selectedCategory {
            return achievements.filter { $0.category == cat }
        }
        return achievements
    }
    
    private var unlockedCount: Int {
        achievements.filter { $0.isUnlocked }.count
    }
    
    private var tierColor: Color {
        guard let profile = appState.ascendProfile else { return Color(red: 0.8, green: 0.45, blue: 0.15) }
        switch profile.ascend_tier.lowercased() {
        case "bronze": return Color(red: 0.8, green: 0.45, blue: 0.15)
        case "silver": return Color(red: 0.7, green: 0.75, blue: 0.8)
        case "gold": return Color(red: 0.95, green: 0.8, blue: 0.2)
        case "platinum": return Color(red: 0.7, green: 0.5, blue: 0.95)
        case "obsidian": return Color(red: 0.2, green: 0.1, blue: 0.3)
        default: return Color(red: 0.8, green: 0.45, blue: 0.15)
        }
    }
    
    private var totalTours: Int {
        appState.recentTours.filter { $0.isCurrentUser }.count
    }
    
    private var totalElevation: Int {
        appState.recentTours.filter { $0.isCurrentUser }.reduce(0) { $0 + $1.elevationGainMeters }
    }

    var body: some View {
        ZStack {
            ZStack {
                bg.ignoresSafeArea()

                // One soft accent halo near top — premium, calm
                Circle()
                    .fill(DesignSystem.Colors.accent.opacity(0.08))
                    .frame(width: 420, height: 420)
                    .blur(radius: 90)
                    .offset(y: -240)
            }
            .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    
                    // ============================================
                    // MARK: - TOP BAR
                    // ============================================
                    HStack {
                        Text("Profile")
                            .font(.app(size: 28, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                        
                        Button(action: { showLayoutEditor = true }) {
                            Image(systemName: "square.grid.2x2.fill")
                                .font(.app(size: 18))
                                .foregroundColor(.gray)
                        }
                        .padding(.trailing, 10)

                        Button(action: { showEditProfile = true }) {
                            Image(systemName: "pencil.circle.fill")
                                .font(.app(size: 22))
                                .foregroundColor(gold)
                        }
                        .padding(.trailing, 8)

                        Button(action: { showSettings = true }) {
                            Image(systemName: "gearshape.fill")
                                .font(.app(size: 20))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 20)
                    
                    // ============================================
                    // MARK: - PROFILE HEADER CARD
                    // ============================================
                    VStack(spacing: 18) {
                        // Avatar with tier ring
                        HStack(spacing: 18) {
                            ZStack {
                                // Tier progress ring
                                Circle()
                                    .stroke(tierColor.opacity(0.2), lineWidth: 3.5)
                                    .frame(width: 82, height: 82)
                                Circle()
                                    .trim(from: 0, to: progressAnimated ? xpProgress : 0)
                                    .stroke(tierColor, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                                    .frame(width: 82, height: 82)
                                    .rotationEffect(.degrees(-90))
                                
                                if let urlString = profileVM.avatarURL, let url = URL(string: urlString) {
                                    CachedAsyncImage(url: url) { image in
                                        image.resizable().scaledToFill()
                                    } placeholder: {
                                        Circle().fill(cardBg)
                                    }
                                    .frame(width: 72, height: 72)
                                    .clipShape(Circle())
                                } else {
                                    Circle()
                                        .fill(cardBg)
                                        .frame(width: 72, height: 72)
                                        .overlay(
                                            Image(systemName: "person.fill")
                                                .font(.app(size: 28))
                                                .foregroundColor(.gray)
                                        )
                                }
                                
                                // Level badge
                                Text("\(appState.currentLevel)")
                                    .font(.app(size: 11, weight: .black))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(tierColor)
                                    .clipShape(Capsule())
                                    .offset(x: 28, y: 30)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(profileVM.userName)
                                    .font(.app(size: 22, weight: .bold))
                                    .foregroundColor(.white)
                                
                                HStack(spacing: 8) {
                                    Text("@\(profileVM.userHandle)")
                                        .font(.app(size: 14))
                                        .foregroundColor(.gray)
                                    
                                    if !profileVM.instaHandle.isEmpty {
                                        Button(action: { openInstagram(profileVM.instaHandle) }) {
                                            HStack(spacing: 3) {
                                                Image(systemName: "camera.circle.fill")
                                                    .font(.app(size: 11))
                                                Text("@\(profileVM.instaHandle)")
                                                    .font(.app(size: 11, weight: .semibold))
                                            }
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(
                                                LinearGradient(colors: [Color.pink.opacity(0.18), Color.purple.opacity(0.18)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                            )
                                            .foregroundColor(.pink)
                                            .clipShape(Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                
                                if !profileVM.userRegion.isEmpty && profileVM.userRegion != "Unknown" {
                                    HStack(spacing: 4) {
                                        Image(systemName: "location.fill")
                                            .font(.app(size: 9))
                                        Text(profileVM.userRegion)
                                            .font(.app(size: 12, weight: .medium))
                                    }
                                    .foregroundColor(gold)
                                    .padding(.top, 2)
                                }
                            }
                            
                            Spacer()
                        }
                        
                        // Sport tags & Hobbies
                        VStack(alignment: .leading, spacing: 8) {
                            if !profileVM.selectedSports.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(profileVM.selectedSports, id: \.self) { sport in
                                            Text(sport)
                                                .font(.app(size: 11, weight: .semibold))
                                                .foregroundColor(.black.opacity(0.7))
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 5)
                                                .background(Color.gray.opacity(0.1))
                                                .clipShape(Capsule())
                                        }
                                    }
                                }
                            }
                            
                            if !profileVM.mountaineeringSpecialties.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(profileVM.mountaineeringSpecialties, id: \.self) { specialty in
                                            HStack(spacing: 4) {
                                                Image(systemName: "mountain.2.fill")
                                                    .font(.app(size: 9))
                                                Text(specialty)
                                            }
                                            .font(.app(size: 11, weight: .bold))
                                            .foregroundColor(DesignSystem.Colors.accent)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(DesignSystem.Colors.accent.opacity(0.1))
                                            .clipShape(Capsule())
                                        }
                                    }
                                }
                            }
                            
                            if !profileVM.otherHobbies.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(profileVM.otherHobbies, id: \.self) { hobby in
                                            Text(hobby)
                                                .font(.app(size: 11, weight: .semibold))
                                                .foregroundColor(.black.opacity(0.7))
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 5)
                                                .background(Color.gray.opacity(0.1))
                                                .clipShape(Capsule())
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Stats row
                        HStack(spacing: 0) {
                            ProfileStatItem(
                                value: "\(appState.currentXP)",
                                label: "XP",
                                color: gold
                            )
                            
                            Rectangle()
                                .fill(Color.white.opacity(0.06))
                                .frame(width: 1, height: 32)
                            
                            ProfileStatItem(
                                value: "\(totalTours)",
                                label: "Missions",
                                color: .cyan
                            )
                            
                            Rectangle()
                                .fill(Color.white.opacity(0.06))
                                .frame(width: 1, height: 32)
                            
                            ProfileStatItem(
                                value: formatElevation(totalElevation),
                                label: "Elevation",
                                color: .green
                            )
                        }
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(DesignSystem.Colors.surface)
                                .environment(\.colorScheme, .light)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
                        )
                    }
                    .padding(20)
                    .background(DesignSystem.Colors.surface)
                    .environment(\.colorScheme, .light)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
                    )
                    .padding(.horizontal, 20)
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : 16)
                    
                    // ============================================
                    // MARK: - WIDGET STACK (reorderable)
                    // ============================================
                    VStack(spacing: 20) {
                        ForEach(widgetOrder) { widget in
                            widgetView(widget)
                                .transition(.opacity)
                        }
                    }
                    .padding(.top, 20)
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : 10)
                    .animation(.easeInOut(duration: 0.25), value: widgetOrderRaw)

                    Spacer().frame(height: 130)
                }
            }
        }
        .onAppear {
            appState.fetchAscendProfile()
            withAnimation(.spring(response: 0.7, dampingFraction: 0.85).delay(0.1)) {
                animateIn = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 1.0, dampingFraction: 0.8)) {
                    progressAnimated = true
                }
            }
        }
        .sheet(isPresented: $showEditProfile) { EditAccountView() }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showAscendRank) { AscendProgressView() }
        .sheet(item: $selectedAchievement) { achievement in
            AchievementDetailSheet(achievement: achievement)
                .presentationDetents([.medium])
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showAllAchievements) {
            AllAchievementsSheet(achievements: achievements, unlockedCount: unlockedCount)
        }
        .sheet(isPresented: $showLayoutEditor) {
            ProfileLayoutEditor(order: widgetOrder) { newOrder in
                setWidgetOrder(newOrder)
            }
            .presentationDetents([.medium, .large])
            .preferredColorScheme(.dark)
        }
    }

    // MARK: - Widget builder
    @ViewBuilder
    private func widgetView(_ widget: ProfileWidget) -> some View {
        switch widget {
        case .rank: rankWidget
        case .equipment: equipmentWidget
        case .logbook: logbookWidget
        case .achievements: achievementsWidget
        }
    }

    private var rankWidget: some View {
        Button(action: { showAscendRank = true }) {
                        HStack(spacing: 15) {
                            if let profile = appState.ascendProfile {
                                let tColor = tierColor
                                let isObsidian = profile.ascend_tier.lowercased() == "obsidian"
                                
                                GemView(isActive: true, color: tColor, isObsidian: isObsidian)
                                    .scaleEffect(0.9)
                                    .frame(width: 45, height: 45)
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Alpinist Rank")
                                        .font(.app(.caption))
                                        .foregroundColor(.gray)
                                    
                                    HStack(alignment: .bottom, spacing: 5) {
                                        Text("\(profile.ascend_tier) \(String(repeating: "I", count: profile.ascend_subtier))")
                                            .font(.app(.headline))
                                            .fontWeight(.bold)
                                            .foregroundColor(isObsidian ? .black : tColor)
                                        
                                        Spacer()
                                        
                                        Text("\(Int(profile.ascend_xp)) XP")
                                            .font(.app(.caption))
                                            .foregroundColor(.gray)
                                    }
                                    
                                    GeometryReader { geo in
                                        let progress = max(0, min(Double(appState.currentLevelProgressXP) / Double(max(appState.xpNeededForNextLevel, 1)), 1.0))
                                        ZStack(alignment: .leading) {
                                            Capsule().fill(Color.gray.opacity(0.1)).frame(height: 6)
                                            Capsule().fill(tColor)
                                                .frame(width: progressAnimated ? geo.size.width * progress : 0, height: 6)
                                        }
                                    }.frame(height: 6)
                                }
                            } else {
                                ProgressView().tint(.gray)
                                Text("Loading Rank...").foregroundColor(.gray).padding(.leading, 10)
                                Spacer()
                            }
                            
                            Image(systemName: "chevron.right").font(.app(.caption)).foregroundColor(.gray)
                        }
                        .padding(20)
                        .background(DesignSystem.Colors.surface)
                        .environment(\.colorScheme, .light)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
    }

    // MARK: - Equipment widget
    private var equipmentWidget: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "tshirt.fill")
                    .font(.app(size: 14, weight: .bold))
                    .foregroundColor(.orange)
                Text("Equipment")
                    .font(.app(size: 19, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                Button(action: { /* edit equipment hook */ }) {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                            .font(.app(size: 11, weight: .bold))
                        Text("Edit")
                            .font(.app(size: 12, weight: .bold))
                    }
                    .foregroundColor(gold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(gold.opacity(0.1))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 20)

            EquipmentLockerView(equipment: profileVM.equipment)
        }
    }

    // MARK: - Logbook widget
    private var logbookWidget: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("Profile Tabs", selection: $selectedProfileTab) {
                ForEach(ProfileTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal, 20)

            switch selectedProfileTab {
            case .missions:
                let myTours = appState.recentTours.filter { $0.isCurrentUser }
                if myTours.isEmpty {
                    Text("No missions completed yet.")
                        .font(.app(.subheadline))
                        .foregroundColor(.gray)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                } else {
                    VStack(spacing: 16) {
                        ForEach(myTours.prefix(3)) { tour in
                            ActivityCardView(tour: tour)
                                .padding(.horizontal, 16)
                        }
                        if myTours.count > 3 {
                            Button(action: { showAllActivities = true }) {
                                Text("See All (\(myTours.count))")
                                    .font(.app(.headline))
                                    .foregroundColor(gold)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(gold.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
                }
            case .saved:
                if appState.bookmarkedTours.isEmpty {
                    Text("No saved tours from the community yet.")
                        .font(.app(.subheadline))
                        .foregroundColor(.gray)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                } else {
                    VStack(spacing: 16) {
                        ForEach(appState.bookmarkedTours.prefix(3)) { tour in
                            ActivityCardView(tour: tour)
                                .padding(.horizontal, 16)
                        }
                        if appState.bookmarkedTours.count > 3 {
                            Button(action: { showAllSavedTours = true }) {
                                Text("See All (\(appState.bookmarkedTours.count))")
                                    .font(.app(.headline))
                                    .foregroundColor(.cyan)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.cyan.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
                }
            case .collections:
                ProfileCollectionsList()
                    .environmentObject(appState)
            }
        }
    }

    // MARK: - Achievements widget
    private var achievementsWidget: some View {
        Button(action: { showAllAchievements = true }) {
            HStack(alignment: .center, spacing: 15) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(gold.opacity(0.1))
                        .frame(width: 48, height: 48)
                    Image(systemName: "medal.fill")
                        .font(.app(size: 20))
                        .foregroundColor(gold)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Achievements")
                        .font(.app(.headline))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("\(unlockedCount) / \(achievements.count) Unlocked")
                        .font(.app(.caption))
                        .foregroundColor(.gray)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.app(.caption))
                    .foregroundColor(.gray)
            }
            .padding(DesignSystem.Spacing.md)
            .background(DesignSystem.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
                    .stroke(Color.black.opacity(0.04), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }

    private func openInstagram(_ handle: String) {
        let cleaned = handle.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "@", with: "")
        guard !cleaned.isEmpty else { return }
        if let appURL = URL(string: "instagram://user?username=\(cleaned)"),
           UIApplication.shared.canOpenURL(appURL) {
            UIApplication.shared.open(appURL)
        } else if let webURL = URL(string: "https://instagram.com/\(cleaned)") {
            UIApplication.shared.open(webURL)
        }
    }

    private func formatElevation(_ m: Int) -> String {
        if m >= 10000 {
            return String(format: "%.1fk", Double(m) / 1000.0)
        }
        return "\(m)m"
    }
}

// =========================================
// MARK: - Profile Stat Item
// =========================================

struct ProfileStatItem: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.app(size: 18, weight: .bold))
                .foregroundColor(.white)
            Text(label)
                .font(.app(size: 10, weight: .semibold))
                .foregroundColor(color.opacity(0.7))
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
    }
}

// =========================================
// MARK: - Category Filter Pill
// =========================================

struct CategoryFilterPill: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.app(size: 10, weight: .bold))
                Text(title)
                    .font(.app(size: 12, weight: .bold))
            }
            .foregroundColor(isSelected ? .black : .gray)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isSelected ? color : Color.gray.opacity(0.1)
            )
            .clipShape(Capsule())
        }
    }
}

// =========================================
// MARK: - Achievement Badge Card
// =========================================

struct AchievementBadgeCard: View {
    let achievement: Achievement
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            achievement.isUnlocked
                                ? achievement.category.color.opacity(0.12)
                                : Color.gray.opacity(0.05)
                        )
                        .frame(height: 76)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    achievement.isUnlocked
                                        ? achievement.category.color.opacity(0.25)
                                        : Color.black.opacity(0.04),
                                    lineWidth: 1
                                )
                        )
                    
                    if achievement.isUnlocked {
                        Image(systemName: achievement.icon)
                            .font(.app(size: 28))
                            .foregroundColor(achievement.category.color)
                    } else {
                        ZStack {
                            Image(systemName: achievement.icon)
                                .font(.app(size: 28))
                                .foregroundColor(.gray.opacity(0.15))
                            
                            Image(systemName: "lock.fill")
                                .font(.app(size: 12))
                                .foregroundColor(.gray.opacity(0.3))
                                .offset(x: 14, y: 14)
                        }
                    }
                }
                
                Text(achievement.title)
                    .font(.app(size: 11, weight: .bold))
                    .foregroundColor(achievement.isUnlocked ? .primary : .gray.opacity(0.4))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                // Progress indicator
                if !achievement.isUnlocked {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.gray.opacity(0.1))
                                .frame(height: 3)
                            Capsule()
                                .fill(achievement.category.color.opacity(0.5))
                                .frame(width: max(2, geo.size.width * achievement.progress), height: 3)
                        }
                    }
                    .frame(height: 3)
                    .padding(.horizontal, 4)
                } else {
                    // Earned indicator
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.app(size: 8))
                        Text("Earned")
                            .font(.app(size: 9, weight: .semibold))
                    }
                    .foregroundColor(achievement.category.color.opacity(0.6))
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// =========================================
// MARK: - Achievement Detail Sheet
// =========================================

struct AchievementDetailSheet: View {
    let achievement: Achievement
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            DesignSystem.Colors.background.ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Handle
                Capsule()
                    .fill(Color.black.opacity(0.2))
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)
                
                // Badge
                ZStack {
                    Circle()
                        .fill(
                            achievement.isUnlocked
                                ? achievement.category.color.opacity(0.12)
                                : Color.gray.opacity(0.05)
                        )
                        .frame(width: 100, height: 100)
                    
                    if achievement.isUnlocked {
                        Circle()
                            .fill(achievement.category.color.opacity(0.06))
                            .frame(width: 130, height: 130)
                        
                        Image(systemName: achievement.icon)
                            .font(.app(size: 44))
                            .foregroundColor(achievement.category.color)
                    } else {
                        Image(systemName: achievement.icon)
                            .font(.app(size: 44))
                            .foregroundColor(.gray.opacity(0.2))
                    }
                }
                
                VStack(spacing: 8) {
                    Text(achievement.title)
                        .font(.app(size: 22, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(achievement.description)
                        .font(.app(size: 15))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    
                    // Category pill
                    HStack(spacing: 5) {
                        Image(systemName: achievement.category.icon)
                            .font(.app(size: 10, weight: .bold))
                        Text(achievement.category.rawValue)
                            .font(.app(size: 11, weight: .bold))
                    }
                    .foregroundColor(achievement.category.color)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(achievement.category.color.opacity(0.12))
                    .clipShape(Capsule())
                    .padding(.top, 4)
                }
                
                // Progress
                VStack(spacing: 10) {
                    HStack {
                        Text("Progress")
                            .font(.app(size: 13, weight: .semibold))
                            .foregroundColor(.gray)
                        Spacer()
                        Text(achievement.progressText)
                            .font(.app(size: 13, weight: .bold))
                            .foregroundColor(achievement.isUnlocked ? achievement.category.color : .primary)
                    }
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.gray.opacity(0.1))
                                .frame(height: 8)
                            Capsule()
                                .fill(
                                    achievement.isUnlocked
                                        ? achievement.category.color
                                        : achievement.category.color.opacity(0.5)
                                )
                                .frame(width: max(4, geo.size.width * achievement.progress), height: 8)
                        }
                    }
                    .frame(height: 8)
                }
                .padding(DesignSystem.Spacing.lg)
                .background(DesignSystem.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                        .stroke(Color.black.opacity(0.04), lineWidth: 0.5)
                )
                .padding(.horizontal, DesignSystem.Spacing.md)
                
                Spacer()
            }
        }
    }
}

// =========================================
// MARK: - Edit Account View (Premium Dark)
// =========================================

struct EditAccountView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var profileVM: ProfileViewModel
    @Environment(\.dismiss) var dismiss
    
    @StateObject private var locationFetcher = LocationFetcher()
    
    @State private var draftName: String = ""
    @State private var draftHandle: String = ""
    @State private var draftRegion: String = ""
    @State private var draftInsta: String = ""
    @State private var photoItem: PhotosPickerItem? = nil
    @State private var draftImageData: Data? = nil
    @State private var draftSports: [String] = []
    @State private var draftHobbies: [String] = []
    @State private var draftSpecialties: [String] = []
    @State private var showHandleErrorAlert = false
    @State private var isSaving = false

    // Custom hobby input
    @State private var customHobbyInput: String = ""
    @State private var hobbySuggestions: [HobbyEntry] = []
    @State private var isSearchingHobbies: Bool = false
    @State private var hobbyInputError: String? = nil
    @State private var hobbySearchTask: Task<Void, Never>? = nil
    
    private let gold = DesignSystem.Colors.accent
    private let cardBg = DesignSystem.Colors.surfaceElevated

    let availableSports = [
        "Mountaineering", "Climbing", "Ski Touring", "Hiking", "Bouldering", "Ice Climbing", "Alpinism",
        "Trail Running", "Ultra Running", "Fastpacking", "Paragliding", "Speedflying",
        "Mountain Biking", "Gravel Biking", "Bikepacking",
        "Freeride Skiing", "Splitboarding", "Snowshoeing",
        "Kayaking", "Packrafting", "Canyoning", "Caving"
    ]
    let availableSpecialties = [
        "Ice Climbing", "Mixed Climbing", "Dry Tooling", "Scrambling",
        "Bouldering", "Highball Bouldering", "Lead Climbing", "Sport Climbing",
        "Trad Climbing", "Aid Climbing", "Big Wall", "Multi-pitch", "Alpine Climbing",
        "Expedition", "Klettersteig / Via Ferrata", "Deep Water Solo", "Free Solo",
        "Crack Climbing", "Slab Climbing", "Roof Climbing",
        "Ski Mountaineering", "Couloir Skiing", "Glacier Travel", "Crevasse Rescue",
        "Highlining", "Slacklining"
    ]
    let availableHobbies = [
        // Fitness / gym
        "Gym", "CrossFit", "Calisthenics", "Powerlifting", "Weightlifting", "Pilates", "Yoga", "Stretching", "Mobility",
        // Combat sports
        "Boxing", "Kickboxing", "Muay Thai", "MMA", "Jiu-Jitsu", "Judo", "Karate", "Taekwondo", "Wrestling", "Fencing",
        // Ball sports
        "Soccer", "Basketball", "Tennis", "Table Tennis", "Badminton", "Squash", "Volleyball",
        "Baseball", "Rugby", "Hockey", "Handball", "Golf", "Bowling",
        // Running / endurance
        "Running", "Marathon", "Triathlon", "Swimming", "Cycling", "Rowing",
        // Water
        "Surfing", "Kitesurfing", "Windsurfing", "Wakeboarding", "Sailing", "Diving", "Freediving", "SUP",
        // Board / wheels
        "Skateboarding", "Snowboarding", "Skiing", "Longboarding", "Inline Skating", "Parkour", "Freerunning",
        // Horse / outdoors
        "Horseback Riding", "Archery", "Fishing", "Hunting", "Camping", "Birdwatching", "Gardening",
        // Creative
        "Photography", "Videography", "Drawing", "Painting", "Sculpting", "Writing", "Blogging", "Podcasting",
        "Music", "Guitar", "Piano", "Drums", "Singing", "DJing", "Dancing",
        // Mind / indoor
        "Reading", "Chess", "Meditation", "Cooking", "Baking", "Coffee", "Wine Tasting",
        "Traveling", "Gaming", "Board Games", "Astronomy",
        // Tech / maker
        "Coding", "Electronics", "Robotics", "3D Printing", "Woodworking", "DIY"
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        
                        // === PHOTO SECTION ===
                        VStack(spacing: 14) {
                            ZStack(alignment: .bottomTrailing) {
                                if let data = draftImageData, let uiImage = UIImage(data: data) {
                                    Image(uiImage: uiImage)
                                        .resizable().scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(gold.opacity(0.3), lineWidth: 2))
                                } else if let urlString = profileVM.avatarURL, let url = URL(string: urlString) {
                                    CachedAsyncImage(url: url) { image in
                                        image.resizable().scaledToFill()
                                    } placeholder: {
                                        Circle().fill(cardBg)
                                    }
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 2))
                                } else {
                                    Circle()
                                        .fill(cardBg)
                                        .frame(width: 100, height: 100)
                                        .overlay(
                                            Image(systemName: "person.fill")
                                                .font(.app(size: 36))
                                                .foregroundColor(.gray)
                                        )
                                        .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 2))
                                }
                                
                                PhotosPicker(selection: $photoItem, matching: .images) {
                                    ZStack {
                                        Circle().fill(gold).frame(width: 32, height: 32)
                                        Image(systemName: "camera.fill")
                                            .font(.app(size: 13, weight: .bold))
                                            .foregroundColor(.black)
                                    }
                                    .overlay(Circle().stroke(Color(red: 0.05, green: 0.05, blue: 0.08), lineWidth: 3))
                                }
                            }
                        }
                        .padding(.top, 20)
                        
                        // === PROFILE INFO SECTION ===
                        VStack(alignment: .leading, spacing: 16) {
                            Text("PROFILE INFO")
                                .font(.app(size: 11, weight: .black))
                                .foregroundColor(.gray)
                                .tracking(2)
                            
                            EditField(icon: "person.fill", placeholder: "Display Name", text: $draftName)
                            
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.gray.opacity(0.1))
                                        .frame(width: 38, height: 38)
                                    Text("@")
                                        .font(.app(size: 16, weight: .bold))
                                        .foregroundColor(.gray)
                                }
                                TextField("username", text: $draftHandle)
                                    .font(.app(size: 15))
                                    .foregroundColor(.white)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .onChange(of: draftHandle) { _, newValue in
                                        draftHandle = newValue.replacingOccurrences(of: "@", with: "")
                                    }
                            }
                            .padding(12)
                            .background(cardBg)
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
                            )
                            
                            // Region with auto-detect
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.black.opacity(0.06))
                                        .frame(width: 38, height: 38)
                                    Image(systemName: "location.fill")
                                        .font(.app(size: 14, weight: .bold))
                                        .foregroundColor(.gray)
                                }
                                TextField("Region / State", text: $draftRegion)
                                    .font(.app(size: 15))
                                    .foregroundColor(.white)
                                
                                Button(action: { locationFetcher.fetchRegion() }) {
                                    if locationFetcher.isFetching {
                                        ProgressView().scaleEffect(0.7)
                                    } else {
                                        Text("Detect")
                                            .font(.app(size: 11, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(gold)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                            .padding(12)
                            .background(cardBg)
                            .cornerRadius(14)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.06), lineWidth: 1))
                            
                            // Instagram integration
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.pink.opacity(0.1))
                                        .frame(width: 38, height: 38)
                                    Image(systemName: "camera.circle.fill")
                                        .font(.app(size: 16, weight: .bold))
                                        .foregroundColor(.pink)
                                }
                                TextField("instagram_handle", text: $draftInsta)
                                    .font(.app(size: 15))
                                    .foregroundColor(.white)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .onChange(of: draftInsta) { _, newValue in
                                        draftInsta = newValue.replacingOccurrences(of: "@", with: "")
                                    }
                            }
                            .padding(12)
                            .background(cardBg)
                            .cornerRadius(14)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.06), lineWidth: 1))
                        }
                        .padding(.horizontal, 20)
                        
                        // === SPORTS SECTION ===
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("DISCIPLINES")
                                    .font(.app(size: 11, weight: .black))
                                    .foregroundColor(.gray)
                                    .tracking(2)
                                Spacer()
                                Text("\(draftSports.count)/4")
                                    .font(.app(size: 11, weight: .bold))
                                    .foregroundColor(draftSports.count >= 4 ? gold : .gray)
                            }
                            
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                ForEach(availableSports, id: \.self) { sport in
                                    SportButton(title: sport, isSelected: draftSports.contains(sport), maxLimit: 4, list: $draftSports, color: gold)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // === SPECIALTIES SECTION ===
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("SPECIALTIES")
                                    .font(.app(size: 11, weight: .black))
                                    .foregroundColor(.gray)
                                    .tracking(2)
                                Spacer()
                                Text("\(draftSpecialties.count)/10")
                                    .font(.app(size: 11, weight: .bold))
                                    .foregroundColor(draftSpecialties.count >= 10 ? gold : .gray)
                            }
                            
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                ForEach(availableSpecialties, id: \.self) { specialty in
                                    SportButton(title: specialty, isSelected: draftSpecialties.contains(specialty), maxLimit: 10, list: $draftSpecialties, color: DesignSystem.Colors.accent)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // === OTHER HOBBIES SECTION ===
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("OTHER HOBBIES")
                                    .font(.app(size: 11, weight: .black))
                                    .foregroundColor(.gray)
                                    .tracking(2)
                                Spacer()
                                Text("\(draftHobbies.count)/10")
                                    .font(.app(size: 11, weight: .bold))
                                    .foregroundColor(draftHobbies.count >= 10 ? gold : .gray)
                            }
                            
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                ForEach(combinedHobbies, id: \.self) { hobby in
                                    SportButton(title: hobby, isSelected: draftHobbies.contains(hobby), maxLimit: 10, list: $draftHobbies, color: .purple)
                                }
                            }

                            // --- Custom hobby input ---
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Add your own")
                                    .font(.app(size: 11, weight: .bold))
                                    .foregroundColor(.gray)
                                    .tracking(1.5)
                                    .padding(.top, 6)

                                HStack(spacing: 8) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10).fill(Color.purple.opacity(0.1))
                                            .frame(width: 38, height: 38)
                                        Image(systemName: "sparkles")
                                            .font(.app(size: 14, weight: .bold))
                                            .foregroundColor(.purple)
                                    }
                                    TextField("e.g. Archery", text: $customHobbyInput)
                                        .font(.app(size: 15))
                                        .textInputAutocapitalization(.words)
                                        .autocorrectionDisabled(false) // keep iOS autocorrect/spellcheck ON
                                        .onChange(of: customHobbyInput) { _, newValue in
                                            onCustomHobbyChanged(newValue)
                                        }
                                        .onSubmit { commitCustomHobby() }

                                    if isSearchingHobbies {
                                        ProgressView().scaleEffect(0.7)
                                    }

                                    Button(action: commitCustomHobby) {
                                        Text("Add")
                                            .font(.app(size: 12, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 12).padding(.vertical, 8)
                                            .background(Color.purple)
                                            .clipShape(Capsule())
                                    }
                                    .disabled(!HobbiesRepository.isValid(customHobbyInput) || draftHobbies.count >= 10)
                                    .opacity(HobbiesRepository.isValid(customHobbyInput) && draftHobbies.count < 10 ? 1 : 0.4)
                                }
                                .padding(12)
                                .background(cardBg)
                                .cornerRadius(14)
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.06), lineWidth: 1))

                                if let err = hobbyInputError {
                                    Text(err)
                                        .font(.app(size: 11, weight: .medium))
                                        .foregroundColor(.red)
                                }

                                // Suggestions (reuse existing community hobbies to avoid typos / duplicates)
                                if !hobbySuggestions.isEmpty {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Used by others")
                                            .font(.app(size: 10, weight: .bold))
                                            .foregroundColor(.gray)
                                            .tracking(1)
                                        FlowRow(spacing: 6) {
                                            ForEach(hobbySuggestions) { entry in
                                                Button {
                                                    addHobby(entry.name)
                                                    customHobbyInput = ""
                                                    hobbySuggestions = []
                                                } label: {
                                                    HStack(spacing: 4) {
                                                        Text(entry.name)
                                                            .font(.app(size: 12, weight: .semibold))
                                                        Text("·\(entry.usage_count)")
                                                            .font(.app(size: 10, weight: .regular))
                                                            .foregroundColor(.gray)
                                                    }
                                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                                    .background(Color.purple.opacity(0.08))
                                                    .foregroundColor(.purple)
                                                    .clipShape(Capsule())
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)

                        Spacer().frame(height: 40)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.gray)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: save) {
                        if isSaving {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Text("Save").fontWeight(.bold).foregroundColor(gold)
                        }
                    }
                    .disabled(isSaving)
                }
            }
            .onAppear {
                draftName = profileVM.userName
                draftHandle = profileVM.userHandle
                draftRegion = profileVM.userRegion == "Unknown" ? "" : profileVM.userRegion
                draftInsta = profileVM.instaHandle
                draftSports = profileVM.selectedSports
                draftSpecialties = profileVM.mountaineeringSpecialties
                draftHobbies = profileVM.otherHobbies
                draftImageData = profileVM.profileImage
            }
            .onChange(of: locationFetcher.detectedRegion) { _, newRegion in
                if let new = newRegion { draftRegion = new }
            }
            .onChange(of: photoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        draftImageData = data
                    }
                }
            }
            .alert("Username taken", isPresented: $showHandleErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("This @handle is already in use by another Alpinist. Please choose a different one.")
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // Hobbies list merged with any custom selections the user already has
    private var combinedHobbies: [String] {
        var seen = Set<String>()
        var out: [String] = []
        for h in availableHobbies + draftHobbies {
            if seen.insert(h).inserted { out.append(h) }
        }
        return out
    }

    private func addHobby(_ name: String) {
        let cleaned = HobbiesRepository.clean(name)
        guard !cleaned.isEmpty, draftHobbies.count < 10 else { return }
        if !draftHobbies.contains(where: { $0.caseInsensitiveCompare(cleaned) == .orderedSame }) {
            draftHobbies.append(cleaned)
        }
    }

    private func onCustomHobbyChanged(_ raw: String) {
        hobbyInputError = nil
        hobbySearchTask?.cancel()
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            hobbySuggestions = []
            return
        }
        isSearchingHobbies = true
        hobbySearchTask = Task {
            try? await Task.sleep(nanoseconds: 250_000_000) // debounce
            if Task.isCancelled { return }
            do {
                let results = try await HobbiesRepository.shared.search(query: trimmed)
                if Task.isCancelled { return }
                await MainActor.run {
                    self.hobbySuggestions = results
                    self.isSearchingHobbies = false
                }
            } catch {
                await MainActor.run {
                    self.hobbySuggestions = []
                    self.isSearchingHobbies = false
                }
            }
        }
    }

    private func commitCustomHobby() {
        let cleaned = HobbiesRepository.clean(customHobbyInput)
        guard HobbiesRepository.isValid(cleaned) else {
            hobbyInputError = "Use 2–40 letters. No numbers or special characters."
            return
        }
        // Prefer exact suggestion match if there is one (dedupe casing/typos)
        let canonical: String
        if let match = hobbySuggestions.first(where: { $0.normalized_name == cleaned.lowercased() }) {
            canonical = match.name
        } else {
            canonical = cleaned
        }
        addHobby(canonical)
        customHobbyInput = ""
        hobbySuggestions = []
        hobbyInputError = nil
        Task.detached { try? await HobbiesRepository.shared.register(name: canonical) }
    }

    private func save() {
        isSaving = true
        Task {
            let isSuccess = await profileVM.updateProfile(
                newName: draftName,
                newHandle: draftHandle,
                newRegion: draftRegion,
                newSports: draftSports,
                newInsta: draftInsta,
                newHobbies: draftHobbies,
                newSpecialties: draftSpecialties,
                currentXP: appState.currentXP,
                currentLevel: appState.currentLevel
            )

            if isSuccess {
                // Cross-VM side effects: mirror profile changes onto the
                // user's own tours in the local feed cache, and refresh the
                // local leaderboard (region may have changed). These move
                // into FeedViewModel / LeaderboardViewModel in their R3
                // steps; for now they live inline at the caller.
                if let session = try? await supabase.auth.session {
                    for i in appState.recentTours.indices where appState.recentTours[i].userId == session.user.id {
                        appState.recentTours[i].playerName = draftName
                        appState.recentTours[i].playerHandle = draftHandle
                        appState.recentTours[i].playerAvatarURL = profileVM.avatarURL
                    }
                }
                appState.fetchLeaderboard()

                if let newData = draftImageData, newData != profileVM.profileImage {
                    profileVM.profileImage = newData
                    await profileVM.uploadAvatar(
                        data: newData,
                        currentXP: appState.currentXP,
                        currentLevel: appState.currentLevel
                    )
                }
                await MainActor.run {
                    isSaving = false
                    dismiss()
                }
            } else {
                await MainActor.run {
                    isSaving = false
                    showHandleErrorAlert = true
                }
            }
        }
    }
}

// =========================================
// MARK: - Edit Field Helper
// =========================================

struct EditField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black.opacity(0.05))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.app(size: 14, weight: .bold))
                    .foregroundColor(.gray)
            }
            TextField(placeholder, text: $text)
                .font(.app(size: 15))
                .foregroundColor(.white)
        }
        .padding(12)
        .background(DesignSystem.Colors.surface)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
    }
}

// Helper button for selecting sports/hobbies
struct SportButton: View {
    let title: String
    let isSelected: Bool
    let maxLimit: Int
    @Binding var list: [String]
    let color: Color
    
    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                if isSelected {
                    list.removeAll { $0 == title }
                } else if list.count < maxLimit {
                    list.append(title)
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.app(size: 14))
                    .foregroundColor(isSelected ? color : .gray.opacity(0.4))
                Text(title)
                    .font(.app(size: 12, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? .white : .gray)
                Spacer()
            }
            .padding(12)
            .background(isSelected ? color : DesignSystem.Colors.surface)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.07), lineWidth: 0.5)
            )
        }
    }
}

// =========================================
// MARK: - Safari View (for Settings links)
// =========================================

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        let vc = SFSafariViewController(url: url, configuration: config)
        return vc
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

// =========================================
// MARK: - Equipment Locker View
// =========================================

struct EquipmentLockerView: View {
    let equipment: Equipment
    
    var body: some View {
        ZStack {
            // Background environment using premium gradient and frost
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(LinearGradient(colors: [Color.white, Color(red: 0.98, green: 0.98, blue: 0.99)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white, lineWidth: 2)
                )
            
            // Subtle contour lines in the background
            Image(systemName: "map.fill")
                .font(.app(size: 150))
                .foregroundColor(.black.opacity(0.02))
                .rotationEffect(.degrees(-15))
                .offset(x: 50, y: -20)
            
            // Character Silhouette
            Image(systemName: "figure.climbing")
                .font(.app(size: 160))
                .foregroundColor(.black.opacity(0.07))
                .offset(y: 10)
            
            // Equipment Slots layout around the character
            VStack(spacing: 20) {
                // Head
                EquipmentSlot(icon: "crown.fill", label: "Head", value: equipment.head, color: .orange)
                    .offset(y: -15)
                
                HStack(spacing: 90) {
                    // Jacket
                    EquipmentSlot(icon: "tshirt.fill", label: "Jacket", value: equipment.jacket, color: .blue)
                    
                    // Backpack
                    EquipmentSlot(icon: "backpack.fill", label: "Pack", value: equipment.backpack, color: .red)
                }
                
                HStack(spacing: 120) {
                    // Pants
                    EquipmentSlot(icon: "figure.walk", label: "Pants", value: equipment.pants, color: .indigo)
                        .offset(y: 10)
                    
                    // Extras
                    EquipmentSlot(icon: "sparkles", label: "Extras", value: equipment.extras, color: .orange)
                        .offset(y: 10)
                }
                
                // Boots
                EquipmentSlot(icon: "shoe.fill", label: "Boots", value: equipment.boots, color: .brown)
                    .offset(y: 30)
            }
            .padding(.vertical, 40)
        }
        .padding(.horizontal, 20)
    }
}

struct EquipmentSlot: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    @State private var showDetail = false
    
    var body: some View {
        Button(action: {
            showDetail = true
        }) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(DesignSystem.Colors.surface)
                        .frame(width: 46, height: 46)
                        .overlay(Circle().stroke(Color.white.opacity(0.07), lineWidth: 0.5))
                    
                    Image(systemName: icon)
                        .font(.app(size: 18, weight: .bold))
                        .foregroundColor(color)
                }
                
                VStack(spacing: 2) {
                    Text(value)
                        .font(.app(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .frame(width: 80)
                    
                    Text(label.uppercased())
                        .font(.app(size: 9, weight: .black))
                        .foregroundColor(.gray)
                        .tracking(1)
                }
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetail) {
            VStack(spacing: 20) {
                Image(systemName: icon)
                    .font(.app(size: 60))
                    .foregroundColor(color)
                    .padding(.top, 40)
                
                Text(label.uppercased())
                    .font(.app(size: 14, weight: .black))
                    .foregroundColor(.gray)
                    .tracking(2)
                
                Text(value)
                    .font(.app(size: 28, weight: .bold))
                
                Text("This is a preview of the equipment detail view. In the future, you will be able to select and change your \(label) gear from a vast library of items here.")
                    .font(.app(size: 15))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 30)
                    .padding(.top, 10)
                
                Spacer()
            }
            .presentationDetents([.fraction(0.45)])
            .preferredColorScheme(.dark)
        }
    }
}

// =========================================
// MARK: - All Achievements Sheet
// =========================================

struct AllAchievementsSheet: View {
    @Environment(\.dismiss) var dismiss
    let achievements: [Achievement]
    let unlockedCount: Int
    @State private var selectedAchievement: Achievement? = nil
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Stat Summary
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Total Unlocked")
                                    .font(.app(.subheadline))
                                    .foregroundColor(.gray)
                                Text("\(unlockedCount) of \(achievements.count)")
                                    .font(.app(.title))
                                    .fontWeight(.black)
                                    .foregroundColor(DesignSystem.Colors.accent)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        
                        LazyVGrid(
                            columns: [GridItem(.flexible(), spacing: 15), GridItem(.flexible(), spacing: 15), GridItem(.flexible(), spacing: 15)],
                            spacing: 15
                        ) {
                            ForEach(achievements) { achievement in
                                AchievementBadgeCard(achievement: achievement, onTap: {
                                    selectedAchievement = achievement
                                })
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Trophy Room")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                    }
                }
            }
            .sheet(item: $selectedAchievement) { achievement in
                AchievementDetailSheet(achievement: achievement)
                    .presentationDetents([.medium])
                    .preferredColorScheme(.dark)
            }
        }
    }
}

// MARK: - Profile Collections List (For Profile Tab)
struct ProfileCollectionsList: View {
    @EnvironmentObject var appState: AppState
    @State private var showCreateSheet = false
    @StateObject private var tempManager = CollectionsManager()
    @State private var selectedCollection: TourCollection?
    @State private var previewCache: [UUID: [Mountain]] = [:]

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Text("My Curated Peaks")
                    .font(.app(.headline))
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                Spacer()
                Button(action: { showCreateSheet = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.app(size: 22))
                        .foregroundColor(DesignSystem.Colors.accent)
                }
            }
            .padding(.horizontal, 20)

            if appState.myCollections.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "rectangle.stack.fill")
                        .font(.app(size: 40))
                        .foregroundColor(.gray.opacity(0.3))
                    Text("No collections yet")
                        .font(.app(.subheadline))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                    Text("Create a collection to organize your favorite peaks and routes.")
                        .font(.app(.caption))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .padding(32)
                .frame(maxWidth: .infinity)
                .background(DesignSystem.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 20)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(appState.myCollections) { collection in
                        CollectionCardView(
                            collection: collection,
                            previewMountains: previewCache[collection.id] ?? []
                        ) {
                            selectedCollection = collection
                        }
                    }
                }
                .padding(.horizontal, 20)
                .task(id: appState.myCollections) {
                    for collection in appState.myCollections {
                        if previewCache[collection.id] == nil {
                            previewCache[collection.id] = await tempManager.fetchPreviewMountains(for: collection, limit: 4)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateCollectionSheet(manager: tempManager)
        }
        .sheet(item: $selectedCollection) { collection in
            CollectionDetailSheet(collection: collection, manager: tempManager)
        }
        .onChange(of: showCreateSheet) { _, isPresented in
            if !isPresented {
                appState.fetchCollections()
            }
        }
    }
}

// =========================================
// MARK: - Profile Layout Editor
// =========================================

struct ProfileLayoutEditor: View {
    @Environment(\.dismiss) var dismiss
    @State var order: [ProfileWidget]
    let onSave: ([ProfileWidget]) -> Void

    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background.ignoresSafeArea()
                VStack(spacing: 0) {
                    Text("Long-press and drag a tile to rearrange your profile.")
                        .font(.app(size: 13))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                        .padding(.bottom, 8)

                    List {
                        ForEach(order) { widget in
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.blue.opacity(0.1))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: widget.icon)
                                        .font(.app(size: 18, weight: .bold))
                                        .foregroundColor(.blue)
                                }
                                Text(widget.title)
                                    .font(.app(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: "line.3.horizontal")
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 6)
                            .listRowBackground(DesignSystem.Colors.surface)
                        }
                        .onMove { source, destination in
                            order.move(fromOffsets: source, toOffset: destination)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .environment(\.editMode, .constant(.active))
                }
            }
            .navigationTitle("Edit Layout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.gray)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onSave(order)
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }
}

struct FilteredActivitiesView: View {
    @Environment(\.dismiss) var dismiss
    let title: String
    let tours: [Tour]
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background.ignoresSafeArea()
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(tours) { tour in
                            ActivityCardView(tour: tour)
                                .padding(.horizontal, 16)
                        }
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill").font(.app(size: 24)).foregroundColor(.gray)
                    }
                }
            }
        }
    }
}

