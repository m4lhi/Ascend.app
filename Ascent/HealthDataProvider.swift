//
//  HealthDataProvider.swift
//  Ascent
//
//  Time-series HealthKit queries for charts and dashboards.
//  Returns arrays of (date, value) for sparklines, trend charts, and zone bars.
//

import Foundation
import SwiftUI
import Combine
#if canImport(HealthKit)
import HealthKit
#endif

// MARK: - Data Point Model

struct HealthDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

struct SleepStage: Identifiable {
    let id = UUID()
    let start: Date
    let end: Date
    let stage: SleepStageType
}

enum SleepStageType: String, CaseIterable {
    case awake   = "Awake"
    case rem     = "REM"
    case core    = "Core"
    case deep    = "Deep"

    var color: Color {
        switch self {
        case .awake: return DesignSystem.Colors.metricEnergy
        case .rem:   return DesignSystem.Colors.metricSleep
        case .core:  return DesignSystem.Colors.metricOxygen
        case .deep:  return Color(red: 0.20, green: 0.25, blue: 0.65)
        }
    }

    var label: String { rawValue }
}

struct HeartRateZoneData: Identifiable {
    let id = UUID()
    let zone: Int
    let label: String
    let minutes: Double
    let color: Color
    let percentage: Double
}

struct DailyMetric: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let label: String
}

struct WorkoutSummary: Identifiable {
    let id = UUID()
    let date: Date
    let type: String
    let icon: String
    let durationMinutes: Int
    let calories: Int
    let elevationGain: Int
    let distanceKm: Double
    let avgHeartRate: Int?
}

// MARK: - Health Data Provider

@MainActor
final class HealthDataProvider: ObservableObject {
    static let shared = HealthDataProvider()

    #if canImport(HealthKit)
    private let store = HKHealthStore()
    #endif

    @Published var heartRateHistory: [HealthDataPoint] = []
    @Published var hrvHistory: [HealthDataPoint] = []
    @Published var restingHRHistory: [HealthDataPoint] = []
    @Published var vo2maxHistory: [HealthDataPoint] = []
    @Published var spo2History: [HealthDataPoint] = []
    @Published var bodyTempHistory: [HealthDataPoint] = []
    @Published var sleepStages: [SleepStage] = []
    @Published var sleepDurationHistory: [HealthDataPoint] = []
    @Published var stepHistory: [HealthDataPoint] = []
    @Published var calorieHistory: [HealthDataPoint] = []
    @Published var elevationHistory: [HealthDataPoint] = []
    @Published var hrZoneData: [HeartRateZoneData] = []
    @Published var recentWorkouts: [WorkoutSummary] = []
    @Published var weeklyTrainingLoad: [DailyMetric] = []
    @Published var respiratoryRateHistory: [HealthDataPoint] = []

    @Published var isLoading = false

    func fetchAll() async {
        isLoading = true
        defer { isLoading = false }

        #if canImport(HealthKit)
        guard HKHealthStore.isHealthDataAvailable() else { return }

        async let hr = fetchTimeSeries(.heartRate, unit: .count().unitDivided(by: .minute()), days: 7, aggregation: .hourly)
        async let hrv = fetchTimeSeries(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), days: 30, aggregation: .daily)
        async let rhr = fetchTimeSeries(.restingHeartRate, unit: .count().unitDivided(by: .minute()), days: 30, aggregation: .daily)
        async let vo2 = fetchTimeSeries(.vo2Max, unit: HKUnit(from: "ml/kg*min"), days: 180, aggregation: .daily)
        async let spo2 = fetchTimeSeries(.oxygenSaturation, unit: .percent(), days: 14, aggregation: .daily)
        async let temp = fetchTimeSeries(.bodyTemperature, unit: .degreeCelsius(), days: 14, aggregation: .daily)
        async let resp = fetchTimeSeries(.respiratoryRate, unit: HKUnit.count().unitDivided(by: .minute()), days: 14, aggregation: .daily)
        async let steps = fetchDailySum(.stepCount, unit: .count(), days: 30)
        async let cals = fetchDailySum(.activeEnergyBurned, unit: .kilocalorie(), days: 30)
        async let sleep = fetchSleepStages()
        async let sleepDur = fetchSleepDurationHistory(days: 14)
        async let zones = fetchHeartRateZones(days: 7)
        async let workouts = fetchRecentWorkouts(days: 30)
        async let loadData = fetchWeeklyTrainingLoad(days: 28)

        heartRateHistory = await hr
        hrvHistory = await hrv
        restingHRHistory = await rhr
        vo2maxHistory = await vo2
        spo2History = await spo2.map { HealthDataPoint(date: $0.date, value: $0.value * 100) }
        bodyTempHistory = await temp
        respiratoryRateHistory = await resp
        stepHistory = await steps
        calorieHistory = await cals
        sleepStages = await sleep
        sleepDurationHistory = await sleepDur
        hrZoneData = await zones
        recentWorkouts = await workouts
        weeklyTrainingLoad = await loadData
        #endif
    }

    // MARK: - Time Series Fetcher

    #if canImport(HealthKit)
    enum Aggregation { case hourly, daily }

    private func fetchTimeSeries(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        days: Int,
        aggregation: Aggregation
    ) async -> [HealthDataPoint] {
        await withCheckedContinuation { cont in
            guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else {
                cont.resume(returning: [])
                return
            }
            let start = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
            let pred = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)

            let interval: DateComponents
            switch aggregation {
            case .hourly: interval = DateComponents(hour: 1)
            case .daily:  interval = DateComponents(day: 1)
            }

            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: pred,
                options: [.discreteAverage],
                anchorDate: Calendar.current.startOfDay(for: start),
                intervalComponents: interval
            )

            query.initialResultsHandler = { _, results, _ in
                var points: [HealthDataPoint] = []
                results?.enumerateStatistics(from: start, to: Date()) { stats, _ in
                    if let avg = stats.averageQuantity() {
                        points.append(HealthDataPoint(date: stats.startDate, value: avg.doubleValue(for: unit)))
                    }
                }
                cont.resume(returning: points)
            }
            store.execute(query)
        }
    }

    private func fetchDailySum(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        days: Int
    ) async -> [HealthDataPoint] {
        await withCheckedContinuation { cont in
            guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else {
                cont.resume(returning: [])
                return
            }
            let start = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
            let pred = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
            let interval = DateComponents(day: 1)

            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: pred,
                options: [.cumulativeSum],
                anchorDate: Calendar.current.startOfDay(for: start),
                intervalComponents: interval
            )

            query.initialResultsHandler = { _, results, _ in
                var points: [HealthDataPoint] = []
                results?.enumerateStatistics(from: start, to: Date()) { stats, _ in
                    if let sum = stats.sumQuantity() {
                        points.append(HealthDataPoint(date: stats.startDate, value: sum.doubleValue(for: unit)))
                    }
                }
                cont.resume(returning: points)
            }
            store.execute(query)
        }
    }

    // MARK: - Sleep Stages

    private func fetchSleepStages() async -> [SleepStage] {
        await withCheckedContinuation { cont in
            let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
            let start = Calendar.current.date(byAdding: .hour, value: -24, to: Date()) ?? Date()
            let pred = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

            let query = HKSampleQuery(sampleType: sleepType, predicate: pred, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, _ in
                guard let samples = samples as? [HKCategorySample] else {
                    cont.resume(returning: [])
                    return
                }
                let stages = samples.compactMap { sample -> SleepStage? in
                    let stage: SleepStageType
                    if #available(iOS 16.0, *) {
                        switch sample.value {
                        case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:  stage = .deep
                        case HKCategoryValueSleepAnalysis.asleepCore.rawValue:  stage = .core
                        case HKCategoryValueSleepAnalysis.asleepREM.rawValue:   stage = .rem
                        case HKCategoryValueSleepAnalysis.awake.rawValue:       stage = .awake
                        default: stage = .core
                        }
                    } else {
                        switch sample.value {
                        case HKCategoryValueSleepAnalysis.asleep.rawValue: stage = .core
                        case HKCategoryValueSleepAnalysis.awake.rawValue:  stage = .awake
                        default: stage = .core
                        }
                    }
                    return SleepStage(start: sample.startDate, end: sample.endDate, stage: stage)
                }
                cont.resume(returning: stages)
            }
            store.execute(query)
        }
    }

    private func fetchSleepDurationHistory(days: Int) async -> [HealthDataPoint] {
        await withCheckedContinuation { cont in
            let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
            let start = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
            let pred = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

            let query = HKSampleQuery(sampleType: sleepType, predicate: pred, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, _ in
                guard let samples = samples as? [HKCategorySample] else {
                    cont.resume(returning: [])
                    return
                }
                let asleepSamples = samples.filter {
                    $0.value != HKCategoryValueSleepAnalysis.awake.rawValue &&
                    $0.value != HKCategoryValueSleepAnalysis.inBed.rawValue
                }

                var dailyTotals: [String: Double] = [:]
                let fmt = DateFormatter()
                fmt.dateFormat = "yyyy-MM-dd"

                for sample in asleepSamples {
                    let key = fmt.string(from: sample.startDate)
                    let hours = sample.endDate.timeIntervalSince(sample.startDate) / 3600
                    dailyTotals[key, default: 0] += hours
                }

                let points = dailyTotals.compactMap { (key, hours) -> HealthDataPoint? in
                    guard let date = fmt.date(from: key) else { return nil }
                    return HealthDataPoint(date: date, value: hours)
                }.sorted { $0.date < $1.date }

                cont.resume(returning: points)
            }
            store.execute(query)
        }
    }

    // MARK: - Heart Rate Zones

    private func fetchHeartRateZones(days: Int) async -> [HeartRateZoneData] {
        await withCheckedContinuation { cont in
            guard let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
                cont.resume(returning: [])
                return
            }
            let start = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
            let pred = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

            let query = HKSampleQuery(sampleType: hrType, predicate: pred, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, _ in
                guard let samples = samples as? [HKQuantitySample], !samples.isEmpty else {
                    cont.resume(returning: Self.emptyZones())
                    return
                }

                var zoneCounts = [0, 0, 0, 0, 0]
                let maxHR = 190.0

                for sample in samples {
                    let bpm = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                    let pct = bpm / maxHR
                    if pct < 0.60      { zoneCounts[0] += 1 }
                    else if pct < 0.70 { zoneCounts[1] += 1 }
                    else if pct < 0.80 { zoneCounts[2] += 1 }
                    else if pct < 0.90 { zoneCounts[3] += 1 }
                    else               { zoneCounts[4] += 1 }
                }

                let total = Double(zoneCounts.reduce(0, +))
                let labels = ["Zone 1", "Zone 2", "Zone 3", "Zone 4", "Zone 5"]
                let colors = [DesignSystem.Colors.zone1, DesignSystem.Colors.zone2, DesignSystem.Colors.zone3, DesignSystem.Colors.zone4, DesignSystem.Colors.zone5]

                let data = (0..<5).map { i in
                    HeartRateZoneData(
                        zone: i + 1,
                        label: labels[i],
                        minutes: Double(zoneCounts[i]),
                        color: colors[i],
                        percentage: total > 0 ? Double(zoneCounts[i]) / total : 0
                    )
                }
                cont.resume(returning: data)
            }
            store.execute(query)
        }
    }

    private static func emptyZones() -> [HeartRateZoneData] {
        let labels = ["Zone 1", "Zone 2", "Zone 3", "Zone 4", "Zone 5"]
        let colors = [DesignSystem.Colors.zone1, DesignSystem.Colors.zone2, DesignSystem.Colors.zone3, DesignSystem.Colors.zone4, DesignSystem.Colors.zone5]
        return (0..<5).map { i in
            HeartRateZoneData(zone: i+1, label: labels[i], minutes: 0, color: colors[i], percentage: 0)
        }
    }

    // MARK: - Recent Workouts

    private func fetchRecentWorkouts(days: Int) async -> [WorkoutSummary] {
        await withCheckedContinuation { cont in
            let start = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
            let pred = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

            let query = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: pred, limit: 20, sortDescriptors: [sort]) { _, samples, _ in
                guard let workouts = samples as? [HKWorkout] else {
                    cont.resume(returning: [])
                    return
                }
                let summaries = workouts.map { w in
                    let elev = (w.metadata?[HKMetadataKeyElevationAscended] as? HKQuantity)
                        .map { Int($0.doubleValue(for: .meter())) } ?? 0
                    let dist = w.totalDistance?.doubleValue(for: .meter()) ?? 0
                    return WorkoutSummary(
                        date: w.startDate,
                        type: w.workoutActivityType.displayName,
                        icon: w.workoutActivityType.sfSymbol,
                        durationMinutes: Int(w.duration / 60),
                        calories: Int(w.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0),
                        elevationGain: elev,
                        distanceKm: dist / 1000,
                        avgHeartRate: nil
                    )
                }
                cont.resume(returning: summaries)
            }
            store.execute(query)
        }
    }

    // MARK: - Training Load (weekly elevation gain per day)

    private func fetchWeeklyTrainingLoad(days: Int) async -> [DailyMetric] {
        await withCheckedContinuation { cont in
            let start = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
            let pred = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

            let query = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: pred, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, _ in
                guard let workouts = samples as? [HKWorkout] else {
                    cont.resume(returning: [])
                    return
                }
                let fmt = DateFormatter()
                fmt.dateFormat = "yyyy-MM-dd"

                var daily: [String: Double] = [:]
                for w in workouts {
                    let key = fmt.string(from: w.startDate)
                    let elev = (w.metadata?[HKMetadataKeyElevationAscended] as? HKQuantity)
                        .map { $0.doubleValue(for: .meter()) } ?? 0
                    let load = (w.duration / 60) + elev * 0.5
                    daily[key, default: 0] += load
                }

                let metrics = daily.compactMap { (key, val) -> DailyMetric? in
                    guard let date = fmt.date(from: key) else { return nil }
                    return DailyMetric(date: date, value: val, label: key)
                }.sorted { $0.date < $1.date }

                cont.resume(returning: metrics)
            }
            store.execute(query)
        }
    }
    #endif
}
