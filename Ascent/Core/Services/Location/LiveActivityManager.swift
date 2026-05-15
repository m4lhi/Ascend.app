import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

@available(iOS 16.2, *)
class LiveActivityManager {
    static let shared = LiveActivityManager()
    
    private var activity: Activity<MountaineeringAttributes>?
    
    // Throttling properties
    private var lastUpdateTime: Date = Date.distantPast
    private var lastPausedState: Bool = false
    private var lastReportedDistance: Double = -100

    func startActivity(mountainName: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        
        // Reset throttling
        lastUpdateTime = Date()
        lastPausedState = false
        lastReportedDistance = 0

        let attributes = MountaineeringAttributes(mountainName: mountainName)
        let state = MountaineeringAttributes.ContentState(
            duration: 0,
            distanceKm: 0,
            remainingDistanceKm: 0,
            averageSpeedKmh: 0,
            isPaused: false
        )

        do {
            activity = try Activity.request(attributes: attributes, content: .init(state: state, staleDate: nil))
            print("LA: Started successfully")
        } catch {
            print("Failed to start Live Activity: \(error)")
        }
    }

    func updateActivity(duration: TimeInterval, distanceMeter: Double, remainingDistanceMeter: Double, speedMetersPerSecond: Double, isPaused: Bool) {
        guard let activity = activity else { return }

        let now = Date()
        let timeSinceLastUpdate = now.timeIntervalSince(lastUpdateTime)
        let stateChanged = (isPaused != lastPausedState)
        let distanceChanged = abs(distanceMeter - lastReportedDistance) > 100 // 100 meters
        
        // Throttling: ONLY update if state changed, or large distance gap, or every 30 seconds!
        // This prevents Apple from killing our Live Activity for spamming the APNS layer!
        if !stateChanged && !distanceChanged && timeSinceLastUpdate < 30 {
            return
        }
        
        lastUpdateTime = now
        lastPausedState = isPaused
        lastReportedDistance = distanceMeter

        let distanceKm = distanceMeter / 1000.0
        let remainingKm = remainingDistanceMeter / 1000.0
        let speedKmh = speedMetersPerSecond * 3.6

        let newState = MountaineeringAttributes.ContentState(
            duration: duration,
            distanceKm: distanceKm,
            remainingDistanceKm: remainingKm,
            averageSpeedKmh: speedKmh,
            isPaused: isPaused
        )

        Task {
            await activity.update(.init(state: newState, staleDate: nil))
        }
    }

    func endActivity() {
        guard let activity = activity else { return }
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        self.activity = nil
    }
}
