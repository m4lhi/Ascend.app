import SwiftUI

// =========================================
// === DATEI: ActivityCardView.swift ===
// === Mit Lösch-Menü für eigene Touren ===
// =========================================

struct ActivityCardView: View {
    // === NEU: Die Karte muss mit dem Gehirn sprechen können ===
    @EnvironmentObject var appState: AppState
    
    let tour: Tour
    
    var formattedDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: tour.durationSeconds) ?? "0m"
    }
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.string(for: tour.date)?.uppercased() ?? "JUST NOW"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            
            // === TOP ROW: Avatar, Name, Zeit & Lösch-Button ===
            HStack(alignment: .top, spacing: 12) {
                if let urlString = tour.playerAvatarURL, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.3))
                        }
                    }
                    .frame(width: 45, height: 45)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(gradient: Gradient(colors: [Color.pink.opacity(0.3), Color.blue.opacity(0.3)]), startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 45, height: 45)
                        .overlay(Text(String(tour.playerName.prefix(1))).fontWeight(.bold).foregroundColor(.white))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(tour.playerName).font(.headline).foregroundColor(.white)
                        if !tour.isCurrentUser {
                            Text("@\(tour.playerHandle)").font(.caption).foregroundColor(.gray)
                        }
                    }
                    Text(timeAgo).font(.caption2).foregroundColor(.gray).fontWeight(.bold)
                }
                Spacer()
                
                // === NEU: Der Lösch-Button (Nur bei DEINEN eigenen Touren) ===
                if tour.isCurrentUser {
                    Menu {
                        // Roter Destructive-Button zum Löschen
                        Button(role: .destructive, action: {
                            appState.deleteTour(tour: tour)
                        }) {
                            Label("Delete Mission", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.title3)
                            .foregroundColor(.gray)
                            .padding(8) // Macht die Hitbox für den Finger größer
                            .contentShape(Rectangle())
                    }
                }
            }
            
            // === MIDDLE: Kommentar ===
            (Text("Conquered ")
                .foregroundColor(.gray)
             + Text(tour.summitName)
                .fontWeight(.bold)
                .foregroundColor(.white)
             + Text(". ")
                .foregroundColor(.gray)
             + Text(tour.storyComment)
                .foregroundColor(.gray)
            )
            .font(.subheadline)
            .lineSpacing(4)
            
            // === BOTTOM: Statistik ===
            HStack(spacing: 10) {
                StatBlock(icon: "chart.bar.fill", value: "+\(tour.elevationGainMeters)m", isXP: false)
                StatBlock(icon: "clock.fill", value: formattedDuration, isXP: false)
                if tour.pauseCount > 0 {
                    StatBlock(icon: "pause.circle.fill", value: "\(tour.pauseCount) pauses", isXP: false)
                }
                StatBlock(icon: "", value: "+\(tour.xpGained) XP", isXP: true)
            }
        }
        .padding(20)
        .background(Color(white: 0.15))
        .cornerRadius(20)
    }
}

// === Hilfs-View für die Statistik-Kästchen ===
struct StatBlock: View {
    let icon: String
    let value: String
    let isXP: Bool
    
    var body: some View {
        HStack(spacing: 6) {
            if !icon.isEmpty {
                Image(systemName: icon).font(.system(size: 10)).foregroundColor(isXP ? .blue : .gray)
            }
            Text(value).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(isXP ? Color(red: 0.5, green: 0.7, blue: 1.0) : .white)
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(isXP ? Color.blue.opacity(0.15) : Color(white: 0.2))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(isXP ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1))
    }
}
