import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

class LiveActivityManager {
    static let shared = LiveActivityManager()

    #if canImport(ActivityKit)
    @available(iOS 16.2, *)
    private var currentActivity: Activity<MountaineeringAttributes>?

    @available(iOS 16.2, *)
    func startActivity(mountainName: String) {
        // Ensure we only have one running
        endActivity()

        let attributes = MountaineeringAttributes(mountainName: mountainName)
        let contentState = MountaineeringAttributes.ContentState(
            duration: 0,
            distanceKm: 0,
            remainingDistanceKm: 0,
            averageSpeedKmh: 0,
            isPaused: false
        )

        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: .init(state: contentState, staleDate: nil),
                pushType: nil
            )
            print("Live Activity started successfully")
        } catch {
            print("Failed to start Live Activity: \(error.localizedDescription)")
        }
    }

    @available(iOS 16.2, *)
    func updateActivity(duration: Double, distanceMeter: Double, remainingDistanceMeter: Double, speedMetersPerSecond: Double, isPaused: Bool) {
        Task {
            let distanceKm = distanceMeter / 1000.0
            let remainingKm = remainingDistanceMeter / 1000.0
            let speedKmh = speedMetersPerSecond * 3.6
            
            let updatedState = MountaineeringAttributes.ContentState(
                duration: duration,
                distanceKm: distanceKm,
                remainingDistanceKm: remainingKm,
                averageSpeedKmh: speedKmh,
                isPaused: isPaused
            )

            await currentActivity?.update(
                ActivityContent<MountaineeringAttributes.ContentState>(
                    state: updatedState,
                    staleDate: nil
                )
            )
        }
    }

    @available(iOS 16.2, *)
    func endActivity() {
        Task {
            // Dismiss immediately
            if let activity = currentActivity {
                await activity.end(nil, dismissalPolicy: .immediate)
                currentActivity = nil
            }
            
            // Also clean up any rogue activities
            for activity in Activity<MountaineeringAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
    #endif
}
