import Foundation
import ActivityKit

public struct MountaineeringAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var duration: TimeInterval
        public var distanceKm: Double
        public var remainingDistanceKm: Double
        public var averageSpeedKmh: Double
        public var isPaused: Bool
    }
    
    public var mountainName: String
}
