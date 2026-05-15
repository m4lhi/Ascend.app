import Foundation
import SwiftUI
import Combine
import Supabase

// =========================================
// === DATEI: ReadinessViewModel.swift ===
// === Readiness + questionnaire surface ===
// =========================================
//
// Owns the readiness-domain state that AppState used to host:
// * healthProfile + readiness — mirrored from HealthCoordinator's
//   @Published surface via Combine sinks. The Coordinator is the
//   authoritative writer (R2); we re-publish so views can bind to
//   the VM directly without reaching through the Coordinator.
// * timeToGoAnswers / timeToGoAnsweredAt — Time-to-Go contextual
//   questionnaire, persisted to UserDefaults via didSet.
// * extendedReadinessAnswers / extendedReadinessAnsweredAt — extended
//   Summit Readiness questionnaire, persisted to UserDefaults.
// * weeklyGoScores — one entry per ISO weekday, persisted.
// * readinessHistory — keyed by "yyyy-MM-dd" → score, trimmed to 90d.
//
// Persistence stays inline (small scope, no PersistenceService needed).

@MainActor
final class ReadinessViewModel: ObservableObject {
    // MARK: - Health-mirror surface (sourced from HealthCoordinator)

    @Published private(set) var healthProfile: HealthKitProfile?
    @Published private(set) var readiness: ReadinessBreakdown?

    // MARK: - Questionnaire + history surface

    @Published var timeToGoAnswers: [String: [String]] = [:] {
        didSet { saveTimeToGoAnswers() }
    }
    @Published var timeToGoAnsweredAt: Date? = nil

    @Published var extendedReadinessAnswers: [String: [String]] = [:] {
        didSet { saveExtendedReadiness() }
    }
    @Published var extendedReadinessAnsweredAt: Date? = nil

    @Published var weeklyGoScores: [Int: Int] = [:] {
        didSet { saveWeeklyGoScores() }
    }

    @Published var readinessHistory: [String: Int] = [:] {
        didSet { saveReadinessHistory() }
    }

    // MARK: - Cross-VM refs

    weak var feedVM: FeedViewModel?

    // MARK: - Combine

    private var cancellables = Set<AnyCancellable>()

    init() {
        loadContextualPersistence()

        // Mirror HealthCoordinator's @Published profile + readiness so
        // views can bind to readinessVM directly. Coordinator stays the
        // authoritative writer of those two values.
        HealthCoordinator.shared.$profile
            .receive(on: DispatchQueue.main)
            .sink { [weak self] new in self?.healthProfile = new }
            .store(in: &cancellables)
        HealthCoordinator.shared.$readiness
            .receive(on: DispatchQueue.main)
            .sink { [weak self] new in self?.readiness = new }
            .store(in: &cancellables)
    }

    // MARK: - Public actions

    /// Resolve target mountain + weather, delegate to HealthCoordinator
    /// for the actual HealthKit fetch + readiness calc. Mirrors the
    /// behavior of the previous AppState.refreshReadiness() exactly.
    func refresh() {
        Task {
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

            var weather: MountainWeather? = nil
            if let targetMt, let lat = targetMt.latitude, let lon = targetMt.longitude {
                await WeatherManager.shared.fetchWeather(latitude: lat, longitude: lon)
                weather = WeatherManager.shared.currentWeather
            }

            await HealthCoordinator.shared.refreshReadiness(
                tours: feedVM?.recentTours ?? [],
                targetMountain: targetMt,
                targetWeather: weather
            )
        }
    }

    /// Append today's score to history, trim entries older than 90 days.
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

    /// Clear the questionnaire / weekly / readiness state after a >7-day
    /// gap. AppState resets its own streak_days separately and calls
    /// this method as part of the same inactivity-reset flow.
    func applyInactivityReset() {
        weeklyGoScores = [:]
        extendedReadinessAnswers = [:]
        extendedReadinessAnsweredAt = nil
        // Hard-clear the mirrored readiness so the user sees the
        // assessment prompt instead of stale data; the next refresh()
        // populates it back from HealthCoordinator.
        readiness = nil
        UserDefaults.standard.removeObject(forKey: "extendedReadinessAnswers")
        UserDefaults.standard.removeObject(forKey: "extendedReadinessAnsweredAt")
    }

    // MARK: - Time-to-Go composite + stage mapping

    /// Time-to-Go composite score (0–100). Combines readiness, recent
    /// workload and the subjective answers from timeToGoAnswers.
    /// Conservative by design — missing data pulls the score down.
    var timeToGoScore: Int {
        let readinessPart = Double(readiness?.totalScore ?? 50)
        let answered = timeToGoAnswers.values.filter { !$0.isEmpty && $0 != [""] }.count
        let subjectiveBonus = min(Double(answered) * 3.0, 30.0)
        let mandatoryAnswered = ["sleep", "nutrition", "weather", "gear", "partners", "motivation"]
            .filter { !(timeToGoAnswers[$0]?.isEmpty ?? true) }
            .count
        let mandatoryFactor = Double(mandatoryAnswered) / 6.0
        let raw = (readinessPart * 0.55 + subjectiveBonus * 1.5) * max(0.4, mandatoryFactor)
        return min(100, max(0, Int(raw)))
    }

    /// Map a 0–100 score onto 5 stages for the Time-to-Go tracker pills.
    /// 0 = deep-red (do not go), 4 = deep-green (prime).
    func goStage(for score: Int) -> Int {
        switch score {
        case ..<25: return 0
        case ..<45: return 1
        case ..<65: return 2
        case ..<82: return 3
        default:    return 4
        }
    }

    // MARK: - Private persistence

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

    private func loadContextualPersistence() {
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

    private func isoDateKey(_ date: Date) -> String {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: date)
    }
}
