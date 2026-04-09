import SwiftUI

struct MiniTrackerPlayer: View {
    @EnvironmentObject var appState: AppState
    
    // Kleiner pulsierender Effekt wenn aktiv
    @State private var blinkToggle = false
    
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
            HStack(spacing: 10) {
                // Status Indicator
                Circle()
                    .fill(appState.isTrackerPaused ? Color.orange : Color(red: 0.1, green: 0.5, blue: 0.95))
                    .frame(width: 8, height: 8)
                    .opacity(appState.isTrackerPaused ? 1 : (blinkToggle ? 1 : 0.4))
                    .animation(appState.isTrackerPaused ? .default : .easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: blinkToggle)
                    .onAppear { blinkToggle = true }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(appState.activeMountain?.name ?? "Ascent")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        Text(timeString)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(appState.isTrackerPaused ? .orange : Color(red: 0.1, green: 0.5, blue: 0.95))
                        
                        Text("•")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                        
                        Text(String(format: "%.1f km", appState.trackerDistanceKm))
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                }
                
                // Expand Icon (sehr dezent jetzt)
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.gray.opacity(0.6))
                    .padding(.leading, 4)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.black.opacity(0.06), lineWidth: 1)
                    )
            )
            // Kleinerer Schatten, weil das Element kompakter ist
            .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
    }
}
