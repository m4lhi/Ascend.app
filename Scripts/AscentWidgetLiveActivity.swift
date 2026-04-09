import ActivityKit
import WidgetKit
import SwiftUI

// Make sure to add this file to your new Widget Extension Target!
// Also make sure MountaineeringAttributes is checked for both targets.

@main
struct AscentWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MountaineeringAttributes.self) { context in
            // Lock screen / Banner UI
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "mountain.2.fill")
                        .foregroundColor(.cyan)
                    Text(context.attributes.mountainName)
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    Text(context.state.isPaused ? "Paused" : "In Progress")
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(context.state.isPaused ? Color.orange : Color.green)
                        .cornerRadius(8)
                        .foregroundColor(.white)
                }
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("Distance")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Text(String(format: "%.2f km", context.state.distanceKm))
                            .font(.system(.title3, design: .rounded).bold())
                            .foregroundColor(.white)
                    }
                    Spacer()
                    VStack(alignment: .center) {
                        Text("Remaining")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Text(String(format: "%.2f km", context.state.remainingDistanceKm))
                            .font(.system(.title3, design: .rounded).bold())
                            .foregroundColor(.white)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("Avg Speed")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Text(String(format: "%.1f km/h", context.state.averageSpeedKmh))
                            .font(.system(.title3, design: .rounded).bold())
                            .foregroundColor(.white)
                    }
                }
            }
            .padding()
            .activityBackgroundTint(Color.black.opacity(0.8))
            .activitySystemActionForegroundColor(Color.cyan)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    HStack {
                        Image(systemName: "figure.walk")
                            .foregroundColor(.cyan)
                        Text(context.state.isPaused ? "Paused" : "Live")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(context.state.isPaused ? .orange : .green)
                    }
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    Text(formatDuration(context.state.duration))
                        .font(.system(.caption, design: .rounded).monospacedDigit())
                        .foregroundColor(.white)
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(alignment: .center, spacing: 20) {
                        VStack(alignment: .leading) {
                            Text("Dist")
                                .font(.caption2)
                                .foregroundColor(.gray)
                            Text(String(format: "%.1f km", context.state.distanceKm))
                                .font(.system(.headline, design: .rounded))
                                .foregroundColor(.white)
                        }
                        
                        VStack(alignment: .center) {
                            Text("Remaining")
                                .font(.caption2)
                                .foregroundColor(.gray)
                            Text(String(format: "%.1f km", context.state.remainingDistanceKm))
                                .font(.system(.headline, design: .rounded))
                                .foregroundColor(.white)
                        }
                        
                        VStack(alignment: .trailing) {
                            Text("Avg Spd")
                                .font(.caption2)
                                .foregroundColor(.gray)
                            Text(String(format: "%.1f km/h", context.state.averageSpeedKmh))
                                .font(.system(.headline, design: .rounded))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.top, 5)
                }
            } compactLeading: {
                Image(systemName: "mountain.2.fill")
                    .foregroundColor(.cyan)
            } compactTrailing: {
                Text(String(format: "%.1f km", context.state.distanceKm))
                    .font(.system(.caption2, design: .rounded).bold())
                    .foregroundColor(.cyan)
            } minimal: {
                Image(systemName: "mountain.2.fill")
                    .foregroundColor(.cyan)
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let h = Int(duration) / 3600
        let m = (Int(duration) % 3600) / 60
        let s = Int(duration) % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }
}
