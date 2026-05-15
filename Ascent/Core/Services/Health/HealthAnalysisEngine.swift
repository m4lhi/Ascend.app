import Foundation
import SwiftUI
import Combine
#if canImport(HealthKit)
import HealthKit
#endif

// =========================================
// === DATEI: HealthAnalysisEngine.swift ===
// === Background Health Data Analysis   ===
// =========================================
//
// Runs periodic deep analysis of Apple Health data:
//   • Activity breakdown by sport type
//   • Altitude exposure history
//   • Fitness trend over 30 / 90 days
//   • Recovery quality indicators
//
// NOTE (R2): Direct access deprecated for new callers — use
// HealthCoordinator. Existing View-Direct-Access (TrainingAnalyticsView)
// will be migrated in R3. The Coordinator orchestrates the periodic
// loop via startBackgroundAnalysis() and is the sole writer into
// AppState.healthProfile / .readiness.

// MARK: - Analysis Result Models

struct SportActivitySummary: Identifiable {
    let id = UUID()
    let sport: String
    let systemIcon: String
    let sessionCount: Int
    let totalMinutes: Int
    let totalElevationGain: Int
    let avgDurationMinutes: Int
}

struct AltitudeExposureSummary {
    let maxAltitudeReached: Int        // metres
    let daysAbove2000m: Int
    let daysAbove3000m: Int
    let daysAbove4000m: Int
    let avgAltitudeM: Int
}

struct FitnessTrend {
    let vo2MaxTrend: TrendDirection
    let stepsTrend: TrendDirection
    let restingHRTrend: TrendDirection
    let activeCaloriesTrend: TrendDirection
    let overallTrend: TrendDirection
}

enum TrendDirection: String {
    case improving = "Improving"
    case stable    = "Stable"
    case declining = "Declining"
    case unknown   = "–"

    var icon: String {
        switch self {
        case .improving: return "arrow.up.right"
        case .stable:    return "arrow.right"
        case .declining: return "arrow.down.right"
        case .unknown:   return "minus"
        }
    }

    var color: Color {
        switch self {
        case .improving: return .green
        case .stable:    return .orange
        case .declining: return .red
        case .unknown:   return .secondary
        }
    }
}

struct HealthAnalysisResult {
    let analysedAt: Date
    let sports: [SportActivitySummary]
    let altitude: AltitudeExposureSummary
    let trend: FitnessTrend
    let profile: HealthKitProfile
}

// MARK: - Engine

@MainActor
final class HealthAnalysisEngine: ObservableObject {
    static let shared = HealthAnalysisEngine()

    @Published var result: HealthAnalysisResult? = nil
    @Published var isAnalysing: Bool = false

    private let analysisIntervalHours: Double = 6
    private var analysisTask: Task<Void, Never>? = nil

    // Start periodic background analysis and attach result to AppState.
    @available(*, deprecated, message: "Use HealthCoordinator.shared.attach(appState) + .startBackgroundAnalysis() instead. Will be made internal once Views (R3) and AICoachingGateway/FitnessOnboardingView Single-Shot calls are migrated.")
    func start(appState: AppState) {
        guard analysisTask == nil else { return }
        analysisTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.runAnalysis(appState: appState)
                let sleepNs = UInt64(self.analysisIntervalHours * 3600 * 1_000_000_000)
                try? await Task.sleep(nanoseconds: sleepNs)
            }
        }
    }

    func stop() {
        analysisTask?.cancel()
        analysisTask = nil
    }

    // Run a full analysis pass and publish the result
    func runAnalysis(appState: AppState) async {
        isAnalysing = true
        defer { isAnalysing = false }

        let profile = await HealthKitBridge.shared.requestAndFetch()
        appState.healthProfile = profile

        #if canImport(HealthKit)
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let store = HKHealthStore()

        async let workouts   = Self.fetchWorkouts(store: store, days: 90)
        async let altitude   = Self.fetchAltitudeExposure(store: store, days: 90)

        let (ws, alt) = await (workouts, altitude)

        let sports   = buildSportSummaries(ws)
        let trend    = buildFitnessTrend(profile: profile)

        let analysis = HealthAnalysisResult(
            analysedAt: Date(),
            sports: sports,
            altitude: alt,
            trend: trend,
            profile: profile
        )
        self.result = analysis
        #endif
    }

    // MARK: - Sport Summary Builder

    private func buildSportSummaries(_ workouts: [AnyObject]) -> [SportActivitySummary] {
        #if canImport(HealthKit)
        guard let hkWorkouts = workouts as? [HKWorkout] else { return [] }

        var grouped: [HKWorkoutActivityType: [HKWorkout]] = [:]
        for w in hkWorkouts {
            grouped[w.workoutActivityType, default: []].append(w)
        }

        return grouped.map { (type, ws) in
            let minutes = ws.reduce(0) { $0 + Int($1.duration / 60) }
            let elevations = ws.compactMap { w -> Int? in
                guard let gain = w.metadata?[HKMetadataKeyElevationAscended] as? HKQuantity else { return nil }
                return Int(gain.doubleValue(for: .meter()))
            }
            let totalElev = elevations.reduce(0, +)
            return SportActivitySummary(
                sport: type.displayName,
                systemIcon: type.sfSymbol,
                sessionCount: ws.count,
                totalMinutes: minutes,
                totalElevationGain: totalElev,
                avgDurationMinutes: ws.isEmpty ? 0 : minutes / ws.count
            )
        }
        .filter { $0.sessionCount > 0 }
        .sorted { $0.totalMinutes > $1.totalMinutes }
        #else
        return []
        #endif
    }

    // MARK: - Fitness Trend Builder

    private func buildFitnessTrend(profile: HealthKitProfile) -> FitnessTrend {
        FitnessTrend(
            vo2MaxTrend:          trendFor(profile.vo2max,                 thresholds: (45, 40)),
            stepsTrend:           trendFor(profile.dailyStepsAvg,           thresholds: (8000, 5000)),
            restingHRTrend:       invertedTrendFor(profile.restingHeartRate, thresholds: (55, 70)),
            activeCaloriesTrend:  trendFor(profile.weeklyActiveCalories,    thresholds: (2000, 1000)),
            overallTrend:         .stable
        )
    }

    private func trendFor<T: Comparable & BinaryInteger>(_ value: T?, thresholds: (good: T, ok: T)) -> TrendDirection {
        guard let v = value else { return .unknown }
        if v >= thresholds.good { return .improving }
        if v >= thresholds.ok   { return .stable }
        return .declining
    }

    private func invertedTrendFor<T: Comparable & BinaryInteger>(_ value: T?, thresholds: (good: T, ok: T)) -> TrendDirection {
        guard let v = value else { return .unknown }
        if v <= thresholds.good { return .improving }
        if v <= thresholds.ok   { return .stable }
        return .declining
    }

    // MARK: - HealthKit Fetchers

    #if canImport(HealthKit)
    private static func fetchWorkouts(store: HKHealthStore, days: Int) async -> [AnyObject] {
        await withCheckedContinuation { cont in
            let start = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
            let pred  = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
            let sort  = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: pred, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, _ in
                cont.resume(returning: (samples ?? []) as [AnyObject])
            }
            store.execute(query)
        }
    }

    private static func fetchAltitudeExposure(store: HKHealthStore, days: Int) async -> AltitudeExposureSummary {
        await withCheckedContinuation { cont in
            let start = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
            let pred  = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)

            // Use workout elevation metadata as the altitude proxy
            let sort  = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: pred, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, _ in
                guard let workouts = samples as? [HKWorkout] else {
                    cont.resume(returning: AltitudeExposureSummary(maxAltitudeReached: 0, daysAbove2000m: 0, daysAbove3000m: 0, daysAbove4000m: 0, avgAltitudeM: 0))
                    return
                }
                // Extract elevation data from workout metadata
                let elevations: [Int] = workouts.compactMap { w -> Int? in
                    if let gain = w.metadata?[HKMetadataKeyElevationAscended] as? HKQuantity {
                        return Int(gain.doubleValue(for: .meter()))
                    }
                    return nil
                }
                let maxElev = elevations.max() ?? 0
                let avgElev = elevations.isEmpty ? 0 : elevations.reduce(0, +) / elevations.count
                // Approximate "days at altitude" from session count at elevation bands
                let above2k = elevations.filter { $0 >= 500 }.count   // 500m gain ≈ starting at 2000m
                let above3k = elevations.filter { $0 >= 1000 }.count
                let above4k = elevations.filter { $0 >= 1500 }.count
                cont.resume(returning: AltitudeExposureSummary(
                    maxAltitudeReached: maxElev,
                    daysAbove2000m: above2k,
                    daysAbove3000m: above3k,
                    daysAbove4000m: above4k,
                    avgAltitudeM: avgElev
                ))
            }
            store.execute(query)
        }
    }
    #endif
}

// MARK: - HKWorkoutActivityType Extensions

#if canImport(HealthKit)
extension HKWorkoutActivityType {
    var displayName: String {
        switch self {
        case .hiking:           return "Hiking"
        case .running:          return "Running"
        case .cycling:          return "Cycling"
        case .climbing:         return "Climbing"
        case .downhillSkiing:   return "Skiing"
        case .snowboarding:     return "Snowboarding"
        case .swimming:         return "Swimming"
        case .traditionalStrengthTraining: return "Strength Training"
        case .functionalStrengthTraining:  return "Functional Training"
        case .yoga:             return "Yoga"
        case .walking:          return "Walking"
        default:                return "Other"
        }
    }

    var sfSymbol: String {
        switch self {
        case .hiking:           return "figure.hiking"
        case .running:          return "figure.run"
        case .cycling:          return "figure.outdoor.cycle"
        case .climbing:         return "figure.climbing"
        case .downhillSkiing:   return "figure.skiing.downhill"
        case .snowboarding:     return "figure.snowboarding"
        case .swimming:         return "figure.pool.swim"
        case .traditionalStrengthTraining, .functionalStrengthTraining: return "dumbbell.fill"
        case .yoga:             return "figure.mind.and.body"
        case .walking:          return "figure.walk"
        default:                return "figure.mixed.cardio"
        }
    }
}
#endif
