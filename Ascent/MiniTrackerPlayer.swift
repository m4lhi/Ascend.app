import SwiftUI

// Full-width Nike-Run-style live activity bar shown at the bottom of the screen
// while a workout/tour is active. Tap to expand the full tracker.
struct MiniTrackerPlayer: View {
    @EnvironmentObject var appState: AppState

    @State private var pulse = false

    private var timeString: String {
        let h = appState.trackerElapsedSeconds / 3600
        let m = (appState.trackerElapsedSeconds % 3600) / 60
        let s = appState.trackerElapsedSeconds % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }

    private var distanceString: String {
        String(format: "%.2f", appState.trackerDistanceKm)
    }

    private var elevationString: String {
        "\(Int(appState.trackerElevationGain))"
    }

    private var heartRateString: String? {
        guard let bpm = appState.trackerHeartRateBpm else { return nil }
        return "\(bpm)"
    }

    private var statusColor: Color {
        appState.isTrackerPaused ? .orange : DesignSystem.Colors.accent
    }

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                appState.isTrackerMinimized = false
            }
        } label: {
            VStack(spacing: 0) {
                // Top row: status + mountain name + chevron
                HStack(spacing: 8) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                        .scaleEffect(appState.isTrackerPaused ? 1.0 : (pulse ? 1.3 : 1.0))
                        .opacity(appState.isTrackerPaused ? 1.0 : (pulse ? 1.0 : 0.5))
                        .animation(
                            appState.isTrackerPaused
                                ? .default
                                : .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                            value: pulse
                        )
                        .onAppear { pulse = true }

                    Text((appState.activeMountain?.name ?? "Live Tracking").uppercased())
                        .font(.app(size: 11, weight: .heavy))
                        .tracking(0.8)
                        .foregroundColor(statusColor)
                        .lineLimit(1)

                    Spacer()

                    if appState.isTrackerPaused {
                        Text("PAUSED")
                            .font(.app(size: 10, weight: .heavy))
                            .tracking(0.6)
                            .foregroundColor(.orange)
                    }

                    Image(systemName: "chevron.up")
                        .font(.app(size: 12, weight: .bold))
                        .foregroundColor(.gray.opacity(0.7))
                }

                // Metrics row
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    metric(
                        value: timeString,
                        label: "TIME",
                        valueColor: statusColor
                    )
                    divider()
                    metric(
                        value: distanceString,
                        unit: "KM",
                        label: "DIST"
                    )
                    divider()
                    metric(
                        value: elevationString,
                        unit: "M",
                        label: "ELEV"
                    )
                    if let hr = heartRateString {
                        divider()
                        metric(
                            value: hr,
                            unit: "BPM",
                            label: "HEART",
                            icon: "heart.fill",
                            valueColor: .red
                        )
                    }
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(DesignSystem.Colors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.black.opacity(0.06), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func metric(
        value: String,
        unit: String? = nil,
        label: String,
        icon: String? = nil,
        valueColor: Color = .primary
    ) -> some View {
        VStack(spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                if let icon {
                    Image(systemName: icon)
                        .font(.app(size: 12, weight: .bold))
                        .foregroundColor(valueColor)
                }
                Text(value)
                    .font(.app(size: 22, weight: .heavy))
                    .foregroundColor(valueColor)
                    .monospacedDigit()
                if let unit {
                    Text(unit)
                        .font(.app(size: 10, weight: .heavy))
                        .foregroundColor(.gray)
                        .padding(.leading, 1)
                }
            }
            Text(label)
                .font(.app(size: 9, weight: .heavy))
                .tracking(0.8)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }

    private func divider() -> some View {
        Rectangle()
            .fill(Color.gray.opacity(0.18))
            .frame(width: 1, height: 28)
    }
}
