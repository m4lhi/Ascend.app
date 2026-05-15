import Foundation
import SwiftUI
import Combine

// =========================================
// === DATEI: HealthCoordinator.swift ===
// === Single facade over the Health layer ===
// =========================================
//
// Orchestrates HealthKitBridge, HealthDataProvider, HealthAnalysisEngine and
// ReadinessManager. Owns the @Published health surface (profile, readiness,
// analysis) and is the sole writer back into AppState's mirror properties.
//
// MARK: - Authoritative source rule
//
// HealthCoordinator.{profile, readiness} is the authoritative state.
// AppState.{healthProfile, readiness} are mirrors for views still bound to
// AppState directly. Only this class writes into those AppState properties.
// R3 will move the mirrors into ReadinessViewModel and remove the duplication.

@MainActor
final class HealthCoordinator: ObservableObject {
    static let shared = HealthCoordinator()

    // MARK: - Published surface

    @Published private(set) var profile: HealthKitProfile?
    @Published private(set) var readiness: ReadinessBreakdown?
    @Published private(set) var analysis: HealthAnalysisResult?
    @Published private(set) var isSyncing: Bool = false

    // MARK: - Orchestrated components (private)

    private let bridge = HealthKitBridge.shared
    private let provider = HealthDataProvider.shared
    private let analysisEngine = HealthAnalysisEngine.shared
    private let readinessManager = ReadinessManager.shared

    // MARK: - AppState wiring

    private weak var appState: AppState?
    private var backgroundTask: Task<Void, Never>?
    private let analysisIntervalHours: Double = 6

    private init() {}

    // MARK: - Lifecycle

    func attach(_ appState: AppState) {
        self.appState = appState
    }

    // Invariante: detach stoppt jeden Background-Task, damit keine Task
    // weiterläuft, die in einen nil-AppState schreibt.
    func detach() {
        stopBackgroundAnalysis()
        self.appState = nil
    }

    // MARK: - Public API

    func refreshReadiness() async {
        guard let appState = appState else { return }
        isSyncing = true
        defer { isSyncing = false }

        let fetched = await bridge.requestAndFetch()
        self.profile = fetched
        appState.healthProfile = fetched

        let targetMt = await resolveTargetMountain()

        var weather: MountainWeather? = nil
        if let targetMt, let lat = targetMt.latitude, let lon = targetMt.longitude {
            await WeatherManager.shared.fetchWeather(latitude: lat, longitude: lon)
            weather = WeatherManager.shared.currentWeather
        }

        let result = readinessManager.calculate(
            profile: fetched,
            tours: appState.recentTours,
            targetMountain: targetMt,
            targetWeather: weather
        )

        self.readiness = result
        withAnimation(.spring()) {
            appState.readiness = result
        }
    }

    func startBackgroundAnalysis() {
        guard backgroundTask == nil else { return }
        guard let appState = appState else { return }
        backgroundTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.runAnalysisPass(appState: appState)
                let sleepNs = UInt64(self.analysisIntervalHours * 3600 * 1_000_000_000)
                try? await Task.sleep(nanoseconds: sleepNs)
            }
        }
    }

    func stopBackgroundAnalysis() {
        backgroundTask?.cancel()
        backgroundTask = nil
    }

    // MARK: - Internal Orchestration

    private func runAnalysisPass(appState: AppState) async {
        await analysisEngine.runAnalysis(appState: appState)
        self.analysis = analysisEngine.result
        self.profile = appState.healthProfile
    }

    private func resolveTargetMountain() async -> Mountain? {
        guard
            let goalData = UserDefaults.standard.data(forKey: "coaching_plan_data"),
            let plan = try? JSONDecoder().decode(CoachingPlan.self, from: goalData)
        else { return nil }

        let results: [Mountain]? = try? await supabase
            .from("mountains")
            .select("id,name,elevation,difficulty,region,country,image_url,latitude,longitude,isPrestigePeak")
            .ilike("name", value: "%\(plan.goalName)%")
            .limit(1)
            .execute()
            .value
        return results?.first
    }
}
