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

struct TrophyRoomView: View {
    @EnvironmentObject var appState: AppState
    
    @State private var showEditProfile = false
    @State private var progressAnimated = false
    @State private var showSettings = false
    @State private var showAscendRank = false
    @State private var animateIn = false
    @State private var selectedCategory: AchievementCategory? = nil
    @State private var selectedAchievement: Achievement? = nil
    
    private let gold = Color(red: 0.1, green: 0.5, blue: 0.95)
    private let cardBg = Color.white
    private let bg = Color(red: 0.95, green: 0.95, blue: 0.97)
    
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
                
                // Ambient color blobs (GPU-optimized)
                Circle()
                    .fill(RadialGradient(colors: [Color.purple.opacity(0.08), Color.clear], center: .center, startRadius: 0, endRadius: 150))
                    .frame(width: 300, height: 300)
                    .offset(x: -80, y: -100)
                Circle()
                    .fill(RadialGradient(colors: [gold.opacity(0.07), Color.clear], center: .center, startRadius: 0, endRadius: 125))
                    .frame(width: 250, height: 250)
                    .offset(x: 120, y: 300)
                Circle()
                    .fill(RadialGradient(colors: [Color.green.opacity(0.06), Color.clear], center: .center, startRadius: 0, endRadius: 100))
                    .frame(width: 200, height: 200)
                    .offset(x: -50, y: 600)
            }
            .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    
                    // ============================================
                    // MARK: - TOP BAR
                    // ============================================
                    HStack {
                        Text("Profile")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        Spacer()
                        
                        Button(action: { showEditProfile = true }) {
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 22, design: .rounded))
                                .foregroundColor(gold)
                        }
                        .padding(.trailing, 8)
                        
                        Button(action: { showSettings = true }) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 20, design: .rounded))
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
                                
                                if let urlString = appState.avatarURL, let url = URL(string: urlString) {
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
                                                .font(.system(size: 28, design: .rounded))
                                                .foregroundColor(.gray)
                                        )
                                }
                                
                                // Level badge
                                Text("\(appState.currentLevel)")
                                    .font(.system(size: 11, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(tierColor)
                                    .clipShape(Capsule())
                                    .offset(x: 28, y: 30)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(appState.userName)
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                Text("@\(appState.userHandle)")
                                    .font(.system(size: 14, design: .rounded))
                                    .foregroundColor(.gray)
                                
                                if !appState.userRegion.isEmpty && appState.userRegion != "Unknown" {
                                    HStack(spacing: 4) {
                                        Image(systemName: "location.fill")
                                            .font(.system(size: 9, design: .rounded))
                                        Text(appState.userRegion)
                                            .font(.system(size: 12, weight: .medium, design: .rounded))
                                    }
                                    .foregroundColor(gold)
                                    .padding(.top, 2)
                                }
                            }
                            
                            Spacer()
                        }
                        
                        // Sport tags
                        if !appState.selectedSports.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(appState.selectedSports, id: \.self) { sport in
                                        Text(sport)
                                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                                            .foregroundColor(.black.opacity(0.7))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(Color.gray.opacity(0.1))
                                            .clipShape(Capsule())
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
                                .fill(.ultraThinMaterial)
                                .environment(\.colorScheme, .light)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
                        )
                    }
                    .padding(20)
                    .background(.ultraThinMaterial)
                    .environment(\.colorScheme, .light)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.06), radius: 15, y: 6)
                    .padding(.horizontal, 20)
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : 16)
                    
                    // ============================================
                    // MARK: - ASCEND RANK CARD
                    // ============================================
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
                                        .font(.system(.caption, design: .rounded))
                                        .foregroundColor(.gray)
                                    
                                    HStack(alignment: .bottom, spacing: 5) {
                                        Text("\(profile.ascend_tier) \(String(repeating: "I", count: profile.ascend_subtier))")
                                            .font(.system(.headline, design: .rounded))
                                            .fontWeight(.bold)
                                            .foregroundColor(isObsidian ? .black : tColor)
                                        
                                        Spacer()
                                        
                                        Text("\(Int(profile.ascend_xp)) XP")
                                            .font(.system(.caption, design: .rounded))
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
                            
                            Image(systemName: "chevron.right").font(.system(.caption, design: .rounded)).foregroundColor(.gray)
                        }
                        .padding(20)
                        .background(.ultraThinMaterial)
                        .environment(\.colorScheme, .light)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
                        )
                        .shadow(color: .black.opacity(0.06), radius: 12, y: 6)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : 12)
                    
                    // ============================================
                    // MARK: - ACHIEVEMENTS
                    // ============================================
                    VStack(alignment: .leading, spacing: 16) {
                        // Section header
                        HStack {
                            HStack(spacing: 8) {
                                Image(systemName: "medal.fill")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(gold)
                                Text("Achievements")
                                    .font(.system(size: 19, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                            }
                            
                            Spacer()
                            
                            Text("\(unlockedCount)/\(achievements.count)")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(gold)
                        }
                        .padding(.horizontal, 20)
                        
                        // Category filter
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                CategoryFilterPill(
                                    title: "All",
                                    icon: "square.grid.2x2.fill",
                                    isSelected: selectedCategory == nil,
                                    color: gold
                                ) {
                                    withAnimation(.spring(response: 0.35)) { selectedCategory = nil }
                                }
                                
                                ForEach(AchievementCategory.allCases, id: \.rawValue) { cat in
                                    CategoryFilterPill(
                                        title: cat.rawValue,
                                        icon: cat.icon,
                                        isSelected: selectedCategory == cat,
                                        color: cat.color
                                    ) {
                                        withAnimation(.spring(response: 0.35)) { selectedCategory = cat }
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // Badge grid
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)
                            ],
                            spacing: 14
                        ) {
                            ForEach(filteredAchievements) { achievement in
                                AchievementBadgeCard(achievement: achievement, onTap: {
                                    selectedAchievement = achievement
                                })
                            }
                        }
                        .padding(.horizontal, 20)
                        .animation(.spring(response: 0.4), value: selectedCategory?.rawValue)
                    }
                    .padding(.top, 28)
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : 10)
                    
                    Spacer().frame(height: 130)
                }
            }
        }
        .onAppear {
            // Refresh profile & rank data when tab appears
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
        .sheet(isPresented: $showEditProfile) {
            EditAccountView()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showAscendRank) {
            AscendProgressView()
        }
        .sheet(item: $selectedAchievement) { achievement in
            AchievementDetailSheet(achievement: achievement)
                .presentationDetents([.medium])
                .preferredColorScheme(.light)
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
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
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
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
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
                            .font(.system(size: 28, design: .rounded))
                            .foregroundColor(achievement.category.color)
                            .shadow(color: achievement.category.color.opacity(0.4), radius: 8)
                    } else {
                        ZStack {
                            Image(systemName: achievement.icon)
                                .font(.system(size: 28, design: .rounded))
                                .foregroundColor(.gray.opacity(0.15))
                            
                            Image(systemName: "lock.fill")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundColor(.gray.opacity(0.3))
                                .offset(x: 14, y: 14)
                        }
                    }
                }
                
                Text(achievement.title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
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
                            .font(.system(size: 8, design: .rounded))
                        Text("Earned")
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
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
            Color(white: 0.98).ignoresSafeArea()
            
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
                            .font(.system(size: 44, design: .rounded))
                            .foregroundColor(achievement.category.color)
                            .shadow(color: achievement.category.color.opacity(0.5), radius: 12)
                    } else {
                        Image(systemName: achievement.icon)
                            .font(.system(size: 44, design: .rounded))
                            .foregroundColor(.gray.opacity(0.2))
                    }
                }
                
                VStack(spacing: 8) {
                    Text(achievement.title)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text(achievement.description)
                        .font(.system(size: 15, design: .rounded))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    
                    // Category pill
                    HStack(spacing: 5) {
                        Image(systemName: achievement.category.icon)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                        Text(achievement.category.rawValue)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
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
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.gray)
                        Spacer()
                        Text(achievement.progressText)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
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
                .padding(20)
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.04), radius: 10, y: 4)
                .padding(.horizontal, 20)
                
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
    @Environment(\.dismiss) var dismiss
    
    @StateObject private var locationFetcher = LocationFetcher()
    
    @State private var draftName: String = ""
    @State private var draftHandle: String = ""
    @State private var draftRegion: String = ""
    @State private var photoItem: PhotosPickerItem? = nil
    @State private var draftImageData: Data? = nil
    @State private var draftSports: [String] = []
    @State private var showHandleErrorAlert = false
    @State private var isSaving = false
    
    private let gold = Color(red: 0.1, green: 0.5, blue: 0.95)
    private let cardBg = Color.white
    
    let availableSports = ["Mountaineering", "Climbing", "Ski Touring", "Hiking", "Bouldering", "Ice Climbing", "Alpinism"]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(white: 0.98).ignoresSafeArea()
                
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
                                } else if let urlString = appState.avatarURL, let url = URL(string: urlString) {
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
                                                .font(.system(size: 36, design: .rounded))
                                                .foregroundColor(.gray)
                                        )
                                        .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 2))
                                }
                                
                                PhotosPicker(selection: $photoItem, matching: .images) {
                                    ZStack {
                                        Circle().fill(gold).frame(width: 32, height: 32)
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
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
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .foregroundColor(.gray)
                                .tracking(2)
                            
                            EditField(icon: "person.fill", placeholder: "Display Name", text: $draftName)
                            
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.gray.opacity(0.1))
                                        .frame(width: 38, height: 38)
                                    Text("@")
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundColor(.gray)
                                }
                                TextField("username", text: $draftHandle)
                                    .font(.system(size: 15, design: .rounded))
                                    .foregroundColor(.primary)
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
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundColor(.gray)
                                }
                                TextField("Region / State", text: $draftRegion)
                                    .font(.system(size: 15, design: .rounded))
                                    .foregroundColor(.primary)
                                
                                Button(action: { locationFetcher.fetchRegion() }) {
                                    if locationFetcher.isFetching {
                                        ProgressView().scaleEffect(0.7)
                                    } else {
                                        Text("Detect")
                                            .font(.system(size: 11, weight: .bold, design: .rounded))
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
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
                            )
                        }
                        .padding(.horizontal, 20)
                        
                        // === SPORTS SECTION ===
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("DISCIPLINES")
                                    .font(.system(size: 11, weight: .black, design: .rounded))
                                    .foregroundColor(.gray)
                                    .tracking(2)
                                Spacer()
                                Text("\(draftSports.count)/4")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundColor(draftSports.count >= 4 ? gold : .gray)
                            }
                            
                            LazyVGrid(
                                columns: [GridItem(.flexible()), GridItem(.flexible())],
                                spacing: 10
                            ) {
                                ForEach(availableSports, id: \.self) { sport in
                                    let isSelected = draftSports.contains(sport)
                                    Button {
                                        withAnimation(.spring(response: 0.3)) {
                                            if isSelected {
                                                draftSports.removeAll { $0 == sport }
                                            } else if draftSports.count < 4 {
                                                draftSports.append(sport)
                                            }
                                        }
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                                .font(.system(size: 14, design: .rounded))
                                                .foregroundColor(isSelected ? gold : .gray.opacity(0.4))
                                            Text(sport)
                                                .font(.system(size: 13, weight: isSelected ? .bold : .medium, design: .rounded))
                                                .foregroundColor(isSelected ? .white : .gray)
                                            Spacer()
                                        }
                                        .padding(12)
                                        .background(isSelected ? gold : cardBg)
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.black.opacity(0.04), lineWidth: 1)
                                        )
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
            .toolbarColorScheme(.light, for: .navigationBar)
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
                draftName = appState.userName
                draftHandle = appState.userHandle
                draftRegion = appState.userRegion == "Unknown" ? "" : appState.userRegion
                draftSports = appState.selectedSports
                draftImageData = appState.profileImage
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
        .preferredColorScheme(.light)
    }
    
    private func save() {
        isSaving = true
        Task {
            let isSuccess = await appState.updateProfileSettings(
                newName: draftName,
                newHandle: draftHandle,
                newRegion: draftRegion,
                newSports: draftSports
            )
            
            if isSuccess {
                if let newData = draftImageData, newData != appState.profileImage {
                    appState.profileImage = newData
                    appState.uploadProfilePicture(data: newData)
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
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.gray)
            }
            TextField(placeholder, text: $text)
                .font(.system(size: 15, design: .rounded))
                .foregroundColor(.primary)
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
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
