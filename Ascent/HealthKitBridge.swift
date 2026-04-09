import Foundation
#if canImport(HealthKit)
import HealthKit
#endif

// =========================================
// === DATEI: HealthKitBridge.swift ===
// === Read-only HealthKit prefill for Coaching ===
// =========================================
//
// Reads height (cm), weight (kg), VO2max and weekly active minutes.
// Gracefully no-ops if HealthKit is unavailable or permissions denied.
//
// IMPORTANT SETUP (one-time, in Xcode):
//  1. Target → Signing & Capabilities → + Capability → HealthKit
//  2. Info.plist → add key `NSHealthShareUsageDescription`
//     value: "Ascent uses your health data to personalize your mountaineering plan."
//
// Without these, authorization will silently fail and defaults stay.

struct HealthKitProfile {
    var heightCm: Int?
    var weightKg: Int?
    var vo2max: Int?
    var weeklyActiveHours: Int?
}

@MainActor
final class HealthKitBridge {
    static let shared = HealthKitBridge()

    #if canImport(HealthKit)
    private let store = HKHealthStore()
    #endif

    func fetchProfile() async -> HealthKitProfile {
        var result = HealthKitProfile()

        #if canImport(HealthKit)
        guard HKHealthStore.isHealthDataAvailable() else { return result }

        let height = HKObjectType.quantityType(forIdentifier: .height)!
        let weight = HKObjectType.quantityType(forIdentifier: .bodyMass)!
        let vo2    = HKObjectType.quantityType(forIdentifier: .vo2Max)!
        let energy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!

        let readSet: Set<HKObjectType> = [height, weight, vo2, energy]

        do {
            try await store.requestAuthorization(toShare: [], read: readSet)
        } catch {
            return result
        }

        result.heightCm = await Self.latestQuantity(store: store, type: height, unit: .meterUnit(with: .centi)).map { Int($0.rounded()) }
        result.weightKg = await Self.latestQuantity(store: store, type: weight, unit: .gramUnit(with: .kilo)).map { Int($0.rounded()) }
        result.vo2max   = await Self.latestQuantity(store: store, type: vo2, unit: HKUnit(from: "ml/kg*min")).map { Int($0.rounded()) }

        // Weekly active energy → rough active hour estimate: 500 kcal ≈ 1 h moderate
        if let kcal = await Self.weeklySum(store: store, type: energy, unit: .kilocalorie()) {
            result.weeklyActiveHours = Int((kcal / 500.0).rounded())
        }
        #endif

        return result
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

    private static func weeklySum(store: HKHealthStore, type: HKQuantityType, unit: HKUnit) async -> Double? {
        await withCheckedContinuation { cont in
            let start = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, _ in
                if let sum = stats?.sumQuantity() {
                    cont.resume(returning: sum.doubleValue(for: unit))
                } else {
                    cont.resume(returning: nil)
                }
            }
            store.execute(query)
        }
    }
    #endif
}
