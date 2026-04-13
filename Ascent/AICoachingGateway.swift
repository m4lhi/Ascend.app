import SwiftUI
import Combine
import Supabase

// =========================================
// === DATEI: AICoachingGateway.swift ===
// === AI Mountaineering Coach — v2 ===
// =========================================
//
// Onboarding (wheel pickers) → Animated themed Map (phases, particles)
// Triggered from the sparkles FAB in ContentView.

// MARK: - Models

enum ExperienceLevel: String, CaseIterable, Codable {
    case none = "Never climbed"
    case hiker = "Regular hiker"
    case alpineCourse = "Alpine course"
    case glacierExp = "Glacier experience"
}

enum EnduranceLevel: String, CaseIterable, Codable {
    case beginner = "Beginner"
    case moderate = "Moderate"
    case strong = "Strong"
    case athlete = "Athlete"
}

enum StationKind: String, Codable {
    case hike, technique, strength, endurance, acclimatization, glacier, summit
}

enum PlanPhase: String, CaseIterable, Codable {
    case foundation = "Foundation"
    case build = "Build"
    case prep = "Peak Prep"
    case summit = "Summit Push"
}

struct CoachStation: Identifiable, Codable {
    let id: UUID
    let title: String
    let subtitle: String
    let reasoning: String        // personalized "why" string
    let kind: StationKind
    let phase: PlanPhase
    let elevationGain: Int
    var mountainId: UUID? = nil
    var isCompleted: Bool
    var isUnlocked: Bool
    var isRealTour: Bool         // tour tracked in Health/feed (gold marker)
}

struct CoachingPlan: Codable {
    var goalName: String
    var goalElevation: Int
    var region: MountainRegion
    var safeTimelineMonths: Int
    var userRequestedMonths: Int
    var wasTimelineAdjusted: Bool
    var stations: [CoachStation]
    var gearRecommendations: [String]
    var headline: String         // 1-sentence personalized intro
}

struct OnboardingData: Codable {
    var heightCm: Int = 175
    var weightKg: Int = 72
    var age: Int = 28
    var location: String = ""
    var endurance: EnduranceLevel = .moderate
    var vo2max: Int = 0
    var weeklyActiveHours: Int = 4
    var experience: [ExperienceLevel] = [.hiker]
    var hasGlacierExperience: Bool = false
    var typicalElevationGain: Int = 500
    var goalName: String = ""
    var desiredMonths: Int = 6
    var sessionsPerWeek: Int = 3
    var minutesPerSession: Int = 60
    var acceptedSafetyCommitment: Bool = false
    var pastCompletedGoals: [String] = []

    // Convenience to check experience as before
    func hasExperience(_ level: ExperienceLevel) -> Bool {
        experience.contains(level)
    }
}

// MARK: - ViewModel

@MainActor
final class CoachingViewModel: ObservableObject {
    @Published var step: Int = 0
    @Published var data = OnboardingData()
    @Published var plan: CoachingPlan? = nil
    @Published var isPrefilling = false
    @Published var selectedTrainingTab: TrainingTab = .hikes

    init() {
        _ = loadFromDefaults()
    }

    enum TrainingTab: String, CaseIterable {
        case hikes = "Hikes"
        case gym = "Gym"
        case chat = "AI Coach"

        var icon: String {
            switch self {
            case .hikes: return "figure.hiking"
            case .gym: return "dumbbell.fill"
            case .chat: return "sparkles"
            }
        }
    }

    let totalSteps = 6
    private static let workoutKey = "coaching_workout_plan"

    private static let onboardingDataKey = "coaching_onboarding_data"
    private static let planKey = "coaching_plan_data"
    static let onboardingCompleteKey = "coachingOnboardingComplete"

    // MARK: Persistence

    func saveToDefaults() {
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: Self.onboardingDataKey)
        }
        if let plan, let encoded = try? JSONEncoder().encode(plan) {
            UserDefaults.standard.set(encoded, forKey: Self.planKey)
        }
        UserDefaults.standard.set(true, forKey: Self.onboardingCompleteKey)
    }

    func loadFromDefaults() -> Bool {
        guard UserDefaults.standard.bool(forKey: Self.onboardingCompleteKey),
              let planData = UserDefaults.standard.data(forKey: Self.planKey),
              let savedPlan = try? JSONDecoder().decode(CoachingPlan.self, from: planData)
        else { return false }

        if let onbData = UserDefaults.standard.data(forKey: Self.onboardingDataKey),
           let savedOnb = try? JSONDecoder().decode(OnboardingData.self, from: onbData) {
            self.data = savedOnb
        }
        self.plan = savedPlan
        self.step = totalSteps // skip to map
        return true
    }

    static func clearSavedData() {
        UserDefaults.standard.removeObject(forKey: onboardingDataKey)
        UserDefaults.standard.removeObject(forKey: planKey)
        UserDefaults.standard.set(false, forKey: onboardingCompleteKey)
    }

    static func loadOnboardingData() -> OnboardingData? {
        guard let data = UserDefaults.standard.data(forKey: onboardingDataKey),
              let decoded = try? JSONDecoder().decode(OnboardingData.self, from: data)
        else { return nil }
        return decoded
    }

    static func saveOnboardingData(_ data: OnboardingData) {
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: onboardingDataKey)
        }
    }

    // MARK: HealthKit prefill
    func prefillFromHealthKit() async {
        isPrefilling = true
        let profile = await HealthKitBridge.shared.fetchProfile()
        if let h = profile.heightCm, h > 100 { data.heightCm = h }
        if let w = profile.weightKg, w > 30 { data.weightKg = w }
        if let v = profile.vo2max, v > 10 { data.vo2max = v }
        if let a = profile.weeklyActiveHours { data.weeklyActiveHours = a }
        isPrefilling = false
    }

    // MARK: Real-tour matching
    // Marks stations as completed (and isRealTour=true) when a real tracked tour
    // from appState.recentTours matches the station's elevation-gain threshold.
    func applyRealTourMatching(_ tours: [Tour]) {
        guard var p = plan else { return }
        let myTours = tours.filter { $0.isCurrentUser }
        var usedTourIds = Set<UUID>()
        var changesMade = false
        
        for i in p.stations.indices {
            guard !p.stations[i].isCompleted else { continue }
            let threshold = p.stations[i].elevationGain
            guard threshold > 0 else { continue }
            // Find a not-yet-used tour that meets the elevation threshold.
            if let match = myTours.first(where: {
                !usedTourIds.contains($0.id) && $0.elevationGainMeters >= threshold
            }) {
                p.stations[i].isCompleted = true
                p.stations[i].isRealTour = true
                if i + 1 < p.stations.count {
                    p.stations[i + 1].isUnlocked = true
                }
                usedTourIds.insert(match.id)
                changesMade = true
            }
        }
        
        if changesMade {
            withAnimation(CT.Springs.soft) { plan = p }
            saveToDefaults()
        }
    }

    func next() {
        HapticManager.shared.light()
        if step < totalSteps - 1 {
            withAnimation(CT.Springs.soft) { step += 1 }
        } else {
            Task {
                await generatePlan()
                saveToDefaults()
                withAnimation(CT.Springs.soft) { step = totalSteps }
            }
        }
    }

    func back() {
        HapticManager.shared.light()
        withAnimation(CT.Springs.soft) {
            if step > 0 { step -= 1 }
        }
    }

    // MARK: Plan generation (personalized)

    func generatePlan() async {
        let goal = data.goalName.isEmpty ? "Mont Blanc" : data.goalName
        let requested = max(1, data.desiredMonths)
        let baseMonths = Self.baseMonths(for: goal)

        // Experience adjustment
        var expBonus = 0
        if data.hasGlacierExperience { expBonus -= 3 }
        if data.hasExperience(.alpineCourse) { expBonus -= 1 }
        if data.hasExperience(.none) { expBonus += 3 }

        // Fitness adjustment
        var fitBonus = 0
        switch data.endurance {
        case .beginner: fitBonus += 2
        case .moderate: fitBonus += 0
        case .strong:   fitBonus -= 1
        case .athlete:  fitBonus -= 2
        }
        if data.age > 55 { fitBonus += 1 }
        if data.vo2max > 0 && data.vo2max < 35 { fitBonus += 1 }

        // Training capacity adjustment
        let weeklyLoad = data.sessionsPerWeek * data.minutesPerSession
        if weeklyLoad < 180 { fitBonus += 1 }

        let safeMonths = max(baseMonths + expBonus + fitBonus, max(requested, 3))
        let adjusted = safeMonths > requested

        let region = MountainRegion.infer(from: data.location)
        
        var availableMts: [Mountain] = []
        if let mts = try? await supabase.from("mountains")
            .select("*, routes:mountain_routes(*)")
            .limit(200) // basic sampling to map fallbacks
            .execute().value as? [Mountain] {
            availableMts = mts
        }

        let stations = Self.buildStations(for: goal, region: region, months: safeMonths, data: data, localMts: availableMts)
        let gear = Self.buildGear(goal: goal, region: region)
        let headline = Self.headline(goal: goal, months: safeMonths, data: data)

        self.plan = CoachingPlan(
            goalName: goal,
            goalElevation: Self.goalElevation(for: goal),
            region: region,
            safeTimelineMonths: safeMonths,
            userRequestedMonths: requested,
            wasTimelineAdjusted: adjusted,
            stations: stations,
            gearRecommendations: gear,
            headline: headline
        )
    }

    static func baseMonths(for goal: String) -> Int {
        let g = goal.lowercased()
        if g.contains("everest") { return 36 }
        if g.contains("denali") { return 24 }
        if g.contains("matterhorn") { return 18 }
        if g.contains("mont blanc") { return 9 }
        if g.contains("kilimanj") { return 6 }
        if g.contains("gran paradiso") { return 6 }
        return 8
    }

    static func goalElevation(for goal: String) -> Int {
        let g = goal.lowercased()
        if g.contains("everest") { return 8848 }
        if g.contains("denali") { return 6190 }
        if g.contains("matterhorn") { return 4478 }
        if g.contains("mont blanc") { return 4809 }
        if g.contains("kilimanj") { return 5895 }
        if g.contains("gran paradiso") { return 4061 }
        return 4000
    }

    static func headline(goal: String, months: Int, data: OnboardingData) -> String {
        let base: String
        switch data.endurance {
        case .beginner: base = "We're starting gentle — building a solid aerobic base before adding vertical."
        case .moderate: base = "You've got a working base. We'll push volume steadily toward \(goal)."
        case .strong:   base = "Strong engine already — we'll focus on technique and altitude tolerance."
        case .athlete:  base = "Athlete-level endurance. Expect a dense, specific program toward \(goal)."
        }
        return "\(months)-month path · \(base)"
    }

    // MARK: - Mountain-adaptive hike progression

    struct HikePeak {
        let name: String
        let elevation: Int
        let subtitle: String
        var mountainId: UUID? = nil
    }

    static func hikeProgression(for goal: String, localMts: [Mountain]) -> [HikePeak] {
        let g = goal.lowercased()
        if g.contains("mont blanc") {
            return [
                HikePeak(name: "Pointe de la Réunion", elevation: 2800, subtitle: "2,800 m · Easy alpine intro"),
                HikePeak(name: "Aiguille du Tour", elevation: 3542, subtitle: "3,542 m · First glacier contact"),
                HikePeak(name: "Gran Paradiso", elevation: 4061, subtitle: "4,061 m · Full 4,000er dress rehearsal"),
            ]
        }
        if g.contains("matterhorn") {
            return [
                HikePeak(name: "Breithorn", elevation: 4164, subtitle: "4,164 m · Easiest 4,000er"),
                HikePeak(name: "Allalinhorn", elevation: 4027, subtitle: "4,027 m · Glacier & ridge practice"),
                HikePeak(name: "Dufourspitze", elevation: 4634, subtitle: "4,634 m · Technical altitude test"),
            ]
        }
        if g.contains("kilimanj") {
            return [
                HikePeak(name: "Mt. Longonot", elevation: 2776, subtitle: "2,776 m · Easy volcano hike"),
                HikePeak(name: "Mt. Kenya (Point Lenana)", elevation: 4985, subtitle: "4,985 m · Altitude acclimatization"),
                HikePeak(name: "Mt. Meru", elevation: 4566, subtitle: "4,566 m · Full dress rehearsal"),
            ]
        }
        if g.contains("denali") {
            return [
                HikePeak(name: "Mt. Baker", elevation: 3286, subtitle: "3,286 m · Glacier skills"),
                HikePeak(name: "Mt. Rainier", elevation: 4392, subtitle: "4,392 m · Multi-day alpine push"),
                HikePeak(name: "Aconcagua", elevation: 6961, subtitle: "6,961 m · Extreme altitude prep"),
            ]
        }
        if g.contains("everest") {
            return [
                HikePeak(name: "Island Peak", elevation: 6189, subtitle: "6,189 m · Technical intro"),
                HikePeak(name: "Ama Dablam", elevation: 6812, subtitle: "6,812 m · Technical high-altitude"),
                HikePeak(name: "Cho Oyu", elevation: 8188, subtitle: "8,188 m · 8,000er experience"),
            ]
        }
        if g.contains("gran paradiso") {
            return [
                HikePeak(name: "Punta Gnifetti", elevation: 4554, subtitle: "4,554 m · Margherita Hut approach"),
                HikePeak(name: "Aiguille du Tour", elevation: 3542, subtitle: "3,542 m · Glacier practice"),
            ]
        }
        // Generic fallback by elevation
        let elev = goalElevation(for: goal)
        let sortedLocal = localMts.sorted { $0.elevation < $1.elevation }
        
        func matchPeak(_ targetElev: Int, fallbackName: String) -> HikePeak {
            if let best = sortedLocal.min(by: { abs($0.elevation - targetElev) < abs($1.elevation - targetElev) }),
               abs(best.elevation - targetElev) < 1500 {
                return HikePeak(name: best.name, elevation: best.elevation, subtitle: "\(best.elevation) m · Found in \(best.region)", mountainId: best.id)
            }
            return HikePeak(name: fallbackName, elevation: targetElev, subtitle: "\(targetElev) m · Foundation hike", mountainId: nil)
        }

        if elev > 5500 {
            return [
                matchPeak(Int(Double(elev) * 0.35), fallbackName: "Regional Peak (easy)"),
                matchPeak(Int(Double(elev) * 0.55), fallbackName: "Regional Peak (moderate)"),
                matchPeak(Int(Double(elev) * 0.8), fallbackName: "Regional Peak (hard)")
            ]
        }
        return [
            matchPeak(max(400, elev / 4), fallbackName: "Local Trail"),
            matchPeak(max(800, elev / 2), fallbackName: "Regional Peak")
        ]
    }

    static func buildStations(for goal: String, region: MountainRegion, months: Int, data: OnboardingData, localMts: [Mountain]) -> [CoachStation] {
        var result: [CoachStation] = []
        let needsGlacier = goalElevation(for: goal) > 4000
        let highAltitude = goalElevation(for: goal) > 5500
        let progression = hikeProgression(for: goal, localMts: localMts)
        let isVet = !data.pastCompletedGoals.isEmpty

        func reason(_ tmpl: String) -> String { tmpl }

        // Foundation phase — GYM + first prep hike ----------------------------
        if let firstHike = progression.first {
            result.append(CoachStation(
                id: UUID(),
                title: firstHike.name,
                subtitle: firstHike.subtitle,
                reasoning: reason(isVet ? "Time to rebuild the aerobic base. Use this familiar terrain to find your pacing again." : "Your first benchmark peak. Sets your movement baseline and natural pace before loading volume."),
                kind: .hike, phase: .foundation, elevationGain: firstHike.elevation,
                isCompleted: false, isUnlocked: true, isRealTour: false
            ))
        } else {
            result.append(CoachStation(
                id: UUID(),
                title: "Foundation Hike",
                subtitle: "400 m gain · easy terrain",
                reasoning: reason(isVet ? "A light re-entry to the mountains after your last objective." : "Sets your movement baseline."),
                kind: .hike, phase: .foundation, elevationGain: 400,
                isCompleted: false, isUnlocked: true, isRealTour: false
            ))
        }
        result.append(CoachStation(
            id: UUID(),
            title: isVet ? "Weighted Load Cycles" : "Legs & Core Strength",
            subtitle: isVet ? "Heavy pack · unilateral" : "Squats · lunges · planks",
            reasoning: reason(data.age > 45
                ? "At your age, joint stability matters more than PRs. Focus on control."
                : (isVet ? "Since you've conquered \(data.pastCompletedGoals.last!), we focus heavily on load-carrying tolerance." : "Bulletproofs knees for long descents — downhill is where alpinists get injured.")),
            kind: .strength, phase: .foundation, elevationGain: 0,
            isCompleted: false, isUnlocked: false, isRealTour: false
        ))
        result.append(CoachStation(
            id: UUID(),
            title: "Zone 2 Endurance",
            subtitle: isVet ? "90 min sustained cardio" : "60 min sustained cardio",
            reasoning: reason(isVet ? "Your base from \(data.pastCompletedGoals.last!) is still there, but we need to stretch your aerobic ceiling further this time." : 
                (data.vo2max > 0 && data.vo2max < 40
                ? "Your VO₂max of \(data.vo2max) tells us Zone 2 is exactly where to spend time first."
                : "Zone 2 builds the mitochondrial base every multi-hour mountain day depends on.")),
            kind: .endurance, phase: .foundation, elevationGain: 0,
            isCompleted: false, isUnlocked: false, isRealTour: false
        ))

        // Build phase — technique + progression hike --------------------------
        result.append(CoachStation(
            id: UUID(),
            title: isVet ? "Advanced Scrambling" : "Footwork Technique",
            subtitle: isVet ? "Exposure · fast transitions" : "Edging · descent control",
            reasoning: reason(isVet ? "You know the basics. Now we train speed through exposed, complex terrain." : "Clean footwork saves enormous energy on long approaches."),
            kind: .technique, phase: .build, elevationGain: 0,
            isCompleted: false, isUnlocked: false, isRealTour: false
        ))
        if progression.count > 1 {
            let midHike = progression[1]
            result.append(CoachStation(
                id: UUID(),
                title: midHike.name,
                subtitle: midHike.subtitle,
                reasoning: reason("A harder objective that tests your developing fitness. Pace discipline is the lesson here."),
                kind: .hike, phase: .build, elevationGain: midHike.elevation,
                isCompleted: false, isUnlocked: false, isRealTour: false
            ))
        }
        if !data.hasExperience(.alpineCourse) {
            result.append(CoachStation(
                id: UUID(),
                title: "Rope Basics",
                subtitle: "Knots · belaying",
                reasoning: reason("You haven't done an alpine course — this is the minimum rope literacy you need."),
                kind: .technique, phase: .build, elevationGain: 0,
                isCompleted: false, isUnlocked: false, isRealTour: false
            ))
        }
        result.append(CoachStation(
            id: UUID(),
            title: isVet ? "Vertical & Grip Load" : "Upper Body Strength",
            subtitle: isVet ? "Pull-ups · farmer walks" : "Pull-ups · rows · carries",
            reasoning: reason(isVet ? "Since you're pushing for \(goal), we're adding intense static holds to mimic alpine terrain." : "Pack carries and ice-axe work demand more pull strength than people expect."),
            kind: .strength, phase: .build, elevationGain: 0,
            isCompleted: false, isUnlocked: false, isRealTour: false
        ))

        // Peak prep phase — acclimatization + dress rehearsal -----------------
        if needsGlacier && !data.hasGlacierExperience {
            result.append(CoachStation(
                id: UUID(),
                title: "Crampon Technique",
                subtitle: "Flat-foot · front-point",
                reasoning: reason("Crampon technique is non-negotiable for \(goal). Drill it on safe terrain first."),
                kind: .technique, phase: .prep, elevationGain: 0,
                isCompleted: false, isUnlocked: false, isRealTour: false
            ))
            result.append(CoachStation(
                id: UUID(),
                title: "Glacier Training",
                subtitle: "Crevasse rescue · ice axe",
                reasoning: reason("Roped glacier travel protects you where the mountain hides the biggest danger."),
                kind: .glacier, phase: .prep, elevationGain: 0,
                isCompleted: false, isUnlocked: false, isRealTour: false
            ))
        }
        // Prep summit hike (last before goal)
        if progression.count > 2 {
            let prepHike = progression[2]
            result.append(CoachStation(
                id: UUID(),
                title: prepHike.name,
                subtitle: prepHike.subtitle,
                reasoning: reason("Your dress-rehearsal summit — same gear, same pace, lower stakes than \(goal)."),
                kind: .summit, phase: .prep, elevationGain: prepHike.elevation,
                isCompleted: false, isUnlocked: false, isRealTour: false
            ))
        } else {
            let prepPeakName: String
            switch region {
            case .andes:      prepPeakName = "Pisco (5,752 m)"
            case .rockies:    prepPeakName = "Mt. Baker (3,286 m)"
            case .himalaya:   prepPeakName = "Island Peak (6,189 m)"
            case .eastAfrica:  prepPeakName = "Mt. Meru (4,566 m)"
            case .alps:       prepPeakName = "Gran Paradiso (4,061 m)"
            }
            result.append(CoachStation(
                id: UUID(),
                title: "Prep: \(prepPeakName)",
                subtitle: "Full gear rehearsal",
                reasoning: reason("A dress-rehearsal summit in \(region.displayName)."),
                kind: .summit, phase: .prep, elevationGain: 1800,
                isCompleted: false, isUnlocked: false, isRealTour: false
            ))
        }

        // Summit phase --------------------------------------------------------
        if highAltitude {
            result.append(CoachStation(
                id: UUID(),
                title: "Acclimatization Rotation",
                subtitle: "Climb high, sleep low",
                reasoning: reason("Above 5,500 m you must acclimatize in rotations. This station is a hard requirement."),
                kind: .acclimatization, phase: .summit, elevationGain: 2500,
                isCompleted: false, isUnlocked: false, isRealTour: false
            ))
        }
        result.append(CoachStation(
            id: UUID(),
            title: "Taper & Recovery",
            subtitle: "Mobility · sleep · fuel",
            reasoning: reason("The week before matters. Drop volume, sharpen quality, sleep more."),
            kind: .endurance, phase: .summit, elevationGain: 0,
            isCompleted: false, isUnlocked: false, isRealTour: false
        ))
        result.append(CoachStation(
            id: UUID(),
            title: "Summit: \(goal)",
            subtitle: "Your main objective",
            reasoning: reason("Everything pointed here. Turn around if conditions say so — the summit will wait."),
            kind: .summit, phase: .summit, elevationGain: goalElevation(for: goal),
            isCompleted: false, isUnlocked: false, isRealTour: false
        ))

        // Cap to months-proportional count
        let targetCount = min(max(months * 2, 10), 20)
        if result.count > targetCount {
            let summit = result.removeLast()
            result = Array(result.prefix(targetCount - 1))
            result.append(summit)
        }
        return result
    }

    static func buildGear(goal: String, region: MountainRegion) -> [String] {
        var base = ["Layered softshell", "Waterproof shell", "Trekking poles", "Headlamp", "Sun protection"]
        if goalElevation(for: goal) > 4000 {
            base += ["Crampons (12-pt)", "Ice axe", "Harness", "Helmet", "Down jacket"]
        }
        if goalElevation(for: goal) > 5500 {
            base += ["Double boots", "Expedition mittens", "Altitude watch"]
        }
        if region == .andes || region == .eastAfrica {
            base += ["High-SPF lip balm", "Buff for dust"]
        }
        return base
    }

    func completeStation(_ id: UUID) {
        guard var p = plan, let idx = p.stations.firstIndex(where: { $0.id == id }) else { return }
        p.stations[idx].isCompleted = true
        // Unlock all subsequent stations up to the next one
        if idx + 1 < p.stations.count {
            p.stations[idx + 1].isUnlocked = true
        }
        withAnimation(CT.Springs.bouncy) { plan = p }
        saveToDefaults()
        HapticManager.shared.heavy()
    }
}

// MARK: - Main Gateway View

struct AICoachingGatewayView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = CoachingViewModel()
    @AppStorage("animationProfile") private var animationProfileRaw: String = AnimationProfile.alpine.rawValue

    var body: some View {
        ZStack {
            // Background adapts once region is known
            if let region = vm.plan?.region {
                region.skyGradient.ignoresSafeArea()
                AmbientParticlesLayer(region: region).ignoresSafeArea()
            } else {
                CT.Gradients.sky.ignoresSafeArea()
            }

            VStack(spacing: 0) {
                topNav
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                ZStack {
                    switch vm.step {
                    case 0: OnboardingBasics(data: $vm.data).transition(stepTransition)
                    case 1: OnboardingFitness(data: $vm.data).transition(stepTransition)
                    case 2: OnboardingExperience(data: $vm.data).transition(stepTransition)
                    case 3: OnboardingGoal(data: $vm.data).transition(stepTransition)
                    case 4: OnboardingCapacity(data: $vm.data).transition(stepTransition)
                    case 5: OnboardingSafety(data: $vm.data).transition(stepTransition)
                    default:
                        if let plan = vm.plan {
                            CoachingMapView(plan: plan, onComplete: { vm.completeStation($0) }, selectedTab: $vm.selectedTrainingTab)
                                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                        }
                    }
                }
                .animation(CT.Springs.soft, value: vm.step)

                if vm.step < vm.totalSteps {
                    ctaButton
                        .padding(.horizontal, 20)
                        .padding(.bottom, 28)
                }
            }
        }
        .preferredColorScheme(.light)
        .task {
            if vm.plan == nil {
                await vm.prefillFromHealthKit()
            } else {
                vm.applyRealTourMatching(appState.recentTours)
            }
        }
        .onChange(of: appState.recentTours.count) { _, _ in
            vm.applyRealTourMatching(appState.recentTours)
        }
        .onChange(of: vm.plan?.stations.count ?? 0) { _, newValue in
            if newValue > 0 {
                vm.applyRealTourMatching(appState.recentTours)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenMountainInExplore"))) { notif in
            if let mountain = notif.object as? Mountain {
                dismiss() // Close entirely
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    appState.exploreSelectedMountain = mountain
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SearchMountainInExplore"))) { notif in
            if let query = notif.object as? String {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    appState.exploreSearchQuery = query
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ResetAICoach"))) { notif in
            let isCompleted = notif.object as? Bool ?? false
            withAnimation(CT.Springs.soft) {
                var newData = vm.data
                if isCompleted, let goal = vm.plan?.goalName {
                    newData.pastCompletedGoals.append(goal)
                    let elev = CoachingViewModel.goalElevation(for: goal)
                    if elev >= 4000 { newData.hasGlacierExperience = true }
                    if !newData.experience.contains(.alpineCourse) { newData.experience.append(.alpineCourse) }
                    if newData.endurance == .beginner {
                        newData.endurance = .moderate
                    } else if newData.endurance == .moderate {
                        newData.endurance = .strong
                    }
                }
                
                // Clear state, but keep user metrics for convenience
                newData.goalName = ""
                newData.acceptedSafetyCommitment = false
                
                vm.data = newData
                vm.plan = nil
                // Jump straight to goal selection if we have basic data already!
                vm.step = 3 
                vm.saveToDefaults()
                
                AIChatViewModel.shared.clearHistory()
                if isCompleted {
                    let congrats = AIChatMessage(text: "Congratulations on conquering \(newData.pastCompletedGoals.last ?? "your objective")! Your base skills have leveled up. What massive peak shall we tackle next?", isUser: false, timestamp: Date())
                    AIChatViewModel.shared.messages = [congrats]
                }
            }
        }
    }

    private var stepTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    private var topNav: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.app(size: 14, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 34, height: 34)
                    .background(CT.Colors.surfaceRaised)
                    .clipShape(Circle())
                    .ctShadow(CT.Shadows.card)
            }
            .buttonStyle(PressableButtonStyle())

            Spacer()

            if vm.step < vm.totalSteps {
                // Segmented progress
                HStack(spacing: 4) {
                    ForEach(0..<vm.totalSteps, id: \.self) { i in
                        Capsule()
                            .fill(i <= vm.step ? CT.Colors.accent : CT.Colors.accent.opacity(0.18))
                            .frame(width: i == vm.step ? 22 : 10, height: 4)
                            .animation(CT.Springs.snappy, value: vm.step)
                    }
                }
            } else {
                Text("Your Path")
                    .font(CT.Typo.label(13))
                    .foregroundColor(.primary)
            }

            Spacer()

            if vm.step > 0 && vm.step < vm.totalSteps {
                Button(action: { vm.back() }) {
                    Image(systemName: "chevron.left")
                        .font(.app(size: 14, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 34, height: 34)
                        .background(CT.Colors.surfaceRaised)
                        .clipShape(Circle())
                        .ctShadow(CT.Shadows.card)
                }
                .buttonStyle(PressableButtonStyle())
            } else {
                Color.clear.frame(width: 34, height: 34)
            }
        }
    }

    private var ctaButton: some View {
        Button(action: { vm.next() }) {
            HStack(spacing: 8) {
                Text(vm.step == vm.totalSteps - 1 ? "Generate my path" : "Continue")
                    .font(.app(size: 16, weight: .bold))
                Image(systemName: vm.step == vm.totalSteps - 1 ? "sparkles" : "arrow.right")
                    .font(.app(size: 14, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: CT.Radius.card, style: .continuous)
                    .fill(canProceed ? AnyShapeStyle(CT.Gradients.cta) : AnyShapeStyle(Color.gray.opacity(0.3)))
            )
            .ctShadow(canProceed ? CT.Shadows.glow : CT.Shadows.card)
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!canProceed)
    }

    private var canProceed: Bool {
        switch vm.step {
        case 3: return !vm.data.goalName.trimmingCharacters(in: .whitespaces).isEmpty
        case 5: return vm.data.acceptedSafetyCommitment
        default: return true
        }
    }
}

// MARK: - Wheel Picker

struct WheelPicker: View {
    let range: ClosedRange<Int>
    let unit: String
    @Binding var value: Int

    var body: some View {
        Picker("", selection: $value) {
            ForEach(Array(range), id: \.self) { v in
                Text("\(v) \(unit)")
                    .font(.app(size: 22, weight: .bold))
                    .tag(v)
            }
        }
        .pickerStyle(.wheel)
        .frame(height: 120)
        .clipped()
    }
}

// MARK: - Screen scaffold

private struct ScreenScaffold<Content: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                ZStack {
                    Circle()
                        .fill(CT.Colors.accent.opacity(0.12))
                        .frame(width: 56, height: 56)
                    Image(systemName: icon)
                        .font(.app(size: 24, weight: .bold))
                        .foregroundColor(CT.Colors.accent)
                }
                .padding(.top, 16)

                Text(title)
                    .font(CT.Typo.display(28))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(CT.Typo.body(14))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                content()
                    .padding(.top, 4)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 30)
        }
    }
}

private struct FieldCard<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(CT.Typo.micro(10))
                .foregroundColor(.secondary).tracking(0.8)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ctCard()
    }
}

// MARK: - Onboarding Screens

private struct OnboardingBasics: View {
    @Binding var data: OnboardingData
    var body: some View {
        ScreenScaffold(
            icon: "figure.stand",
            title: "The basics",
            subtitle: "Your body and location help us tailor a realistic path."
        ) {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    FieldCard(label: "Height") {
                        WheelPicker(range: 140...220, unit: "cm", value: $data.heightCm)
                    }
                    FieldCard(label: "Weight") {
                        WheelPicker(range: 40...150, unit: "kg", value: $data.weightKg)
                    }
                }
                FieldCard(label: "Age") {
                    WheelPicker(range: 14...85, unit: "yrs", value: $data.age)
                }
                FieldCard(label: "Location") {
                    TextField("e.g. Innsbruck, Austria", text: $data.location)
                        .font(CT.Typo.body(15))
                        .autocorrectionDisabled()
                }
            }
        }
    }
}

private struct OnboardingFitness: View {
    @Binding var data: OnboardingData
    var body: some View {
        ScreenScaffold(
            icon: "heart.fill",
            title: "How fit are you?",
            subtitle: "VO₂max is optional — we'll scale the plan either way."
        ) {
            VStack(spacing: 12) {
                FieldCard(label: "Endurance level") {
                    VStack(spacing: 6) {
                        ForEach(EnduranceLevel.allCases, id: \.self) { lvl in
                            Button(action: {
                                HapticManager.shared.light()
                                withAnimation(CT.Springs.snappy) { data.endurance = lvl }
                            }) {
                                HStack {
                                    Text(lvl.rawValue)
                                        .font(.app(size: 15, weight: .semibold))
                                    Spacer()
                                    if data.endurance == lvl {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(CT.Colors.accent)
                                            .transition(.scale.combined(with: .opacity))
                                    }
                                }
                                .foregroundColor(.primary)
                                .padding(.vertical, 9)
                                .padding(.horizontal, 4)
                            }
                            .buttonStyle(PressableButtonStyle())
                        }
                    }
                }
                FieldCard(label: "VO₂max (0 = skip)") {
                    WheelPicker(range: 0...80, unit: "ml/kg/min", value: $data.vo2max)
                }
                FieldCard(label: "Active hours per week") {
                    WheelPicker(range: 0...30, unit: "h", value: $data.weeklyActiveHours)
                }
            }
        }
    }
}

private struct OnboardingExperience: View {
    @Binding var data: OnboardingData
    var body: some View {
        ScreenScaffold(
            icon: "mountain.2.fill",
            title: "Your experience",
            subtitle: "Be honest — this shapes how conservative your plan needs to be."
        ) {
            VStack(spacing: 12) {
                FieldCard(label: "I have") {
                    VStack(spacing: 6) {
                        ForEach(ExperienceLevel.allCases, id: \.self) { lvl in
                            Button(action: {
                                HapticManager.shared.light()
                                withAnimation(CT.Springs.snappy) {
                                    if data.experience.contains(lvl) { data.experience.removeAll { $0 == lvl } }
                                    else { data.experience.append(lvl) }
                                }
                            }) {
                                HStack(spacing: 10) {
                                    Image(systemName: data.experience.contains(lvl) ? "checkmark.square.fill" : "square")
                                        .foregroundColor(data.experience.contains(lvl) ? CT.Colors.accent : .gray)
                                    Text(lvl.rawValue)
                                        .font(.app(size: 15, weight: .semibold))
                                        .foregroundColor(.primary)
                                    Spacer()
                                }
                                .padding(.vertical, 7)
                            }
                            .buttonStyle(PressableButtonStyle())
                        }
                    }
                }
                FieldCard(label: "Glacier experience") {
                    Toggle(isOn: $data.hasGlacierExperience) {
                        Text("Yes, I've walked on a roped glacier")
                            .font(CT.Typo.body(14))
                    }
                    .tint(CT.Colors.accent)
                }
                FieldCard(label: "Typical elevation per tour") {
                    WheelPicker(range: 0...3000, unit: "m", value: $data.typicalElevationGain)
                }
            }
        }
    }
}

private struct OnboardingGoal: View {
    @Binding var data: OnboardingData
    private let suggestions = ["Mont Blanc", "Matterhorn", "Kilimanjaro", "Gran Paradiso", "Denali"]
    var body: some View {
        ScreenScaffold(
            icon: "flag.checkered",
            title: "Your objective",
            subtitle: "Pick the summit you want to climb. We'll adjust unrealistic timeframes automatically."
        ) {
            VStack(spacing: 12) {
                FieldCard(label: "Dream summit") {
                    TextField("e.g. Mont Blanc", text: $data.goalName)
                        .font(.app(size: 18, weight: .semibold))
                        .autocorrectionDisabled()
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(suggestions, id: \.self) { s in
                                Button(s) {
                                    HapticManager.shared.light()
                                    withAnimation(CT.Springs.snappy) { data.goalName = s }
                                }
                                .font(.app(size: 11, weight: .semibold))
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .background(CT.Colors.accent.opacity(data.goalName == s ? 0.22 : 0.08))
                                .foregroundColor(CT.Colors.accent)
                                .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.top, 6)
                }
                FieldCard(label: "Desired timeframe") {
                    WheelPicker(range: 1...48, unit: "months", value: $data.desiredMonths)
                }
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(CT.Colors.accent)
                    Text("If the timeframe is unsafe, we'll extend it automatically.")
                        .font(CT.Typo.body(12))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

private struct OnboardingCapacity: View {
    @Binding var data: OnboardingData
    var body: some View {
        ScreenScaffold(
            icon: "clock.fill",
            title: "Training capacity",
            subtitle: "Consistency beats volume. We'll scale the plan to your real calendar."
        ) {
            VStack(spacing: 12) {
                FieldCard(label: "Sessions per week") {
                    WheelPicker(range: 1...7, unit: "", value: $data.sessionsPerWeek)
                }
                FieldCard(label: "Minutes per session") {
                    WheelPicker(range: 20...240, unit: "min", value: $data.minutesPerSession)
                }
                HStack(spacing: 10) {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(CT.Colors.accent)
                    Text("≈ \(data.sessionsPerWeek * data.minutesPerSession / 60) h / week training load")
                        .font(CT.Typo.label(12))
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(CT.Colors.accent.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }
}

private struct OnboardingSafety: View {
    @Binding var data: OnboardingData
    var body: some View {
        ScreenScaffold(
            icon: "shield.lefthalf.filled",
            title: "Safety first",
            subtitle: "Mountaineering carries real risk. This plan is guidance — not a substitute for certified guides, weather forecasts or avalanche training."
        ) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach([
                    ("cloud.sun.fill", "Always check local weather and avalanche forecasts."),
                    ("person.2.fill", "Never solo above your experience level."),
                    ("exclamationmark.triangle.fill", "Turn around when in doubt — the summit will wait.")
                ], id: \.0) { item in
                    HStack(spacing: 12) {
                        Image(systemName: item.0)
                            .foregroundColor(CT.Colors.accent)
                            .frame(width: 22)
                        Text(item.1)
                            .font(CT.Typo.body(14))
                            .foregroundColor(.primary.opacity(0.85))
                    }
                    .padding(.vertical, 6)
                }

                Button(action: {
                    HapticManager.shared.light()
                    withAnimation(CT.Springs.snappy) { data.acceptedSafetyCommitment.toggle() }
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: data.acceptedSafetyCommitment ? "checkmark.square.fill" : "square")
                            .font(.app(size: 20))
                            .foregroundColor(data.acceptedSafetyCommitment ? CT.Colors.accent : .gray)
                        Text("I commit to following a safe training path.")
                            .font(.app(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                        Spacer()
                    }
                    .padding(14)
                    .ctCard()
                }
                .buttonStyle(PressableButtonStyle())
                .padding(.top, 6)
            }
        }
    }
}

// MARK: - Coaching Map v2

struct CoachingMapView: View {
    let plan: CoachingPlan
    let onComplete: (UUID) -> Void
    @Binding var selectedTab: CoachingViewModel.TrainingTab

    @State private var breathe = false
    @State private var selectedStation: CoachStation? = nil

    private let hikeKinds: Set<StationKind> = [.hike, .acclimatization, .glacier, .summit]
    private let gymKinds: Set<StationKind> = [.strength, .endurance, .technique]

    private var filteredStations: [CoachStation] {
        let kinds = selectedTab == .hikes ? hikeKinds : gymKinds
        return plan.stations.filter { kinds.contains($0.kind) }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    headerCard
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                    // Tab selector
                    tabPicker
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 4)

                    if selectedTab == .chat {
                        AIChatGuideView(isEmbedded: true)
                            .frame(height: UIScreen.main.bounds.height * 0.6)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                    } else {
                        let stationsToShow = filteredStations
                        let phases = PlanPhase.allCases.filter { phase in
                            stationsToShow.contains { $0.phase == phase }
                        }

                        ForEach(phases, id: \.self) { phase in
                            let phaseStations = stationsToShow.filter { $0.phase == phase }
                            if !phaseStations.isEmpty {
                                phaseHeader(phase)
                                    .padding(.horizontal, 20)
                                    .padding(.top, 22)
                                    .padding(.bottom, 6)

                                ForEach(Array(phaseStations.enumerated()), id: \.element.id) { idx, station in
                                    let globalIdx = stationsToShow.firstIndex(where: { $0.id == station.id }) ?? idx
                                    StationRow(
                                        station: station,
                                        globalIndex: globalIdx,
                                        region: plan.region,
                                        breathe: breathe,
                                        isLeft: globalIdx % 2 == 0,
                                        onTap: { selectedStation = station }
                                    )
                                    .id(station.id)

                                    if station.id != phaseStations.last?.id || phase != phases.last {
                                        PathConnector(leftToRight: globalIdx % 2 == 0, completed: station.isCompleted)
                                            .frame(height: 40)
                                    }
                                }
                            }
                        }

                        gearCard
                            .padding(.horizontal, 16)
                            .padding(.top, 24)
                            .padding(.bottom, 20)
                            
                        if plan.stations.allSatisfy({ $0.isCompleted }) {
                            Button(action: {
                                NotificationCenter.default.post(name: NSNotification.Name("ResetAICoach"), object: true)
                            }) {
                                HStack {
                                    Image(systemName: "flag.checkered")
                                    Text("Start New Objective")
                                }
                                .font(.app(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(CT.Gradients.cta)
                                .clipShape(RoundedRectangle(cornerRadius: CT.Radius.card, style: .continuous))
                                .ctShadow(CT.Shadows.glow)
                            }
                            .buttonStyle(PressableButtonStyle())
                            .padding(.horizontal, 16)
                            .padding(.bottom, 40)
                        } else {
                            Button(action: {
                                NotificationCenter.default.post(name: NSNotification.Name("ResetAICoach"), object: false)
                            }) {
                                Text("Abandon & start new plan")
                                    .font(CT.Typo.label(13))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.bottom, 40)
                        }
                    }
                }
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
                    breathe.toggle()
                }
                if let target = filteredStations.first(where: { $0.isUnlocked && !$0.isCompleted }) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(CT.Springs.soft) {
                            proxy.scrollTo(target.id, anchor: .center)
                        }
                    }
                }
            }
        }
        .sheet(item: $selectedStation) { station in
            StationDetailSheet(station: station, selectedTab: $selectedTab) {
                onComplete(station.id)
                selectedStation = nil
            }
            .presentationDetents([.fraction(0.55), .large])
            .preferredColorScheme(.light)
        }
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach(CoachingViewModel.TrainingTab.allCases, id: \.self) { tab in
                Button(action: {
                    HapticManager.shared.light()
                    withAnimation(CT.Springs.snappy) { selectedTab = tab }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: tab == .hikes ? "figure.hiking" : "dumbbell.fill")
                            .font(.app(size: 13, weight: .bold))
                        Text(tab.rawValue)
                            .font(.app(size: 14, weight: .bold))
                    }
                    .foregroundColor(selectedTab == tab ? .white : .primary.opacity(0.6))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(selectedTab == tab ? CT.Colors.accent : Color.clear)
                    )
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(CT.Colors.surface)
        )
        .ctShadow(CT.Shadows.card)
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "flag.checkered").foregroundColor(CT.Colors.accent)
                Text("YOUR OBJECTIVE")
                    .font(CT.Typo.micro(10))
                    .foregroundColor(.secondary).tracking(1)
                Spacer()
                Text(plan.region.displayName.uppercased())
                    .font(CT.Typo.micro(10))
                    .foregroundColor(CT.Colors.accent)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(CT.Colors.accent.opacity(0.1))
                    .clipShape(Capsule())
            }
            Text(plan.goalName)
                .font(CT.Typo.display(28))
            Text("\(plan.goalElevation) m")
                .font(CT.Typo.body(13))
                .foregroundColor(.secondary)

            Text(plan.headline)
                .font(CT.Typo.body(13))
                .foregroundColor(.primary.opacity(0.8))
                .padding(.top, 6)

            if plan.wasTimelineAdjusted {
                HStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(.orange)
                    Text("Timeline adjusted to \(plan.safeTimelineMonths) months for safety (from \(plan.userRequestedMonths)).")
                        .font(CT.Typo.label(11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 6)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ctCard()
    }

    private func phaseHeader(_ phase: PlanPhase) -> some View {
        let completedInPhase = plan.stations.filter { $0.phase == phase && $0.isCompleted }.count
        let totalInPhase = plan.stations.filter { $0.phase == phase }.count
        return HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(CT.Colors.accent)
                .frame(width: 3, height: 18)
            Text(phase.rawValue.uppercased())
                .font(CT.Typo.micro(11))
                .foregroundColor(.primary)
                .tracking(1.2)
            Text("\(completedInPhase)/\(totalInPhase)")
                .font(CT.Typo.micro(10))
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    private var gearCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "backpack.fill").foregroundColor(CT.Colors.accent)
                Text("RECOMMENDED GEAR")
                    .font(CT.Typo.micro(10))
                    .foregroundColor(.secondary).tracking(1)
            }
            FlowLayout(spacing: 6) {
                ForEach(plan.gearRecommendations, id: \.self) { g in
                    Text(g)
                        .font(.app(size: 11, weight: .semibold))
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(CT.Colors.accent.opacity(0.1))
                        .foregroundColor(CT.Colors.accent)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ctCard()
    }
}

// MARK: - Station Row

private struct StationRow: View {
    let station: CoachStation
    let globalIndex: Int
    let region: MountainRegion
    let breathe: Bool
    let isLeft: Bool
    let onTap: () -> Void

    var body: some View {
        HStack {
            if isLeft {
                node; Spacer()
            } else {
                Spacer(); node
            }
        }
        .padding(.horizontal, 28)
    }

    private var color: Color {
        if station.isCompleted { return CT.Colors.accent }
        if station.isRealTour { return CT.Colors.gold }
        if station.isUnlocked { return CT.Colors.accent }
        return CT.Colors.locked
    }

    private var icon: String {
        switch station.kind {
        case .hike: return "figure.hiking"
        case .technique: return "scribble.variable"
        case .strength: return "dumbbell.fill"
        case .endurance: return "heart.circle.fill"
        case .acclimatization: return "wind"
        case .glacier: return "snowflake"
        case .summit: return "flag.fill"
        }
    }

    private var node: some View {
        Button(action: { HapticManager.shared.light(); onTap() }) {
            VStack(spacing: 6) {
                ZStack {
                    if station.isUnlocked && !station.isCompleted {
                        Circle()
                            .fill(color.opacity(0.14))
                            .frame(width: 92, height: 92)
                            .scaleEffect(breathe ? 1.10 : 0.92)
                    }
                    StylizedMountain(
                        size: 60 + CGFloat(min(globalIndex, 12)) * 1.8,
                        ridgeColors: region.ridgeColors,
                        tintOverlay: station.isCompleted ? CT.Colors.accent.opacity(0.35) : Color.clear
                    )
                    .scaleEffect(breathe && station.isUnlocked ? 1.015 : 1.0)

                    Circle()
                        .fill(Color.white)
                        .frame(width: 30, height: 30)
                        .overlay(
                            Image(systemName: station.isCompleted ? "checkmark" : icon)
                                .font(.app(size: 13, weight: .bold))
                                .foregroundColor(color)
                        )
                        .offset(y: 22)
                        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)

                    if station.isRealTour {
                        Image(systemName: "sparkle")
                            .foregroundColor(CT.Colors.gold)
                            .font(.app(size: 14))
                            .offset(x: 28, y: -22)
                    }
                }
                Text(station.title)
                    .font(CT.Typo.label(11))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .frame(maxWidth: 130)
            }
        }
        .buttonStyle(PressableButtonStyle(scale: 0.94))
        // Removed `.disabled(!station.isUnlocked)` so user can view/click locked stations
        .opacity(station.isUnlocked ? 1.0 : 0.6)
    }
}

// MARK: - Stylized Mountain

private struct StylizedMountain: View {
    let size: CGFloat
    let ridgeColors: [Color]
    var tintOverlay: Color = .clear

    var body: some View {
        ZStack {
            TriangleShape()
                .fill(ridgeColors[safe: 2] ?? .gray)
                .frame(width: size * 0.95, height: size * 0.75)
                .offset(x: -size * 0.22, y: size * 0.05)
            TriangleShape()
                .fill(ridgeColors[safe: 1] ?? .gray)
                .frame(width: size * 0.88, height: size * 0.80)
                .offset(x: size * 0.18, y: size * 0.04)
            TriangleShape()
                .fill(
                    LinearGradient(
                        colors: [ridgeColors[safe: 0] ?? .gray, (ridgeColors[safe: 1] ?? .gray).opacity(0.75)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .frame(width: size, height: size * 0.95)
            TriangleShape()
                .fill(Color.white.opacity(0.9))
                .frame(width: size * 0.38, height: size * 0.32)
                .offset(y: -size * 0.30)
            TriangleShape()
                .fill(tintOverlay)
                .frame(width: size, height: size * 0.95)
                .blendMode(.plusLighter)
        }
        .frame(width: size, height: size)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private struct TriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Path Connector

private struct PathConnector: View {
    let leftToRight: Bool
    let completed: Bool
    @State private var phase: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            Path { path in
                let start = CGPoint(x: leftToRight ? geo.size.width * 0.22 : geo.size.width * 0.78, y: 0)
                let end = CGPoint(x: leftToRight ? geo.size.width * 0.78 : geo.size.width * 0.22, y: geo.size.height)
                let control = CGPoint(x: geo.size.width * 0.5, y: geo.size.height * 0.55)
                path.move(to: start)
                path.addQuadCurve(to: end, control: control)
            }
            .stroke(
                completed ? CT.Colors.accent : Color.gray.opacity(0.32),
                style: StrokeStyle(lineWidth: 2.6, lineCap: .round, dash: [5, 6], dashPhase: phase)
            )
        }
        .onAppear {
            withAnimation(.linear(duration: 14).repeatForever(autoreverses: false)) {
                phase = -60
            }
        }
    }
}

// MARK: - Station Detail

private struct StationDetailSheet: View {
    let station: CoachStation
    @Binding var selectedTab: CoachingViewModel.TrainingTab
    let onComplete: () -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Capsule().fill(Color.gray.opacity(0.3)).frame(width: 40, height: 4).frame(maxWidth: .infinity)

            HStack(spacing: 8) {
                Text(station.phase.rawValue.uppercased())
                    .font(CT.Typo.micro(9)).tracking(1)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(CT.Colors.accent.opacity(0.1))
                    .foregroundColor(CT.Colors.accent)
                    .clipShape(Capsule())
                Text(station.kind.rawValue.uppercased())
                    .font(CT.Typo.micro(9)).tracking(1)
                    .foregroundColor(.secondary)
            }

            Text(station.title)
                .font(CT.Typo.display(26))

            Text(station.subtitle)
                .font(CT.Typo.body(14))
                .foregroundColor(.secondary)

            if station.elevationGain > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.right")
                    Text("+\(station.elevationGain) m")
                }
                .font(.app(size: 13, weight: .semibold))
                .foregroundColor(CT.Colors.accent)
            }

            // Reasoning box
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "sparkles")
                    .foregroundColor(CT.Colors.accent)
                Text(station.reasoning)
                    .font(CT.Typo.body(13))
                    .foregroundColor(.primary.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CT.Colors.accent.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Spacer(minLength: 0)
            
            if let targetId = station.mountainId {
                Button(action: {
                    Task {
                        // Fetch mountain directly from DB to open in map
                        if let mountain: Mountain = try? await supabase.from("mountains")
                            .select("*, routes:mountain_routes(*)")
                            .eq("id", value: targetId)
                            .single()
                            .execute().value {
                            
                            DispatchQueue.main.async {
                                dismiss()
                                NotificationCenter.default.post(name: NSNotification.Name("OpenMountainInExplore"), object: mountain)
                            }
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: "map.fill")
                        Text("Open Peak in Explorer Map")
                    }
                    .font(.app(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(CT.Radius.card)
                    .padding(.bottom, 6)
                }
            } else if [.hike, .summit].contains(station.kind) {
                let cleanName = station.title.replacingOccurrences(of: "Prep: ", with: "").replacingOccurrences(of: "Summit: ", with: "")
                Button(action: {
                    Task {
                        // Attempt to find by exact or fuzzy name
                        if let mountain: Mountain = try? await supabase.from("mountains")
                            .select("*, routes:mountain_routes(*)")
                            .ilike("name", pattern: "%\(cleanName.components(separatedBy: " (")[0])%")
                            .limit(1)
                            .single()
                            .execute().value {
                            
                            DispatchQueue.main.async {
                                dismiss()
                                NotificationCenter.default.post(name: NSNotification.Name("OpenMountainInExplore"), object: mountain)
                            }
                        } else {
                            // Fallback if not physically in database
                            DispatchQueue.main.async {
                                dismiss()
                                NotificationCenter.default.post(name: NSNotification.Name("SearchMountainInExplore"), object: cleanName)
                            }
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: "map.fill")
                        Text("View Peak Details")
                    }
                    .font(.app(size: 15, weight: .bold))
                    .foregroundColor(CT.Colors.accent)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .background(CT.Colors.accent.opacity(0.12))
                    .cornerRadius(CT.Radius.card)
                    .padding(.bottom, 6)
                }
            }
            
            if [.strength, .endurance, .technique, .glacier].contains(station.kind) {
                Button(action: {
                    dismiss()
                    selectedTab = .chat
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        NotificationCenter.default.post(name: NSNotification.Name("AskAIAbooutStation"), object: station.title)
                    }
                }) {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("Ask AI for detailed exercises")
                    }
                    .font(.app(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .background(Color.indigo)
                    .cornerRadius(CT.Radius.card)
                    .padding(.bottom, 6)
                }
            }

            Button(action: {
                onComplete()
                dismiss()
            }) {
                Text(station.isCompleted ? "Completed" : (station.mountainId != nil ? "Mark done (Unverified)" : "Mark as done manually"))
                    .font(.app(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        RoundedRectangle(cornerRadius: CT.Radius.card, style: .continuous)
                            .fill(station.isCompleted ? AnyShapeStyle(Color.gray) : AnyShapeStyle(CT.Gradients.cta))
                    )
                    .ctShadow(CT.Shadows.glow)
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(station.isCompleted)
        }
        .padding(22)
    }
}

// MARK: - FlowLayout

struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, totalH: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x + size.width > maxW {
                x = 0; y += rowH + spacing; rowH = 0
            }
            x += size.width + spacing
            rowH = max(rowH, size.height)
            totalH = y + rowH
        }
        return CGSize(width: maxW, height: totalH)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX, y: CGFloat = bounds.minY, rowH: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX {
                x = bounds.minX; y += rowH + spacing; rowH = 0
            }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowH = max(rowH, size.height)
        }
    }
}
