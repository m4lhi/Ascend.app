import SwiftUI
import Combine
import Supabase
import CoreLocation

// =========================================
// === DATEI: FitnessOnboardingView.swift ===
// === Immersive Fitness Onboarding ===
// =========================================

// MARK: - Fitness Level Definitions

struct FitnessLevel {
    let icon: String
    let title: String
    let subtitle: String
    let elevationCap: Int
    let difficulties: [Difficulty]
    let color: Color
}

let fitnessLevels: [FitnessLevel] = [
    FitnessLevel(icon: "figure.walk",     title: "Beginner", subtitle: "First steps on the mountain",
                 elevationCap: 1500,  difficulties: [.easy],                          color: .green),
    FitnessLevel(icon: "figure.hiking",   title: "Casual",   subtitle: "Weekend hiker",
                 elevationCap: 2500,  difficulties: [.easy, .medium],                 color: .blue),
    FitnessLevel(icon: "mountain.2.fill", title: "Active",   subtitle: "Regular trail runner",
                 elevationCap: 3500,  difficulties: [.easy, .medium, .hard],          color: .orange),
    FitnessLevel(icon: "figure.climbing", title: "Athletic", subtitle: "Experienced alpinist",
                 elevationCap: 4500,  difficulties: [.medium, .hard, .extreme],       color: .red),
    FitnessLevel(icon: "crown.fill",      title: "Elite",    subtitle: "High-altitude expert",
                 elevationCap: 99999, difficulties: Difficulty.allCases,              color: .purple),
]

// MARK: - Fitness Score Engine

struct FitnessScoreEngine {
    struct Input {
        var age: Int
        var heightCm: Int
        var weightKg: Int
        var vo2max: Int?
        var dailyStepsAvg: Int?
        var weeklyActiveCalories: Int?
        var weeklyWorkouts: Int?
        var avgRunningPaceMinPerKm: Double?
        var highestPeakElevation: Int?
        var restingHeartRate: Int?
    }

    static func compute(from input: Input) -> (score: Int, level: Int, breakdown: [(label: String, pts: Int, max: Int)]) {
        var breakdown: [(label: String, pts: Int, max: Int)] = []

        // VO2 Max — 30 pts
        let v: Int
        if let vo2 = input.vo2max {
            v = vo2 >= 60 ? 30 : vo2 >= 50 ? 24 : vo2 >= 40 ? 18 : vo2 >= 30 ? 10 : 4
        } else { v = 0 }
        breakdown.append(("VO₂ Max", v, 30))

        // Daily steps — 15 pts
        let s: Int
        if let steps = input.dailyStepsAvg {
            s = steps >= 12000 ? 15 : steps >= 8000 ? 11 : steps >= 5000 ? 7 : steps >= 2000 ? 3 : 0
        } else { s = 0 }
        breakdown.append(("Daily Steps", s, 15))

        // Active calories — 15 pts
        let c: Int
        if let cal = input.weeklyActiveCalories {
            c = cal >= 3000 ? 15 : cal >= 2000 ? 11 : cal >= 1000 ? 7 : cal >= 400 ? 3 : 0
        } else { c = 0 }
        breakdown.append(("Active Calories", c, 15))

        // Running pace — 10 pts
        let p: Int
        if let pace = input.avgRunningPaceMinPerKm {
            p = pace <= 4.5 ? 10 : pace <= 5.5 ? 7 : pace <= 7.0 ? 4 : 1
        } else { p = 0 }
        breakdown.append(("Running Pace", p, 10))

        // Weekly workouts — 10 pts
        let w: Int
        if let wo = input.weeklyWorkouts {
            w = wo >= 5 ? 10 : wo >= 3 ? 7 : wo >= 2 ? 4 : wo >= 1 ? 2 : 0
        } else { w = 0 }
        breakdown.append(("Weekly Workouts", w, 10))

        // Highest peak — 15 pts
        let pk: Int
        if let elev = input.highestPeakElevation {
            pk = elev >= 4000 ? 15 : elev >= 3000 ? 11 : elev >= 2000 ? 7 : elev >= 1000 ? 4 : 1
        } else { pk = 0 }
        breakdown.append(("Peak Experience", pk, 15))

        // Resting HR — 5 pts
        let hr: Int
        if let rhr = input.restingHeartRate {
            hr = rhr <= 50 ? 5 : rhr <= 60 ? 3 : rhr <= 70 ? 1 : 0
        } else { hr = 0 }
        breakdown.append(("Resting Heart Rate", hr, 5))

        var total = v + s + c + p + w + pk + hr

        // Age adjustment
        let ageAdj = input.age <= 25 ? 3 : input.age <= 35 ? 0 : input.age <= 50 ? -3 : -6
        total = max(0, min(100, total + ageAdj))

        let level = total >= 80 ? 5 : total >= 60 ? 4 : total >= 40 ? 3 : total >= 20 ? 2 : 1
        return (total, level, breakdown)
    }
}

// MARK: - Onboarding State

@MainActor
class FitnessOnboardingState: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let totalSteps = 8

    // Navigation
    @Published var step = 0
    @Published var direction = 1  // 1 = forward, -1 = backward

    // Personal stats
    @Published var age: Int = 25
    @Published var heightCm: Int = 175
    @Published var weightKg: Int = 75

    // Health
    @Published var healthProfile: HealthKitProfile? = nil
    @Published var healthState: HealthState = .idle
    @Published var isLoadingHealth = false

    // Activity (optional)
    @Published var manualVo2Max: Int? = nil
    @Published var showVo2Input = false
    @Published var paceMinutes: Int = 5
    @Published var paceSeconds: Int = 30
    @Published var includePace = false
    @Published var weeklyStrengthDays: Int = 0

    // Mountain experience
    @Published var searchText = ""
    @Published var searchResults: [Mountain] = []
    @Published var selectedPeaks: [Mountain] = []
    @Published var isSearching = false
    @Published var searchTask: Task<Void, Never>? = nil

    // Location
    @Published var locationStatus: CLAuthorizationStatus = .notDetermined
    private var locationManager: CLLocationManager?

    func requestLocation() {
        let manager = CLLocationManager()
        manager.delegate = self
        self.locationManager = manager
        locationStatus = manager.authorizationStatus
        if locationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in self.locationStatus = status }
    }

    // Analysis result
    @Published var analysisSteps: [(label: String, done: Bool)] = []
    @Published var breakdown: [(label: String, pts: Int, max: Int)] = []
    @Published var finalScore = 0
    @Published var finalLevel = 0
    @Published var isAnalysisDone = false

    enum HealthState { case idle, requesting, granted, denied }

    var effectiveVo2: Int? { manualVo2Max ?? healthProfile?.vo2max }

    var runningPaceMinPerKm: Double? {
        guard includePace else { return healthProfile?.avgRunningPaceMinPerKm }
        return Double(paceMinutes) + Double(paceSeconds) / 60.0
    }

    var highestSelectedPeak: Int? { selectedPeaks.map { $0.elevation }.max() }

    var scoreInput: FitnessScoreEngine.Input {
        FitnessScoreEngine.Input(
            age: age,
            heightCm: heightCm,
            weightKg: weightKg,
            vo2max: effectiveVo2,
            dailyStepsAvg: healthProfile?.dailyStepsAvg,
            weeklyActiveCalories: healthProfile?.weeklyActiveCalories,
            weeklyWorkouts: healthProfile?.weeklyWorkoutsCount ?? (weeklyStrengthDays > 0 ? weeklyStrengthDays : nil),
            avgRunningPaceMinPerKm: runningPaceMinPerKm,
            highestPeakElevation: highestSelectedPeak,
            restingHeartRate: healthProfile?.restingHeartRate
        )
    }

    func advance() {
        direction = 1
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) { step += 1 }
    }

    func goBack() {
        guard step > 0 else { return }
        direction = -1
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) { step -= 1 }
    }

    func requestHealth() async {
        isLoadingHealth = true
        healthState = .requesting
        let profile = await HealthKitBridge.shared.requestAndFetch()
        healthProfile = profile
        healthState = (profile.heightCm != nil || profile.vo2max != nil || profile.dailyStepsAvg != nil) ? .granted : .denied
        isLoadingHealth = false
        // Pre-fill stats from Health if not yet set
        if let h = profile.heightCm { heightCm = h }
        if let w = profile.weightKg { weightKg = w }
    }

    func searchMountains() {
        searchTask?.cancel()
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else { searchResults = []; return }
        searchTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            isSearching = true
            do {
                let safe = query.replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "")
                let results: [Mountain] = try await supabase
                    .from("mountains")
                    .select("id,name,elevation,difficulty,region,country,image_url,latitude,longitude,isPrestigePeak")
                    .or("name.ilike.%\(safe)%,region.ilike.%\(safe)%")
                    .order("elevation", ascending: false)
                    .limit(20)
                    .execute()
                    .value
                if !Task.isCancelled { searchResults = results }
            } catch { }
            isSearching = false
        }
    }

    func runAnalysis() async {
        let steps: [String] = [
            "Reading physical profile…",
            "Processing Apple Health data…",
            "Evaluating VO₂ Max…",
            "Analyzing mountain experience…",
            "Calculating fitness score…",
            "Matching recommended peaks…",
        ]
        analysisSteps = steps.map { ($0, false) }

        for i in analysisSteps.indices {
            try? await Task.sleep(nanoseconds: 480_000_000)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                analysisSteps[i].done = true
            }
        }

        let result = FitnessScoreEngine.compute(from: scoreInput)
        finalScore = result.score
        finalLevel = result.level
        breakdown = result.breakdown

        try? await Task.sleep(nanoseconds: 400_000_000)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) { isAnalysisDone = true }
    }
}

// MARK: - Main View

struct FitnessOnboardingView: View {
    @AppStorage("userFitnessLevel") private var userFitnessLevel = 0
    @AppStorage("userMaxElevation") private var userMaxElevation = 0
    @AppStorage("userWeeklyDays") private var userWeeklyDays = 0
    @AppStorage("fitnessOnboardingCompleted") private var fitnessOnboardingCompleted = false

    let onComplete: () -> Void

    @StateObject private var state = FitnessOnboardingState()
    private let accent = DesignSystem.Colors.accent

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            RadialGradient(colors: [accent.opacity(0.08), .clear], center: .top, startRadius: 0, endRadius: 360)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    if state.step > 0 && state.step < FitnessOnboardingState.totalSteps - 1 {
                        Button { state.goBack() } label: {
                            Image(systemName: "chevron.left")
                                .font(.app(size: 16, weight: .semibold))
                                .foregroundColor(.primary.opacity(0.6))
                                .frame(width: 36, height: 36)
                                .background(Color.black.opacity(0.07))
                                .clipShape(Circle())
                        }
                    } else { Color.clear.frame(width: 36, height: 36) }

                    Spacer()
                    stepIndicator
                    Spacer()

                    if state.step < FitnessOnboardingState.totalSteps - 1 {
                        Button { saveAndComplete() } label: {
                            Text("Skip")
                                .font(.app(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                    } else { Color.clear.frame(width: 36, height: 36) }
                }
                .padding(.horizontal, 20)
                .padding(.top, 56)
                .padding(.bottom, 20)

                // Step content
                stepContent
                    .transition(.asymmetric(
                        insertion: .move(edge: state.direction > 0 ? .trailing : .leading).combined(with: .opacity),
                        removal: .move(edge: state.direction > 0 ? .leading : .trailing).combined(with: .opacity)
                    ))
                    .id(state.step)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Bottom action
                if state.step < FitnessOnboardingState.totalSteps - 1 && state.step != 6 {
                    bottomButton
                        .padding(.horizontal, 24)
                        .padding(.bottom, 48)
                }
            }
        }
        .onChange(of: state.searchText) { _, _ in state.searchMountains() }
        .onChange(of: state.isAnalysisDone) { _, done in
            if done { withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) { state.step = 6 } }
        }
    }

    // MARK: - Step Routing
    @ViewBuilder
    var stepContent: some View {
        switch state.step {
        case 0: WelcomeStep()
        case 1: PersonalStatsStep(state: state)
        case 2: LocationStep(state: state)
        case 3: HealthStep(state: state)
        case 4: MountainSearchStep(state: state)
        case 5: ActivityStep(state: state)
        case 6: AnalysisStep(state: state)
        default: ResultStep(state: state, onSave: saveAndComplete)
        }
    }

    // MARK: - Step indicator
    var stepIndicator: some View {
        HStack(spacing: 5) {
            ForEach(0..<FitnessOnboardingState.totalSteps, id: \.self) { i in
                Capsule()
                    .fill(i == state.step ? accent : Color.black.opacity(0.12))
                    .frame(width: i == state.step ? 22 : 6, height: 6)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: state.step)

            }
        }
    }

    // MARK: - Bottom button
    var bottomButton: some View {
        Button {
            handleNext()
        } label: {
            HStack(spacing: 8) {
                Text(buttonTitle)
                    .font(.app(size: 17, weight: .black))
                Image(systemName: "arrow.right")
                    .font(.app(size: 15, weight: .bold))
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(accent)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: accent.opacity(0.4), radius: 14, y: 6)
        }
    }

    var buttonTitle: String {
        switch state.step {
        case 2: return state.locationStatus == .notDetermined ? "Allow Location" : "Continue"
        case 3: return state.healthState == .idle ? "Connect Apple Health" : "Continue"
        case 4: return state.selectedPeaks.isEmpty ? "Skip for now" : "Continue (\(state.selectedPeaks.count) peaks)"
        case 5: return "Analyse My Fitness"
        default: return "Continue"
        }
    }

    func handleNext() {
        if state.step == 2 && state.locationStatus == .notDetermined {
            state.requestLocation()
            return
        }
        if state.step == 3 && state.healthState == .idle {
            Task { await state.requestHealth() }
            return
        }
        if state.step == 5 {
            state.advance()
            Task { await state.runAnalysis() }
            return
        }
        state.advance()
    }

    func saveAndComplete() {
        userFitnessLevel = state.finalLevel > 0 ? state.finalLevel : 2
        userMaxElevation = state.highestSelectedPeak ?? 0
        userWeeklyDays = state.weeklyStrengthDays
        fitnessOnboardingCompleted = true
        HapticManager.shared.success()
        onComplete()
    }
}

// MARK: - Step 0: Welcome

private struct WelcomeStep: View {
    @State private var appeared = false
    private let accent = DesignSystem.Colors.accent

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(accent.opacity(0.08 - Double(i) * 0.02))
                        .frame(width: CGFloat(130 + i * 50), height: CGFloat(130 + i * 50))
                        .scaleEffect(appeared ? 1 : 0.4)
                        .animation(.spring(response: 0.7, dampingFraction: 0.6).delay(Double(i) * 0.12), value: appeared)
                }
                Image(systemName: "mountain.2.fill")
                    .font(.system(size: 64, weight: .bold))
                    .foregroundStyle(LinearGradient(colors: [accent, accent.opacity(0.7)], startPoint: .top, endPoint: .bottom))
                    .scaleEffect(appeared ? 1 : 0.3)
                    .animation(.spring(response: 0.6, dampingFraction: 0.55).delay(0.1), value: appeared)
            }

            VStack(spacing: 14) {
                Text("Know Your Mountain")
                    .font(.app(size: 32, weight: .black))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.25), value: appeared)

                Text("We analyze your real fitness data — not just what you think — to recommend peaks that challenge without risking you.")
                    .font(.app(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 28)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.38), value: appeared)
            }

            VStack(spacing: 10) {
                ForEach(["Age · Height · Weight", "Location & Nearby Peaks", "Apple Health Integration", "VO₂ Max & Heart Rate", "Your Climbed Peaks"], id: \.self) { item in
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(accent)
                            .font(.app(size: 14))
                        Text(item)
                            .font(.app(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 40)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)
            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.5), value: appeared)

            Spacer()
        }
        .onAppear { withAnimation { appeared = true } }
    }
}

// MARK: - Step 1: Personal Stats

private struct PersonalStatsStep: View {
    @ObservedObject var state: FitnessOnboardingState
    private let accent = DesignSystem.Colors.accent

    var bmi: Double? {
        let h = Double(state.heightCm) / 100.0
        guard h > 0 else { return nil }
        return Double(state.weightKg) / (h * h)
    }

    var bmiLabel: String {
        guard let b = bmi else { return "" }
        if b < 18.5 { return "Underweight" }
        if b < 25   { return "Normal" }
        if b < 30   { return "Overweight" }
        return "Obese"
    }

    var bmiColor: Color {
        guard let b = bmi else { return .gray }
        if b < 18.5 { return .blue }
        if b < 25   { return .green }
        if b < 30   { return .orange }
        return .red
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                stepHeader(title: "About You", subtitle: "This helps calibrate your fitness score accurately.")

                // Age
                StatCard(icon: "person.fill", label: "Age", color: accent) {
                    HStack {
                        Text("\(state.age) years")
                            .font(.app(size: 22, weight: .black))
                            .foregroundColor(.primary)
                        Spacer()
                        Stepper("", value: $state.age, in: 14...90)
                            .labelsHidden()
                            .tint(accent)
                    }
                    Slider(value: Binding(get: { Double(state.age) }, set: { state.age = Int($0) }), in: 14...90, step: 1)
                        .tint(accent)
                }

                // Height
                StatCard(icon: "arrow.up.and.down", label: "Height", color: .blue) {
                    HStack {
                        Text("\(state.heightCm) cm")
                            .font(.app(size: 22, weight: .black))
                            .foregroundColor(.primary)
                        Spacer()
                        Stepper("", value: $state.heightCm, in: 120...230)
                            .labelsHidden()
                            .tint(.blue)
                    }
                    Slider(value: Binding(get: { Double(state.heightCm) }, set: { state.heightCm = Int($0) }), in: 120...230, step: 1)
                        .tint(.blue)
                }

                // Weight
                StatCard(icon: "scalemass.fill", label: "Weight", color: .orange) {
                    HStack {
                        Text("\(state.weightKg) kg")
                            .font(.app(size: 22, weight: .black))
                            .foregroundColor(.primary)
                        Spacer()
                        Stepper("", value: $state.weightKg, in: 30...200)
                            .labelsHidden()
                            .tint(.orange)
                    }
                    Slider(value: Binding(get: { Double(state.weightKg) }, set: { state.weightKg = Int($0) }), in: 30...200, step: 1)
                        .tint(.orange)
                }

                // BMI pill
                if let b = bmi {
                    HStack {
                        Spacer()
                        HStack(spacing: 6) {
                            Circle().fill(bmiColor).frame(width: 8, height: 8)
                            Text(String(format: "BMI %.1f · %@", b, bmiLabel))
                                .font(.app(size: 12, weight: .semibold))
                                .foregroundColor(bmiColor)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(bmiColor.opacity(0.12))
                        .clipShape(Capsule())
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
    }
}

// MARK: - Step 2: Location

private struct LocationStep: View {
    @ObservedObject var state: FitnessOnboardingState
    private let accent = DesignSystem.Colors.accent
    @State private var appeared = false

    var statusColor: Color {
        switch state.locationStatus {
        case .authorizedWhenInUse, .authorizedAlways: return .green
        case .denied, .restricted: return .orange
        default: return .secondary
        }
    }

    var statusText: String {
        switch state.locationStatus {
        case .authorizedWhenInUse, .authorizedAlways: return "Location access granted"
        case .denied, .restricted: return "Access denied — tap Continue to skip"
        default: return "Tap below to allow location access"
        }
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                ForEach(0..<2) { i in
                    Circle()
                        .fill(Color.blue.opacity(0.07 - Double(i) * 0.02))
                        .frame(width: CGFloat(110 + i * 50), height: CGFloat(110 + i * 50))
                        .scaleEffect(appeared ? 1 : 0.5)
                        .animation(.spring(response: 0.65, dampingFraction: 0.65).delay(Double(i) * 0.1), value: appeared)
                }
                Image(systemName: "location.fill")
                    .font(.system(size: 52, weight: .bold))
                    .foregroundColor(.blue)
                    .scaleEffect(appeared ? 1 : 0.3)
                    .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.08), value: appeared)
            }

            VStack(spacing: 12) {
                Text("Your Location")
                    .font(.app(size: 28, weight: .black))
                    .foregroundColor(.primary)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.22), value: appeared)

                Text("We use your location to recommend nearby peaks and calculate your distance to every mountain.")
                    .font(.app(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 28)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.32), value: appeared)
            }

            VStack(spacing: 10) {
                ForEach([
                    ("location.fill", "Find peaks near you", Color.blue),
                    ("arrow.triangle.swap", "Calculate distances", Color.green),
                    ("mountain.2.fill", "Sort by proximity", accent),
                ], id: \.0) { icon, text, color in
                    HStack(spacing: 12) {
                        Image(systemName: icon)
                            .foregroundColor(color)
                            .font(.app(size: 16))
                            .frame(width: 26)
                        Text(text)
                            .font(.app(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 36)
                }
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)
            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.42), value: appeared)

            HStack(spacing: 6) {
                Circle().fill(statusColor).frame(width: 7, height: 7)
                Text(statusText)
                    .font(.app(size: 13, weight: .semibold))
                    .foregroundColor(statusColor)
            }
            .padding(.horizontal, 16).padding(.vertical, 9)
            .background(statusColor.opacity(0.1))
            .clipShape(Capsule())
            .animation(.spring(response: 0.4), value: state.locationStatus)

            if state.locationStatus == .notDetermined {
                Button { state.requestLocation() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "location.fill")
                        Text("Allow Location Access")
                            .font(.app(size: 16, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color.blue.opacity(0.3), radius: 10, y: 4)
                }
                .padding(.horizontal, 32)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }

            Spacer()
        }
        .onAppear { withAnimation { appeared = true } }
    }
}

// MARK: - Step 3: Apple Health

private struct HealthStep: View {
    @ObservedObject var state: FitnessOnboardingState
    private let accent = DesignSystem.Colors.accent
    @State private var appeared = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                stepHeader(title: "Apple Health", subtitle: "Connect once — no manual guesswork.")

                // Permission card
                VStack(spacing: 20) {
                    ZStack {
                        Circle().fill(Color.red.opacity(0.12)).frame(width: 80, height: 80)
                        Image(systemName: "heart.fill")
                            .font(.system(size: 38, weight: .bold))
                            .foregroundColor(.red)
                    }

                    Text("What we read")
                        .font(.app(size: 13, weight: .bold))
                        .foregroundColor(.secondary)

                    VStack(spacing: 8) {
                        ForEach(healthItems, id: \.0) { item in
                            HStack(spacing: 12) {
                                Image(systemName: item.1)
                                    .font(.app(size: 14))
                                    .foregroundColor(item.2)
                                    .frame(width: 24)
                                Text(item.0)
                                    .font(.app(size: 14, weight: .medium))
                                    .foregroundColor(.primary)
                                Spacer()
                                if case .granted = state.healthState, let val = item.3 {
                                    Text(val)
                                        .font(.app(size: 12, weight: .bold))
                                        .foregroundColor(accent)
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                            .padding(.horizontal, 16).padding(.vertical, 10)
                            .background(Color.black.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    if case .denied = state.healthState {
                        Text("Permission denied or no data found. You can continue manually.")
                            .font(.app(size: 12))
                            .foregroundColor(.orange.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12)
                    }

                    if state.isLoadingHealth {
                        HStack(spacing: 10) {
                            ProgressView().tint(accent)
                            Text("Reading Apple Health…")
                                .font(.app(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(20)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
                .padding(.horizontal, 20)

                // Privacy note
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill").font(.app(size: 11)).foregroundColor(.secondary)
                    Text("Read-only · Never stored on our servers")
                        .font(.app(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.bottom, 100)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: state.healthState == .granted)
    }

    var healthItems: [(String, String, Color, String?)] {
        let hp = state.healthProfile
        return [
            ("VO₂ Max",          "waveform.path.ecg",          .green,  hp?.vo2max.map { "\($0) ml/kg/min" }),
            ("Resting Heart Rate","heart.fill",                  .red,    hp?.restingHeartRate.map { "\($0) bpm" }),
            ("Daily Steps",      "figure.walk",                 .blue,   hp?.dailyStepsAvg.map { "\($0 / 1000)k steps/day" }),
            ("Active Calories",  "flame.fill",                  .orange, hp?.weeklyActiveCalories.map { "\($0) kcal/week" }),
            ("Weekly Workouts",  "dumbbell.fill",               accent,  hp?.weeklyWorkoutsCount.map { "\($0) sessions" }),
            ("Running Pace",     "stopwatch.fill",              .cyan,   hp?.avgRunningPaceMinPerKm.map { String(format: "%.1f min/km", $0) }),
        ]
    }
}

// MARK: - Step 3: Mountain Experience

private struct MountainSearchStep: View {
    @ObservedObject var state: FitnessOnboardingState
    private let accent = DesignSystem.Colors.accent
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepHeader(title: "Your Peaks", subtitle: "Search and select mountains you've already climbed.")
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

            // Search bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary).font(.app(size: 15))
                TextField("Search mountains…", text: $state.searchText)
                    .focused($focused)
                    .foregroundColor(.primary)
                    .font(.app(size: 15))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                if state.isSearching {
                    ProgressView().tint(accent).scaleEffect(0.7)
                }
                if !state.searchText.isEmpty {
                    Button { state.searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.08), lineWidth: 1))
            .padding(.horizontal, 20)

            // Selected peaks chips
            if !state.selectedPeaks.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Spacer().frame(width: 12)
                        ForEach(state.selectedPeaks, id: \.id) { peak in
                            HStack(spacing: 4) {
                                Text(peak.name)
                                    .font(.app(size: 12, weight: .bold))
                                    .foregroundColor(.black)
                                Text("\(peak.elevation)m")
                                    .font(.app(size: 10))
                                    .foregroundColor(.black.opacity(0.6))
                                Button { state.selectedPeaks.removeAll { $0.id == peak.id } } label: {
                                    Image(systemName: "xmark").font(.system(size: 9, weight: .bold)).foregroundColor(.black.opacity(0.6))
                                }
                            }
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(accent)
                            .clipShape(Capsule())
                        }
                        Spacer().frame(width: 12)
                    }
                }
                .padding(.vertical, 10)
            }

            // Results
            if state.searchText.count >= 2 {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(state.searchResults, id: \.id) { mountain in
                            let isSelected = state.selectedPeaks.contains(where: { $0.id == mountain.id })
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    if isSelected { state.selectedPeaks.removeAll { $0.id == mountain.id } }
                                    else { state.selectedPeaks.append(mountain) }
                                }
                                HapticManager.shared.light()
                            } label: {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(isSelected ? accent : Color.white.opacity(0.08))
                                            .frame(width: 36, height: 36)
                                        Image(systemName: isSelected ? "checkmark" : "mountain.2")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(isSelected ? .black : .white.opacity(0.6))
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(mountain.name)
                                            .font(.app(size: 15, weight: .bold))
                                            .foregroundColor(.primary)
                                        Text("\(mountain.elevation)m · \(mountain.region)")
                                            .font(.app(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    difficultyPill(mountain.difficulty)
                                }
                                .padding(.horizontal, 20).padding(.vertical, 12)
                                .background(isSelected ? accent.opacity(0.08) : Color.clear)
                            }
                            .buttonStyle(.plain)
                            Divider().background(Color.white.opacity(0.06)).padding(.leading, 68)
                        }
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 40, weight: .light))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("Type at least 2 characters\nto search peaks from our database")
                        .font(.app(size: 13))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear { focused = true }
    }

    func difficultyPill(_ diff: Difficulty) -> some View {
        Text(diff.rawValue)
            .font(.app(size: 9, weight: .black))
            .foregroundColor(.white)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(diff.color.opacity(0.8))
            .clipShape(Capsule())
    }
}

// MARK: - Step 4: Activity (Optional)

private struct ActivityStep: View {
    @ObservedObject var state: FitnessOnboardingState
    private let accent = DesignSystem.Colors.accent

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                stepHeader(title: "Activity Profile", subtitle: "Optional — but makes your score more accurate.")
                    .overlay(alignment: .topTrailing) {
                        Text("Optional")
                            .font(.app(size: 10, weight: .bold))
                            .foregroundColor(accent.opacity(0.7))
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(accent.opacity(0.1))
                            .clipShape(Capsule())
                            .padding(.trailing, 20)
                    }

                // Running pace
                StatCard(icon: "figure.run", label: "Running Pace", color: .cyan) {
                    Toggle(isOn: $state.includePace.animation(.spring())) {
                        Text("I run regularly")
                            .font(.app(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    .tint(accent)

                    if state.includePace {
                        VStack(spacing: 8) {
                            HStack {
                                Text("Average pace")
                                    .font(.app(size: 13))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(String(format: "%d:%02d min/km", state.paceMinutes, state.paceSeconds))
                                    .font(.app(size: 16, weight: .black))
                                    .foregroundColor(accent)
                            }

                            HStack(spacing: 16) {
                                VStack(spacing: 4) {
                                    Text("Minutes").font(.app(size: 10)).foregroundColor(.secondary)
                                    Picker("", selection: $state.paceMinutes) {
                                        ForEach(3...12, id: \.self) { Text("\($0)") }
                                    }
                                    .pickerStyle(.wheel)
                                    .frame(width: 70, height: 80)
                                    .clipped()
                                }
                                Text(":").font(.app(size: 24, weight: .black)).foregroundColor(.secondary)
                                VStack(spacing: 4) {
                                    Text("Seconds").font(.app(size: 10)).foregroundColor(.secondary)
                                    Picker("", selection: $state.paceSeconds) {
                                        ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { Text(String(format: "%02d", $0)) }
                                    }
                                    .pickerStyle(.wheel)
                                    .frame(width: 70, height: 80)
                                    .clipped()
                                }
                            }
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // From Health if available
                    if let pace = state.healthProfile?.avgRunningPaceMinPerKm, !state.includePace {
                        HStack(spacing: 6) {
                            Image(systemName: "heart.fill").font(.app(size: 10)).foregroundColor(.red)
                            Text(String(format: "From Apple Health: %.1f min/km", pace))
                                .font(.app(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Strength training
                StatCard(icon: "dumbbell.fill", label: "Strength Training", color: .orange) {
                    VStack(spacing: 10) {
                        HStack {
                            Text("Days per week")
                                .font(.app(size: 14, weight: .semibold))
                                .foregroundColor(.primary)
                            Spacer()
                            Text(state.weeklyStrengthDays == 0 ? "None" : "\(state.weeklyStrengthDays)×")
                                .font(.app(size: 16, weight: .black))
                                .foregroundColor(.orange)
                        }
                        HStack(spacing: 8) {
                            ForEach(0...6, id: \.self) { d in
                                Button {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { state.weeklyStrengthDays = d }
                                    HapticManager.shared.light()
                                } label: {
                                    Text(d == 0 ? "–" : "\(d)")
                                        .font(.app(size: 13, weight: .bold))
                                        .foregroundColor(state.weeklyStrengthDays == d ? .black : .white.opacity(0.5))
                                        .frame(maxWidth: .infinity).padding(.vertical, 9)
                                        .background(state.weeklyStrengthDays == d ? Color.orange : Color.white.opacity(0.08))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .scaleEffect(state.weeklyStrengthDays == d ? 1.06 : 1.0)
                                }
                            }
                        }
                    }
                }

                // Manual VO2 Max
                StatCard(icon: "waveform.path.ecg", label: "VO₂ Max (Optional)", color: .green) {
                    if state.effectiveVo2 == nil || state.showVo2Input {
                        VStack(spacing: 10) {
                            HStack {
                                Text("I know my VO₂ Max")
                                    .font(.app(size: 14, weight: .semibold))
                                    .foregroundColor(.primary)
                                Spacer()
                                Toggle("", isOn: $state.showVo2Input.animation(.spring()))
                                    .labelsHidden()
                                    .tint(accent)
                            }
                            if state.showVo2Input {
                                HStack {
                                    Text(state.manualVo2Max.map { "\($0)" } ?? "–")
                                        .font(.app(size: 28, weight: .black))
                                        .foregroundColor(.green)
                                    Text("ml/kg/min")
                                        .font(.app(size: 13))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Stepper("", value: Binding(
                                        get: { state.manualVo2Max ?? 35 },
                                        set: { state.manualVo2Max = $0 }
                                    ), in: 20...90).labelsHidden().tint(.green)
                                }
                                Slider(value: Binding(
                                    get: { Double(state.manualVo2Max ?? 35) },
                                    set: { state.manualVo2Max = Int($0) }
                                ), in: 20...90, step: 1).tint(.green)
                                Text("Average: 35–45 · Elite: 60+")
                                    .font(.app(size: 11)).foregroundColor(.secondary)
                            }
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                    } else if let v = state.effectiveVo2 {
                        HStack(spacing: 6) {
                            Image(systemName: "heart.fill").font(.app(size: 10)).foregroundColor(.red)
                            Text("From Apple Health: \(v) ml/kg/min")
                                .font(.app(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
    }
}

// MARK: - Step 5: Analysis

private struct AnalysisStep: View {
    @ObservedObject var state: FitnessOnboardingState
    private let accent = DesignSystem.Colors.accent

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            if !state.isAnalysisDone {
                VStack(spacing: 24) {
                    ZStack {
                        Circle()
                            .stroke(Color.black.opacity(0.08), lineWidth: 3)
                            .frame(width: 90, height: 90)
                        Circle()
                            .trim(from: 0, to: CGFloat(state.analysisSteps.filter { $0.done }.count) / CGFloat(max(1, state.analysisSteps.count)))
                            .stroke(accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .frame(width: 90, height: 90)
                            .rotationEffect(.degrees(-90))
                            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: state.analysisSteps.filter { $0.done }.count)
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(accent)
                    }

                    Text("Analyzing your profile…")
                        .font(.app(size: 22, weight: .black))
                        .foregroundColor(.primary)

                    VStack(spacing: 10) {
                        ForEach(Array(state.analysisSteps.enumerated()), id: \.offset) { i, step in
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(step.done ? accent : Color.black.opacity(0.08))
                                        .frame(width: 22, height: 22)
                                    if step.done {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.black)
                                            .transition(.scale.combined(with: .opacity))
                                    }
                                }
                                Text(step.label)
                                    .font(.app(size: 13, weight: step.done ? .semibold : .regular))
                                    .foregroundColor(step.done ? .primary : .secondary)
                                    .animation(.spring(response: 0.3), value: step.done)
                                Spacer()
                            }
                        }
                    }
                    .padding(.horizontal, 32)
                }
            }

            Spacer()
        }
    }
}

// MARK: - Step 6: Result

private struct ResultStep: View {
    @ObservedObject var state: FitnessOnboardingState
    let onSave: () -> Void
    private let accent = DesignSystem.Colors.accent
    @State private var scoreDisplayed = 0
    @State private var appeared = false

    var level: FitnessLevel { fitnessLevels[min(max(state.finalLevel - 1, 0), fitnessLevels.count - 1)] }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                // Score ring
                ZStack {
                    Circle()
                        .stroke(Color.black.opacity(0.07), lineWidth: 10)
                        .frame(width: 150, height: 150)
                    Circle()
                        .trim(from: 0, to: appeared ? CGFloat(state.finalScore) / 100.0 : 0)
                        .stroke(level.color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .frame(width: 150, height: 150)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 1.2, dampingFraction: 0.8).delay(0.2), value: appeared)

                    VStack(spacing: 4) {
                        Text("\(scoreDisplayed)")
                            .font(.system(size: 42, weight: .black, design: .rounded))
                            .foregroundColor(.primary)
                        Text("/ 100")
                            .font(.app(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 8)

                // Level badge
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: level.icon)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(level.color)
                        Text(level.title)
                            .font(.app(size: 28, weight: .black))
                            .foregroundColor(.primary)
                    }
                    Text(level.subtitle)
                        .font(.app(size: 14))
                        .foregroundColor(.secondary)
                }

                // Breakdown
                VStack(spacing: 0) {
                    Text("Score Breakdown")
                        .font(.app(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 10)

                    ForEach(state.breakdown, id: \.label) { item in
                        HStack(spacing: 10) {
                            Text(item.label)
                                .font(.app(size: 13))
                                .foregroundColor(.secondary)
                                .frame(width: 130, alignment: .leading)

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.white.opacity(0.07)).frame(height: 6)
                                    Capsule()
                                        .fill(item.pts > 0 ? accent : Color.white.opacity(0.1))
                                        .frame(width: appeared ? geo.size.width * CGFloat(item.pts) / CGFloat(max(item.max, 1)) : 0, height: 6)
                                        .animation(.spring(response: 0.8, dampingFraction: 0.75).delay(0.3), value: appeared)
                                }
                            }
                            .frame(height: 6)

                            Text("\(item.pts)/\(item.max)")
                                .font(.app(size: 11, weight: .bold))
                                .foregroundColor(item.pts > 0 ? accent : Color.white.opacity(0.2))
                                .frame(width: 36, alignment: .trailing)
                        }
                        .padding(.vertical, 7)
                        Divider().background(Color.white.opacity(0.06))
                    }
                }
                .padding(16)
                .background(Color(.systemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 18))

                // Save button
                Button { onSave() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "mountain.2.fill")
                        Text("Explore My Mountains")
                            .font(.app(size: 17, weight: .black))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(accent)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .shadow(color: accent.opacity(0.45), radius: 16, y: 8)
                }
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 20)
        }
        .onAppear {
            withAnimation { appeared = true }
            animateScore()
        }
    }

    func animateScore() {
        let target = state.finalScore
        let steps = 40
        let delay = 0.6
        for i in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + Double(i) * 0.025) {
                scoreDisplayed = Int(Double(target) * Double(i) / Double(steps))
            }
        }
    }
}

// MARK: - Shared UI Helpers

private func stepHeader(title: String, subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        Text(title)
            .font(.app(size: 28, weight: .black))
            .foregroundColor(.primary)
        Text(subtitle)
            .font(.app(size: 14))
            .foregroundColor(.secondary)
            .lineSpacing(2)
    }
}

private struct StatCard<Content: View>: View {
    let icon: String
    let label: String
    let color: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.app(size: 13, weight: .bold))
                    .foregroundColor(color)
                Text(label)
                    .font(.app(size: 12, weight: .bold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
            content()
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.black.opacity(0.06), lineWidth: 1))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }
}
