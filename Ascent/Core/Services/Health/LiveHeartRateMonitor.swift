import Foundation
import Combine
#if canImport(HealthKit)
import HealthKit
#endif

// Streams live heart rate from HealthKit while a workout is active.
// HealthKit aggregates samples written by Apple Watch automatically,
// so this works for any user wearing a paired Watch — no Watch app needed.
@MainActor
final class LiveHeartRateMonitor: ObservableObject {
    static let shared = LiveHeartRateMonitor()

    @Published private(set) var currentBpm: Int? = nil
    @Published private(set) var sourceName: String? = nil
    @Published private(set) var lastSampleAt: Date? = nil

    #if canImport(HealthKit)
    private let store = HKHealthStore()
    private var query: HKAnchoredObjectQuery?
    private var anchor: HKQueryAnchor?
    #endif

    private init() {}

    func start() {
        #if canImport(HealthKit)
        guard HKHealthStore.isHealthDataAvailable() else { return }
        guard let hrType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }

        Task {
            do {
                try await store.requestAuthorization(toShare: [], read: [hrType])
            } catch {
                return
            }
            await MainActor.run { self.beginQuery(type: hrType) }
        }
        #endif
    }

    func stop() {
        #if canImport(HealthKit)
        if let q = query {
            store.stop(q)
            query = nil
        }
        anchor = nil
        currentBpm = nil
        sourceName = nil
        lastSampleAt = nil
        #endif
    }

    #if canImport(HealthKit)
    private func beginQuery(type: HKQuantityType) {
        // Only consider samples from the last few minutes so we don't show stale values
        let predicate = HKQuery.predicateForSamples(
            withStart: Date().addingTimeInterval(-300),
            end: nil,
            options: .strictStartDate
        )

        let q = HKAnchoredObjectQuery(
            type: type,
            predicate: predicate,
            anchor: anchor,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, newAnchor, _ in
            self?.handle(samples: samples, anchor: newAnchor)
        }

        q.updateHandler = { [weak self] _, samples, _, newAnchor, _ in
            self?.handle(samples: samples, anchor: newAnchor)
        }

        store.execute(q)
        query = q
    }

    private nonisolated func handle(samples: [HKSample]?, anchor newAnchor: HKQueryAnchor?) {
        guard let qSamples = samples as? [HKQuantitySample], !qSamples.isEmpty else { return }
        // Use the most recent sample
        let latest = qSamples.max(by: { $0.endDate < $1.endDate })!
        let unit = HKUnit.count().unitDivided(by: .minute())
        let bpm = Int(latest.quantity.doubleValue(for: unit).rounded())
        let src = latest.sourceRevision.source.name

        Task { @MainActor in
            self.currentBpm = bpm
            self.sourceName = src
            self.lastSampleAt = latest.endDate
            self.anchor = newAnchor
        }
    }
    #endif
}
