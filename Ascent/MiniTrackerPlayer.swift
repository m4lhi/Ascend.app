import SwiftUI

struct MiniTrackerPlayer: View {
    @EnvironmentObject var appState: AppState
    
    private var timeString: String {
        let h = appState.trackerElapsedSeconds / 3600
        let m = (appState.trackerElapsedSeconds % 3600) / 60
        let s = appState.trackerElapsedSeconds % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }
    
    var body: some View {
        Button {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                appState.isTrackerMinimized = false
            }
        } label: {
            HStack(spacing: 12) {
                // Status Indicator
                Circle()
                    .fill(appState.isTrackerPaused ? Color.orange : Color(red: 0.1, green: 0.5, blue: 0.95))
                    .frame(width: 10, height: 10)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(appState.activeMountain?.name ?? "Ascent Mission")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        Text(timeString)
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundColor(appState.isTrackerPaused ? .orange : Color(red: 0.1, green: 0.5, blue: 0.95))
                        
                        Text("•")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                        
                        Text(String(format: "%.1f km", appState.trackerDistanceKm))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.gray)

                        Text("•")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)

                        Text("\(Int(appState.trackerElevationGain)) Hm")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                // Expand Icon
                Image(systemName: "chevron.up")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.gray.opacity(0.8))
                    .padding(8)
                    .background(Color.black.opacity(0.04), in: Circle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.black.opacity(0.05), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.12), radius: 25, y: 15)
        }
        .buttonStyle(.plain)
    }
}
