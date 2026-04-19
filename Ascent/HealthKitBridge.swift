import Foundation
#if canImport(HealthKit)
import HealthKit
#endif

// =========================================
// === DATEI: HealthKitBridge.swift ===
// === Read-only HealthKit prefill ===
// =========================================

struct HealthKitProfile {
    var heightCm: Int?
    var weightKg: Int?
    var vo2max: Int?
    var weeklyActiveHours: Int?        // kept for AICoachingGateway compatibility
    var weeklyActiveCalories: Int?
    var dailyStepsAvg: Int?
    var restingHeartRate: Int?
    var weeklyWorkoutsCount: Int?
    var avgRunningPaceMinPerKm: Double?
    
    // Pro Mountaineer Metrics
    var heartRateVariability: Double?    // SDNN in ms
    var bloodOxygenSaturation: Double?   // SpO2 in %
    var respiratoryRate: Double?         // Breaths per min
    var sleepMinutesLastNight: Int?
    var isSleepRestful: Bool?

    var bmi: Double? {
        guard let h = heightCm, let w = weightKg, h > 0 else { return nil }
        let hM = Double(h) / 100.0
        return Double(w) / (hM * hM)
    }
}

@MainActor
final class HealthKitBridge {
    static let shared = HealthKitBridge()

    #if canImport(HealthKit)
    private let store = HKHealthStore()
    #endif

    func requestAndFetch() async -> HealthKitProfile {
        var result = HealthKitProfile()

        #if canImport(HealthKit)
        guard HKHealthStore.isHealthDataAvailable() else { return result }

        let height  = HKObjectType.quantityType(forIdentifier: .height)!
        let weight  = HKObjectType.quantityType(forIdentifier: .bodyMass)!
        let vo2     = HKObjectType.quantityType(forIdentifier: .vo2Max)!
        let energy  = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        let steps   = HKObjectType.quantityType(forIdentifier: .stepCount)!
        let rhr     = HKObjectType.quantityType(forIdentifier: .restingHeartRate)!
        let hrv     = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
        let spo2    = HKObjectType.quantityType(forIdentifier: .oxygenSaturation)!
        let resp    = HKObjectType.quantityType(forIdentifier: .respiratoryRate)!
        let sleep   = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let workout = HKObjectType.workoutType()

        let readSet: Set<HKObjectType> = [height, weight, vo2, energy, steps, rhr, hrv, spo2, resp, sleep, workout]

        do {
            try await store.requestAuthorization(toShare: [], read: readSet)
        } catch {
            return result
        }

        // Parallel reads
        async let heightVal = Self.latestQuantity(store: store, type: height, unit: .meterUnit(with: .centi))
        async let weightVal = Self.latestQuantity(store: store, type: weight, unit: .gramUnit(with: .kilo))
        async let vo2Val    = Self.latestQuantity(store: store, type: vo2, unit: HKUnit(from: "ml/kg*min"))
        async let kcalVal   = Self.periodSum(store: store, type: energy, unit: .kilocalorie(), days: 7)
        async let stepsVal  = Self.periodSum(store: store, type: steps, unit: .count(), days: 30)
        async let rhrVal    = Self.latestQuantity(store: store, type: rhr, unit: .count().unitDivided(by: .minute()))
        async let workoutsVal = Self.recentWorkouts(store: store, days: 7)
        async let runPaceVal  = Self.avgRunningPaceMinPerKm(store: store, days: 30)
        
        async let hrvVal      = Self.latestQuantity(store: store, type: hrv, unit: .secondUnit(with: .milli))
        async let spo2Val     = Self.latestQuantity(store: store, type: spo2, unit: .percent())
        async let respVal     = Self.latestQuantity(store: store, type: resp, unit: HKUnit.count().unitDivided(by: .minute()))
        async let sleepVal    = Self.lastNightSleep(store: store)

        result.heightCm             = await heightVal.map { Int($0.rounded()) }
        result.weightKg             = await weightVal.map { Int($0.rounded()) }
        result.vo2max               = await vo2Val.map { Int($0.rounded()) }
        result.restingHeartRate     = await rhrVal.map { Int($0.rounded()) }
        result.avgRunningPaceMinPerKm = await runPaceVal
        
        result.heartRateVariability = await hrvVal
        result.bloodOxygenSaturation = await spo2Val.map { $0 * 100.0 }
        result.respiratoryRate      = await respVal
        
        if let sData = await sleepVal {
            result.sleepMinutesLastNight = sData.minutes
            result.isSleepRestful = sData.isRestful
        }

        if let kcal = await kcalVal {
            let intKcal = Int(kcal.rounded())
            result.weeklyActiveCalories = intKcal
            result.weeklyActiveHours    = Int((kcal / 500.0).rounded())
        }
        if let totalSteps = await stepsVal {
            result.dailyStepsAvg = Int((totalSteps / 30.0).rounded())
        }
        result.weeklyWorkoutsCount = await workoutsVal
        #endif

        return result
    }

    // Legacy entry point — used by AICoachingGateway
    func fetchProfile() async -> HealthKitProfile {
        await requestAndFetch()
    }

    #if canImport(HealthKit)
    private static func latestQuantity(store: HKHealthStore, type: HKQuantityType, unit: HKUnit) async -> Double? {
        await withCheckedContinuation { cont in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                if let q = (samples?.first as? HKQuantitySample)?.quantity {
                    cont.resume(returning: q.doubleValue(for: unit))
                } else {
                    cont.resume(returning: nil)
                }
            }
            store.execute(query)
        }
    }

    private static func periodSum(store: HKHealthStore, type: HKQuantityType, unit: HKUnit, days: Int) async -> Double? {
        await withCheckedContinuation { cont in
            let start = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
            let pred  = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: pred, options: .cumulativeSum) { _, stats, _ in
                cont.resume(returning: stats?.sumQuantity()?.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }

    private static func recentWorkouts(store: HKHealthStore, days: Int) async -> Int? {
        await withCheckedContinuation { cont in
            let start = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
            let pred  = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
            let sort  = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: pred, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, _ in
                cont.resume(returning: samples?.count)
            }
            store.execute(query)
        }
    }

    private static func avgRunningPaceMinPerKm(store: HKHealthStore, days: Int) async -> Double? {
        await withCheckedContinuation { cont in
            let start = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
            let pred  = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
            let sort  = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: pred, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, _ in
                guard let workouts = samples as? [HKWorkout] else { cont.resume(returning: nil); return }
                let runs = workouts.filter { $0.workoutActivityType == .running && $0.totalDistance != nil && $0.duration > 60 }
                if runs.isEmpty { cont.resume(returning: nil); return }
                let paces: [Double] = runs.compactMap { w -> Double? in
                    guard let dist = w.totalDistance?.doubleValue(for: .meter()), dist > 100 else { return nil }
                    let minPerKm = (w.duration / 60.0) / (dist / 1000.0)
                    return minPerKm
                }
                guard !paces.isEmpty else { cont.resume(returning: nil); return }
                cont.resume(returning: paces.reduce(0, +) / Double(paces.count))
            }
            store.execute(query)
        }
    }

    private static func lastNightSleep(store: HKHealthStore) async -> (minutes: Int, isRestful: Bool)? {
        await withCheckedContinuation { cont in
            let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
            let calendar = Calendar.current
            let start = calendar.date(byAdding: .hour, value: -24, to: Date()) ?? Date()
            let pred = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            
            let query = HKSampleQuery(sampleType: sleepType, predicate: pred, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, _ in
                guard let sleepSamples = samples as? [HKCategorySample], !sleepSamples.isEmpty else {
                    cont.resume(returning: nil)
                    return
                }
                
                let totalSeconds = sleepSamples.filter { $0.value == HKCategoryValueSleepAnalysis.asleep.rawValue }
                    .reduce(0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                
                let isRestful = totalSeconds > 7 * 3600 // Subjective pro metric: > 7h 
                cont.resume(returning: (Int(totalSeconds / 60), isRestful))
            }
            store.execute(query)
        }
    }
    #endif
}
