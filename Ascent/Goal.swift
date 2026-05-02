import Foundation
import CoreLocation

// User-defined target peak with optional deadline.
// Persisted in UserDefaults (lightweight; does not require Supabase round-trip).
struct Goal: Identifiable, Codable, Hashable {
    var id: UUID
    var mountainId: UUID?            // nil if free-form (no DB peak match)
    var mountainName: String
    var elevationM: Int
    var latitude: Double?
    var longitude: Double?
    var targetDate: Date?            // optional deadline
    var notes: String
    var readinessSnapshot: Int?      // % readiness at the time the goal was set
    var createdAt: Date

    init(id: UUID = UUID(), mountainId: UUID? = nil, mountainName: String,
         elevationM: Int, latitude: Double? = nil, longitude: Double? = nil,
         targetDate: Date? = nil, notes: String = "", readinessSnapshot: Int? = nil,
         createdAt: Date = Date()) {
        self.id = id
        self.mountainId = mountainId
        self.mountainName = mountainName
        self.elevationM = elevationM
        self.latitude = latitude
        self.longitude = longitude
        self.targetDate = targetDate
        self.notes = notes
        self.readinessSnapshot = readinessSnapshot
        self.createdAt = createdAt
    }

    init(from mountain: Mountain, targetDate: Date? = nil, notes: String = "", readinessSnapshot: Int? = nil) {
        self.id = UUID()
        self.mountainId = mountain.id
        self.mountainName = mountain.name
        self.elevationM = mountain.elevation
        self.latitude = mountain.latitude
        self.longitude = mountain.longitude
        self.targetDate = targetDate
        self.notes = notes
        self.readinessSnapshot = readinessSnapshot
        self.createdAt = Date()
    }

    var coordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    /// Days remaining until target date — nil if no deadline, negative if past.
    var daysUntilTarget: Int? {
        guard let date = targetDate else { return nil }
        return Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()),
                                                to: Calendar.current.startOfDay(for: date)).day
    }
}

// MARK: - Persistence helpers

enum GoalStore {
    private static let key = "ascent_goals_v1"

    static func load() -> [Goal] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let goals = try? JSONDecoder().decode([Goal].self, from: data) else { return [] }
        return goals
    }

    static func save(_ goals: [Goal]) {
        if let data = try? JSONEncoder().encode(goals) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

// MARK: - Smart selection helpers

extension Array where Element == Goal {
    /// Goal whose target date is closest in the future (preferred), or most-recently-created.
    var primary: Goal? {
        let upcoming = self.compactMap { goal -> (Goal, Int)? in
            guard let d = goal.daysUntilTarget, d >= 0 else { return nil }
            return (goal, d)
        }
        if let nextUp = upcoming.min(by: { $0.1 < $1.1 })?.0 { return nextUp }
        return self.sorted(by: { $0.createdAt > $1.createdAt }).first
    }

    /// Closest goal to the given location (great for "nearest peak you're targeting").
    func nearest(to coord: CLLocationCoordinate2D) -> Goal? {
        let here = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        return self
            .compactMap { goal -> (Goal, CLLocationDistance)? in
                guard let c = goal.coordinate else { return nil }
                let there = CLLocation(latitude: c.latitude, longitude: c.longitude)
                return (goal, there.distance(from: here))
            }
            .min(by: { $0.1 < $1.1 })?.0
    }
}
