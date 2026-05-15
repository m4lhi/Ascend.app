import Foundation
import SwiftUI
import Combine
import Supabase
import CoreLocation

// =========================================
// === DATEI: AppState.swift ===
// === Das Gehirn der App ===
// =========================================

// --- DATENMODELLE ---

// CloudProfile lives in Core/Models/CloudProfile.swift (R3).

struct AscendProfile: Codable {
    let user_id: UUID
    var ascend_xp: Double
    var ascend_level: Int
    var ascend_tier: String
    var ascend_subtier: Int
    var streak_days: Int
    var last_activity_date: Date?
    var prestige_mountains_completed: Int
}



// CloudTour lives in Core/Models/Tour.swift (R3 step 3).

/// Lightweight encoded polyline helpers for storing route data
struct RouteEncoder {
    /// Encode an array of CLLocation into a compact JSON string of [[lat,lon,alt],...]
    static func encode(_ locations: [CLLocation]) -> String? {
        guard !locations.isEmpty else { return nil }
        // Sample down to max 200 points for storage efficiency
        let step = max(1, locations.count / 200)
        var sampled: [[Double]] = []
        for i in stride(from: 0, to: locations.count, by: step) {
            let loc = locations[i]
            sampled.append([
                (loc.coordinate.latitude * 100000).rounded() / 100000,
                (loc.coordinate.longitude * 100000).rounded() / 100000,
                loc.altitude.rounded()
            ])
        }
        // Always include the last point
        if let last = locations.last {
            let lastEntry = [
                (last.coordinate.latitude * 100000).rounded() / 100000,
                (last.coordinate.longitude * 100000).rounded() / 100000,
                last.altitude.rounded()
            ]
            if sampled.last != lastEntry { sampled.append(lastEntry) }
        }
        guard let data = try? JSONSerialization.data(withJSONObject: sampled) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Decode a JSON polyline string back into coordinates
    static func decode(_ polyline: String) -> [CLLocationCoordinate2D] {
        guard let data = polyline.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[Double]] else { return [] }
        return arr.compactMap { point in
            guard point.count >= 2 else { return nil }
            return CLLocationCoordinate2D(latitude: point[0], longitude: point[1])
        }
    }

    /// Decode a JSON polyline string back into CLLocation including altitude
    static func decodeWithAltitude(_ polyline: String) -> [CLLocation] {
        guard let data = polyline.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[Double]] else { return [] }
        return arr.compactMap { point in
            guard point.count >= 2 else { return nil }
            let lat = point[0]
            let lon = point[1]
            let alt = point.count >= 3 ? point[2] : 0
            return CLLocation(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                              altitude: alt,
                              horizontalAccuracy: 0,
                              verticalAccuracy: 0,
                              timestamp: Date())
        }
    }
}

struct PauseEntry: Codable, Identifiable {
    let id: UUID
    let startTime: Date
    let endTime: Date
    let latitude: Double
    let longitude: Double
    let isAutomatic: Bool

    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
}

// FriendshipRule lives in Core/Models/FriendshipRule.swift (R3 step 4).

// Tour / CloudFistBump / CloudComment / CloudBookmark / CommentDisplay
// live in Core/Models/Tour.swift (R3 step 3).

// HeroBannerItem lives in Core/Models/HeroBannerItem.swift (R3 step 5).

// --- EQUIPMENT MODEL ---

struct EquipmentItem: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let brand: String
    let affiliateURL: String?
    let icon: String
    
    static func == (lhs: EquipmentItem, rhs: EquipmentItem) -> Bool {
        lhs.id == rhs.id
    }
}

struct Equipment: Codable, Equatable {
    var head: String = "Beanie"
    var jacket: String = "Arc'teryx Alpha SV"
    var backpack: String = "Osprey Mutant 38"
    var pants: String = "Fjallraven Keb"
    var boots: String = "La Sportiva Nepal"
    var extras: String = "Petzl Ice Axes"
    
    // Affiliate URLs for each slot
    var headURL: String? = nil
    var jacketURL: String? = nil
    var backpackURL: String? = nil
    var pantsURL: String? = nil
    var bootsURL: String? = nil
    var extrasURL: String? = nil
}

// Equipment catalog with affiliate links
struct EquipmentCatalog {
    static let heads: [EquipmentItem] = [
        EquipmentItem(id: "h1", name: "Beanie", brand: "Patagonia", affiliateURL: nil, icon: "crown.fill"),
        EquipmentItem(id: "h2", name: "Alpine Helmet", brand: "Petzl", affiliateURL: nil, icon: "crown.fill"),
        EquipmentItem(id: "h3", name: "Sun Cap", brand: "Outdoor Research", affiliateURL: nil, icon: "crown.fill"),
        EquipmentItem(id: "h4", name: "Balaclava", brand: "Arc'teryx", affiliateURL: nil, icon: "crown.fill"),
        EquipmentItem(id: "h5", name: "Buff Headband", brand: "Buff", affiliateURL: nil, icon: "crown.fill"),
    ]
    
    static let jackets: [EquipmentItem] = [
        EquipmentItem(id: "j1", name: "Alpha SV", brand: "Arc'teryx", affiliateURL: nil, icon: "tshirt.fill"),
        EquipmentItem(id: "j2", name: "Torrentshell 3L", brand: "Patagonia", affiliateURL: nil, icon: "tshirt.fill"),
        EquipmentItem(id: "j3", name: "Bergwacht GTX", brand: "Mammut", affiliateURL: nil, icon: "tshirt.fill"),
        EquipmentItem(id: "j4", name: "Kento HS", brand: "Mammut", affiliateURL: nil, icon: "tshirt.fill"),
        EquipmentItem(id: "j5", name: "Nano Puff", brand: "Patagonia", affiliateURL: nil, icon: "tshirt.fill"),
        EquipmentItem(id: "j6", name: "Cerium Down", brand: "Arc'teryx", affiliateURL: nil, icon: "tshirt.fill"),
    ]
    
    static let backpacks: [EquipmentItem] = [
        EquipmentItem(id: "b1", name: "Mutant 38", brand: "Osprey", affiliateURL: nil, icon: "backpack.fill"),
        EquipmentItem(id: "b2", name: "Trion 28", brand: "Mammut", affiliateURL: nil, icon: "backpack.fill"),
        EquipmentItem(id: "b3", name: "Alpinist 35", brand: "Osprey", affiliateURL: nil, icon: "backpack.fill"),
        EquipmentItem(id: "b4", name: "Storm 25", brand: "Blue Ice", affiliateURL: nil, icon: "backpack.fill"),
        EquipmentItem(id: "b5", name: "Cirriform 28", brand: "Black Diamond", affiliateURL: nil, icon: "backpack.fill"),
    ]
    
    static let pantsItems: [EquipmentItem] = [
        EquipmentItem(id: "p1", name: "Keb Trousers", brand: "Fjällräven", affiliateURL: nil, icon: "figure.walk"),
        EquipmentItem(id: "p2", name: "Gamma MX", brand: "Arc'teryx", affiliateURL: nil, icon: "figure.walk"),
        EquipmentItem(id: "p3", name: "Courmayeur Pants", brand: "Salewa", affiliateURL: nil, icon: "figure.walk"),
        EquipmentItem(id: "p4", name: "Eisfeld Light", brand: "Mammut", affiliateURL: nil, icon: "figure.walk"),
    ]
    
    static let bootsItems: [EquipmentItem] = [
        EquipmentItem(id: "s1", name: "Nepal Cube", brand: "La Sportiva", affiliateURL: nil, icon: "shoe.fill"),
        EquipmentItem(id: "s2", name: "Trango Tower", brand: "La Sportiva", affiliateURL: nil, icon: "shoe.fill"),
        EquipmentItem(id: "s3", name: "Kento Advanced", brand: "Mammut", affiliateURL: nil, icon: "shoe.fill"),
        EquipmentItem(id: "s4", name: "G2 Evo", brand: "Scarpa", affiliateURL: nil, icon: "shoe.fill"),
        EquipmentItem(id: "s5", name: "Phantom 6000", brand: "Scarpa", affiliateURL: nil, icon: "shoe.fill"),
    ]
    
    static let extrasItems: [EquipmentItem] = [
        EquipmentItem(id: "e1", name: "Ice Axes", brand: "Petzl", affiliateURL: nil, icon: "hammer.fill"),
        EquipmentItem(id: "e2", name: "Trekking Poles", brand: "Black Diamond", affiliateURL: nil, icon: "hammer.fill"),
        EquipmentItem(id: "e3", name: "Headlamp", brand: "Petzl", affiliateURL: nil, icon: "hammer.fill"),
        EquipmentItem(id: "e4", name: "Crampons", brand: "Grivel", affiliateURL: nil, icon: "hammer.fill"),
        EquipmentItem(id: "e5", name: "Carabiners Set", brand: "DMM", affiliateURL: nil, icon: "hammer.fill"),
        EquipmentItem(id: "e6", name: "GPS Watch", brand: "Garmin", affiliateURL: nil, icon: "hammer.fill"),
    ]
    
    static func items(for slot: String) -> [EquipmentItem] {
        switch slot {
        case "Head": return heads
        case "Jacket": return jackets
        case "Pack": return backpacks
        case "Pants": return pantsItems
        case "Boots": return bootsItems
        case "Extras": return extrasItems
        default: return []
        }
    }
}


// --- HAUPTKLASSE ---

@MainActor
class AppState: ObservableObject {

    // Weak reference to ProfileViewModel (R3). Set by AscentApp once the
    // VM is constructed. Used by methods that still need to compose a
    // CloudProfile snapshot (fetchLeaderboard) until LeaderboardViewModel
    // takes over in R3 step 4. Symmetric to HealthCoordinator's attach
    // pattern.
    weak var profileVM: ProfileViewModel?

    // Weak reference to FeedViewModel (R3 step 3). Set by AscentApp.
    // Used by methods that still need to read/mutate the feed cache
    // (refreshReadiness, weeklyGoScores, addCompletedTour, deleteTour)
    // until further VMs / R4 take over.
    weak var feedVM: FeedViewModel?

    // Weak reference to LeaderboardViewModel (R3 step 4). Set by AscentApp.
    // Used by fetchInitialDataChain and the tour-XP-push path
    // (uploadProfileToCloud) to trigger a leaderboard refresh.
    weak var leaderboardVM: LeaderboardViewModel?

    init() {
        loadContextualPersistence()
    }

    // --- GLOBAL TRACKER STATE ---
    @Published var isTrackerActive: Bool = false
    @Published var isTrackerMinimized: Bool = false
    @Published var activeMountain: Mountain? = nil
    @Published var trackerElapsedSeconds: Int = 0
    @Published var trackerDistanceKm: Double = 0.0
    @Published var trackerElevationGain: Double = 0.0
    @Published var isTrackerPaused: Bool = false

    // Live workout metrics (streamed during active recording)
    @Published var trackerHeartRateBpm: Int? = nil
    @Published var trackerHeartRateSource: String? = nil // e.g. "Apple Watch"

    // User-defined climbing goals (target peaks). Persisted in UserDefaults.
    @Published var goals: [Goal] = GoalStore.load() {
        didSet { GoalStore.save(goals) }
    }


    // User profile state lives in ProfileViewModel (R3).

    // Fortschritt
    @Published var currentXP: Int = 0
    @Published var currentLevel: Int = 1
    
    // Ascend Progress
    @Published var ascendProfile: AscendProfile? = nil
    
    // Readiness & Health
    @Published var readiness: ReadinessBreakdown? = nil
    @Published var healthProfile: HealthKitProfile? = nil

    
    // Feed state (recentTours, bookmarkedTours) lives in FeedViewModel (R3 step 3).

    // Leaderboard state (friendsLeaderboard, globalLeaderboard, localLeaderboard)
    // lives in LeaderboardViewModel (R3 step 4).

    // Discovery
    @Published var recommendedPeaks: [Mountain] = []
    @Published var heroBannerItems: [HeroBannerItem] = []
    @Published var suggestedRoutes: [Mountain] = []

    // Collections (shared across all pages)
    @Published var myCollections: [TourCollection] = []

    // FAB Visibility (driven by scroll direction in child views)
    @Published var isFABVisible: Bool = true
    
    // Explicit navigation triggers
    @Published var exploreSelectedMountain: Mountain? = nil
    @Published var exploreSearchQuery: String? = nil

    // Requested tab switch from a child view. ContentView observes this and
    // flips `selectedTab`; nil'd back out after the switch is applied.
    @Published var pendingTab: Int? = nil

    // Time-to-Go — answers to the contextual questionnaire, keyed by question id.
    // Multi-select answers are stored as arrays of strings, boolean/scalar answers
    // as a one-element array ("true" / "3" / etc.) so the storage stays uniform.
    @Published var timeToGoAnswers: [String: [String]] = [:] {
        didSet { saveTimeToGoAnswers() }
    }
    @Published var timeToGoAnsweredAt: Date? = nil

    // Extended Summit Readiness — subjective answers beyond the 5 mandatory sliders.
    @Published var extendedReadinessAnswers: [String: [String]] = [:] {
        didSet { saveExtendedReadiness() }
    }
    @Published var extendedReadinessAnsweredAt: Date? = nil

    // Weekly go-score log: one entry per ISO weekday (1 = Monday … 7 = Sunday).
    // Each value is a 0–100 score used by the 5-stage tracker pill.
    @Published var weeklyGoScores: [Int: Int] = [:] {
        didSet { saveWeeklyGoScores() }
    }

    // Historical readiness log keyed by "yyyy-MM-dd" → score 0–100.
    // Retained for 90 days; used by the Summit Readiness calendar view.
    @Published var readinessHistory: [String: Int] = [:] {
        didSet { saveReadinessHistory() }
    }

    private func saveTimeToGoAnswers() {
        if let data = try? JSONEncoder().encode(timeToGoAnswers) {
            UserDefaults.standard.set(data, forKey: "timeToGoAnswers")
        }
        if let at = timeToGoAnsweredAt {
            UserDefaults.standard.set(at, forKey: "timeToGoAnsweredAt")
        }
    }
    private func saveExtendedReadiness() {
        if let data = try? JSONEncoder().encode(extendedReadinessAnswers) {
            UserDefaults.standard.set(data, forKey: "extendedReadinessAnswers")
        }
        if let at = extendedReadinessAnsweredAt {
            UserDefaults.standard.set(at, forKey: "extendedReadinessAnsweredAt")
        }
    }
    private func saveWeeklyGoScores() {
        let strKeyed = Dictionary(uniqueKeysWithValues: weeklyGoScores.map { (String($0.key), $0.value) })
        if let data = try? JSONEncoder().encode(strKeyed) {
            UserDefaults.standard.set(data, forKey: "weeklyGoScores")
        }
    }
    private func saveReadinessHistory() {
        if let data = try? JSONEncoder().encode(readinessHistory) {
            UserDefaults.standard.set(data, forKey: "readinessHistory")
        }
    }

    /// Records today's score in the persistent readiness history and trims entries older than 90 days.
    func recordReadinessScore(_ score: Int) {
        let key = isoDateKey(Date())
        readinessHistory[key] = score
        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        readinessHistory = readinessHistory.filter {
            guard let d = fmt.date(from: $0.key) else { return false }
            return d >= cutoff
        }
    }

    private func isoDateKey(_ date: Date) -> String {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: date)
    }

    func loadContextualPersistence() {
        if let data = UserDefaults.standard.data(forKey: "timeToGoAnswers"),
           let decoded = try? JSONDecoder().decode([String: [String]].self, from: data) {
            timeToGoAnswers = decoded
        }
        timeToGoAnsweredAt = UserDefaults.standard.object(forKey: "timeToGoAnsweredAt") as? Date
        if let data = UserDefaults.standard.data(forKey: "extendedReadinessAnswers"),
           let decoded = try? JSONDecoder().decode([String: [String]].self, from: data) {
            extendedReadinessAnswers = decoded
        }
        extendedReadinessAnsweredAt = UserDefaults.standard.object(forKey: "extendedReadinessAnsweredAt") as? Date
        if let data = UserDefaults.standard.data(forKey: "weeklyGoScores"),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
            weeklyGoScores = Dictionary(uniqueKeysWithValues: decoded.compactMap {
                guard let k = Int($0.key) else { return nil }
                return (k, $0.value)
            })
        }
        if let data = UserDefaults.standard.data(forKey: "readinessHistory"),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
            readinessHistory = decoded
        }
    }

    /// Time-to-Go composite score (0–100). Combines readiness, recent workload
    /// and the subjective answers from `timeToGoAnswers`. Conservative by design:
    /// missing data pulls the score down rather than up.
    var timeToGoScore: Int {
        let readinessPart = Double(readiness?.totalScore ?? 50)
        // Subjective component: every answered question contributes +3, capped at 30.
        let answered = timeToGoAnswers.values.filter { !$0.isEmpty && $0 != [""] }.count
        let subjectiveBonus = min(Double(answered) * 3.0, 30.0)
        // Mandatory questions penalty: if fewer than 6 mandatory answers, scale down.
        let mandatoryAnswered = ["sleep", "nutrition", "weather", "gear", "partners", "motivation"]
            .filter { !(timeToGoAnswers[$0]?.isEmpty ?? true) }
            .count
        let mandatoryFactor = Double(mandatoryAnswered) / 6.0
        let raw = (readinessPart * 0.55 + subjectiveBonus * 1.5) * max(0.4, mandatoryFactor)
        return min(100, max(0, Int(raw)))
    }

    /// Map a 0–100 score onto 5 stages for the Time-to-Go tracker pills.
    /// Stages: 0 = deep-red (do not go), 4 = deep-green (prime).
    func goStage(for score: Int) -> Int {
        switch score {
        case ..<25: return 0
        case ..<45: return 1
        case ..<65: return 2
        case ..<82: return 3
        default:    return 4
        }
    }

    // Feed pagination state (isLoadingMoreFeed, hasMoreFeed, feedPage,
    // feedPageSize, feedMaxItems) lives in FeedViewModel (R3 step 3).

    var currentLevelProgressXP: Int { currentXP % 1000 }
    var xpNeededForNextLevel: Int { 1000 }

    // Weekly objectives helpers
    var weeklyTours: [Tour] {
        guard let weekInterval = Calendar.current.dateInterval(of: .weekOfYear, for: Date()) else { return [] }
        // Safe nil fallback: during app start the feedVM weak ref may not be
        // set yet — empty result is fine, the view will recompute when
        // feedVM publishes its first page.
        return (feedVM?.recentTours ?? []).filter { $0.isCurrentUser && weekInterval.contains($0.date) }
    }
    var weeklyElevation: Int { weeklyTours.reduce(0) { $0 + $1.elevationGainMeters } }
    var weeklyTourCount: Int { weeklyTours.count }
    
    // Automatische Berechnung des Rangs anhand des aktuellen Levels!
    func syncAscendTierWithCurrentLevel() {
        guard ascendProfile != nil else { return }
        
        // Finde den Rang, in dessen Level-Range wir uns befinden
        let roadmapTiers = AscendRoadmapData.shared.tiers
        if let matchedTier = roadmapTiers.first(where: { currentLevel >= $0.startLvl && currentLevel <= $0.endLvl }) {
            let parts = matchedTier.name.split(separator: " ")
            let baseTier = String(parts[0]) // z.B. "Bronze"
            
            var subtier = 1
            if parts.count > 1 {
                let numeral = String(parts[1])
                if numeral == "II" { subtier = 2 }
                else if numeral == "III" { subtier = 3 }
            }
            // Obsidian hat keine Subtier-Angabe im Namen, bleibt bei 1
            
            ascendProfile?.ascend_tier = baseTier
            ascendProfile?.ascend_subtier = subtier
            ascendProfile?.ascend_level = self.currentLevel
            ascendProfile?.ascend_xp = Double(self.currentXP) // XP fix!
        }
    }
    
    // --- INIT CHAIN ---

    // Kicks off the post-profile init chain after AscentApp resolves the
    // profile via ProfileViewModel.fetchProfile(). Profile fetch and its
    // write-path live in ProfileViewModel (R3).
    func fetchInitialDataChain() {
        leaderboardVM?.fetchLeaderboard()
        feedVM?.fetchFeed()
        fetchAscendProfile()
        fetchCollections()
        feedVM?.fetchBookmarkedTours()
    }

    // Internal XP/Level push back to the profile row. Used after
    // addCompletedTour / deleteTour where currentXP and currentLevel
    // change. Will move to ProgressViewModel in R5.
    private func uploadProfileToCloud(refreshLeaderboard: Bool = false) {
        guard let vm = profileVM else { return }
        Task {
            do {
                let session = try await supabase.auth.session
                let updated = CloudProfile(
                    id: session.user.id,
                    username: vm.userName,
                    handle: vm.userHandle,
                    xp: self.currentXP,
                    level: self.currentLevel,
                    avatar_url: vm.avatarURL,
                    region: vm.userRegion,
                    insta_handle: vm.instaHandle,
                    disciplines: vm.selectedSports,
                    specialties: vm.mountaineeringSpecialties,
                    hobbies: vm.otherHobbies
                )
                try await ProfileService.shared.upsertProfile(updated)
                if refreshLeaderboard { leaderboardVM?.fetchLeaderboard() }
            } catch { print("❌ uploadProfileToCloud error: \(error)") }
        }
    }
    
    // Lädt das Ascend Profil (Level, Tier, XP)
    func fetchAscendProfile() {
        Task {
            do {
                let session = try await supabase.auth.session
                let userId = session.user.id
                
                let result: AscendProfile = try await supabase
                    .from("ascend_profiles")
                    .select()
                    .eq("user_id", value: userId)
                    .single()
                    .execute()
                    .value
                
                self.ascendProfile = result
                self.applyInactivityReset()
                self.syncAscendTierWithCurrentLevel() // <- Hier wird der korrekte dynamische Rang ermittelt!
                
            } catch {
                print("⚠️ Fetch Ascend Profile: \(error)")
                // Create dummy or insert if not exists
                self.ascendProfile = AscendProfile(
                    user_id: UUID(),
                    ascend_xp: 0,
                    ascend_level: 1,
                    ascend_tier: "Bronze",
                    ascend_subtier: 1,
                    streak_days: 0,
                    last_activity_date: nil,
                    prestige_mountains_completed: 0
                )
                self.syncAscendTierWithCurrentLevel() // <- Selbst beim leeren Start der richtige Rang
            }
        }
    }
    
    /// Resets streak and clears weekly scores if the user has been inactive for more than 7 days.
    /// Also clears the weekly go-score grid so stale pills don't mislead.
    private func applyInactivityReset() {
        guard let profile = ascendProfile,
              let lastActive = profile.last_activity_date else { return }
        let daysSinceActive = Calendar.current.dateComponents([.day], from: lastActive, to: Date()).day ?? 0
        guard daysSinceActive > 7 else { return }

        // Reset streak locally; the next tour logged will rebuild it via Supabase
        ascendProfile?.streak_days = 0
        // Clear the current-week pill grid so the user sees blank history, not stale data
        weeklyGoScores = [:]
        // Clear readiness assessment so they start fresh after a long break
        extendedReadinessAnswers = [:]
        extendedReadinessAnsweredAt = nil
        readiness = nil
        UserDefaults.standard.removeObject(forKey: "extendedReadinessAnswers")
        UserDefaults.standard.removeObject(forKey: "extendedReadinessAnsweredAt")
    }

    // --- READINESS FUNKTIONEN ---

    func refreshReadiness() {
        Task {
            // Resolve target mountain (Supabase lookup) from coaching plan, if any.
            // Stays here until R3 moves this into ReadinessViewModel / MountainService.
            var targetMt: Mountain? = nil
            if let goalData = UserDefaults.standard.data(forKey: "coaching_plan_data"),
               let plan = try? JSONDecoder().decode(CoachingPlan.self, from: goalData) {
                let results: [Mountain]? = try? await supabase
                    .from("mountains")
                    .select("id,name,elevation,difficulty,region,country,image_url,latitude,longitude,isPrestigePeak")
                    .ilike("name", value: "%\(plan.goalName)%")
                    .limit(1)
                    .execute()
                    .value
                targetMt = results?.first
            }

            // Fetch current weather for the resolved target, if coordinates available.
            var weather: MountainWeather? = nil
            if let targetMt, let lat = targetMt.latitude, let lon = targetMt.longitude {
                await WeatherManager.shared.fetchWeather(latitude: lat, longitude: lon)
                weather = WeatherManager.shared.currentWeather
            }

            // Delegate to HealthCoordinator: it fetches the HealthKit profile,
            // runs ReadinessManager.calculate, and writes back into
            // self.healthProfile / self.readiness (mirror until R3).
            await HealthCoordinator.shared.refreshReadiness(
                tours: feedVM?.recentTours ?? [],
                targetMountain: targetMt,
                targetWeather: weather
            )
        }
    }
    
    // Feed fetch / pagination / bookmarks live in FeedViewModel (R3 step 3).

    func addCompletedTour(summit: String, comment: String, elevation: Int, duration: TimeInterval, distance: Double, xp: Int, pauses: [PauseEntry] = [], photoData: Data? = nil, rawRoute: [CLLocation] = []) {
        self.currentXP += xp
        self.currentLevel = (self.currentXP / 1000) + 1
        self.syncAscendTierWithCurrentLevel() // Update Rank if user leveled up

        uploadProfileToCloud(refreshLeaderboard: true)  // Tour completed = XP changed = leaderboard needs refresh
        fetchCollections() // Refresh collections in case mountain was added to one
        
        // Optional: Update ascend_profiles DB if we want it permanently saved.
        // We'll trust the sync on fetch, but pushing the new level is clean.
        if let profile = self.ascendProfile {
            Task {
                try? await supabase.from("ascend_profiles").upsert(profile).execute()
            }
        }

        Task {
            let myId: UUID
            do {
                myId = try await supabase.auth.session.user.id
            } catch {
                print("❌ Fehler beim Auth: \(error)")
                return
            }

            var pausesJSON: String? = nil
            if !pauses.isEmpty {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                if let data = try? encoder.encode(pauses) {
                    pausesJSON = String(data: data, encoding: .utf8)
                }
            }

            // Resize photo on background thread to avoid UI freeze
            var compressedPhoto: Data? = nil
            if let photoData {
                compressedPhoto = await Task.detached(priority: .userInitiated) {
                    guard let uiImage = UIImage(data: photoData) else { return nil as Data? }
                    let maxDim: CGFloat = 800
                    let scale = min(maxDim / max(uiImage.size.width, uiImage.size.height), 1.0)
                    let newSize = CGSize(width: uiImage.size.width * scale, height: uiImage.size.height * scale)
                    let renderer = UIGraphicsImageRenderer(size: newSize)
                    let resized = renderer.image { _ in uiImage.draw(in: CGRect(origin: .zero, size: newSize)) }
                    return resized.jpegData(compressionQuality: 0.6)
                }.value
                if let compressed = compressedPhoto {
                    print("📸 Photo prepared (\(compressed.count / 1024)KB)")
                }
            }

            // Upload photo first (retry), then insert tour with photo_url
            var photoURL: String? = nil
            if let compressed = compressedPhoto {
                let photoPath = "\(myId)/\(UUID().uuidString).jpg"
                for attempt in 1...3 {
                    do {
                        try await supabase.storage.from("tour-photos").upload(photoPath, data: compressed, options: FileOptions(contentType: "image/jpeg"))
                        let publicURL = try supabase.storage.from("tour-photos").getPublicURL(path: photoPath)
                        photoURL = publicURL.absoluteString
                        print("📸 Photo uploaded (attempt \(attempt))")
                        break
                    } catch {
                        print("⚠️ Photo upload attempt \(attempt) failed: \(error.localizedDescription)")
                        if attempt < 3 {
                            try? await Task.sleep(nanoseconds: UInt64(attempt) * 2_000_000_000)
                        }
                    }
                }
            }

            // Encode route polyline for storage
            let routePolyline = RouteEncoder.encode(rawRoute)

            // Insert tour (with photo_url if upload succeeded) — retry up to 3 times
            let newCloudTour = CloudTour(
                id: nil,
                user_id: myId,
                name: summit,
                elevation: elevation,
                date: Date(),
                difficulty: "Medium",
                notes: comment,
                duration_seconds: Int(duration),
                distance_km: distance,
                pauses: pausesJSON,
                photo_url: photoURL,
                route_polyline: routePolyline
            )

            for attempt in 1...3 {
                do {
                    try await supabase.from("tours").insert(newCloudTour).execute()
                    print("✅ Tour erfolgreich hochgeladen: \(summit) (attempt \(attempt))")
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    feedVM?.fetchFeed(forceRefresh: true)
                    return
                } catch {
                    print("⚠️ Tour insert attempt \(attempt) failed: \(error.localizedDescription)")
                    if attempt < 3 {
                        try? await Task.sleep(nanoseconds: UInt64(attempt) * 2_000_000_000)
                    } else {
                        print("❌ Tour konnte nach 3 Versuchen nicht gespeichert werden")
                    }
                }
            }
        }
    }

    // Löscht eine Tour
    func deleteTour(tour: Tour) {
        self.currentXP = max(0, self.currentXP - tour.xpGained)
        self.currentLevel = max(1, (self.currentXP / 1000) + 1)
        feedVM?.removeTour(id: tour.id)
        uploadProfileToCloud(refreshLeaderboard: true)

        Task {
            do {
                if let cloudId = tour.cloudId {
                    try await supabase.from("tours").delete().eq("id", value: cloudId).execute()
                } else {
                    let myId = try await supabase.auth.session.user.id
                    try await supabase.from("tours").delete().eq("user_id", value: myId).eq("name", value: tour.summitName).execute()
                }
            } catch { print("❌ Fehler beim Löschen der Tour: \(error)") }
        }
    }

    // Social interactions (toggleFistBump / postComment / fetchComments /
    // toggleBookmark) live in FeedViewModel (R3 step 3).

    // Leaderboard fetch + addFriend live in LeaderboardViewModel (R3 step 4).

    // --- DISCOVERY ---

    func fetchRecommendedPeaks() {
        guard recommendedPeaks.isEmpty else { return }

        Task {
            do {
                // 1. Lade Berge mit Bildern. Da url oft image_url heißt, laden wir etwas mehr und filtern lokal.
                let rawPeaks: [Mountain] = try await supabase
                    .from("mountains")
                    .select("*, routes:mountain_routes(*)")
                    .not("image_url", operator: .is, value: "null")
                    .neq("image_url", value: "")
                    .limit(200)
                    .execute()
                    .value
                    
                let allPeaks = rawPeaks.filter { ($0.effectiveImageUrl ?? "").count > 5 }

                // 2. Sortiere und wähle zufällige Berge für die Anzeige LOKAL aus
                let displayPeaks = Array(allPeaks.shuffled().prefix(10))
                let routeSuggestions = Array(allPeaks.shuffled().prefix(8))

                // 3. Baue die Elemente für das Hero Banner zusammen
                var bannerItems: [HeroBannerItem] = []
                for peak in allPeaks.filter({ $0.isPrestigePeak }).shuffled().prefix(3) {
                    bannerItems.append(HeroBannerItem(
                        title: peak.name,
                        subtitle: "\(peak.elevation)m · \(peak.region)",
                        imageURL: (peak.effectiveImageUrl?.isEmpty == false) ? peak.effectiveImageUrl : nil,
                        badge: "PRESTIGE PEAK",
                        mountain: peak
                    ))
                }
                for peak in allPeaks.filter({ !$0.isPrestigePeak }).shuffled().prefix(3) {
                    bannerItems.append(HeroBannerItem(
                        title: peak.name,
                        subtitle: "\(peak.elevation)m · \(peak.region)",
                        imageURL: (peak.effectiveImageUrl?.isEmpty == false) ? peak.effectiveImageUrl : nil,
                        badge: "RECOMMENDED",
                        mountain: peak
                    ))
                }
                let finalBanner = Array(bannerItems.shuffled().prefix(5))

                // 4. Update der UI auf dem Main-Thread
                self.recommendedPeaks = displayPeaks
                self.suggestedRoutes = routeSuggestions
                self.heroBannerItems = finalBanner
                print("✅ Erfolgreich \(allPeaks.count) Berge von Supabase geladen!")
            } catch {
                // 5. Falls es weiterhin fehlschlägt, loggen wir den exakten Grund in die Konsole
                print("❌ Fehler beim Laden der Peaks von Supabase: \(error)")
                print("💡 Tipp: Wenn dies passiert, weichen die Spalten in Supabase wahrscheinlich vom 'Mountain' Modell ab (z.B. imageUrl vs image_url oder falscher Datentyp).")
            }
        }
    }

    // --- COLLECTIONS ---

    func fetchCollections() {
        Task {
            do {
                let userId = try await supabase.auth.session.user.id
                let results: [TourCollection] = try await supabase
                    .from("collections")
                    .select()
                    .eq("user_id", value: userId)
                    .order("updated_at", ascending: false)
                    .execute()
                    .value
                self.myCollections = results
            } catch {
                print("⚠️ Fetch collections: \(error)")
            }
        }
    }
}
