import SwiftUI

// =========================================
// === DATEI: ContentView.swift ===
// === Steuert das Menü und die Tabs ===
// =========================================

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var showTracker = false

    init() {
        UITabBar.appearance().isHidden = true
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            
            Color(red: 0.95, green: 0.95, blue: 0.97).ignoresSafeArea()
            
            Group {
                switch selectedTab {
                case 0: BasecampView()
                case 1: ExploreView()
                case 2: ArenaView()
                case 3: TrophyRoomView()
                default: BasecampView()
                }
            }
            .transition(.opacity)

            CustomTabBar(selectedTab: $selectedTab, showTracker: $showTracker)
        }
        .preferredColorScheme(.light)
        .fullScreenCover(isPresented: $showTracker) {
            LiveRecordView(targetMountain: nil)
        }
    }
}

// === DIE SCHWEBENDE LEISTE MIT PLAY-BUTTON ===
struct CustomTabBar: View {
    @Binding var selectedTab: Int
    @Binding var showTracker: Bool
    
    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 40)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .light)
                .clipShape(RoundedRectangle(cornerRadius: 40))
                .frame(height: 85)
                .shadow(color: .black.opacity(0.1), radius: 25, y: 15)
            
            HStack(spacing: 0) {
                TabBarIcon(icon: "house.fill", isSelected: selectedTab == 0) { selectedTab = 0 }
                TabBarIcon(icon: "map.fill", isSelected: selectedTab == 1) { selectedTab = 1 }
                Spacer().frame(width: 80)
                TabBarIcon(icon: "chart.bar.fill", isSelected: selectedTab == 2) { selectedTab = 2 }
                TabBarIcon(icon: "person.fill", isSelected: selectedTab == 3) { selectedTab = 3 }
            }
            .padding(.horizontal, 20)
            .padding(.top, 25)
            
            Button(action: {
                HapticManager.shared.heavy()
                showTracker = true
            }) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.1, green: 0.5, blue: 0.95))
                        .clipShape(Circle())
                        .frame(width: 70, height: 70)
                        .shadow(color: Color(red: 0.1, green: 0.5, blue: 0.95).opacity(0.4), radius: 15, y: 4)
                    
                    Image(systemName: "figure.walk")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .offset(x: 2)
                }
            }
            .offset(y: -25)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
    }
}

struct TabBarIcon: View {
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 26, weight: isSelected ? .bold : .regular, design: .rounded))
                .foregroundColor(isSelected ? Color(red: 0.1, green: 0.5, blue: 0.95) : .gray.opacity(0.6))
                .frame(maxWidth: .infinity)
        }
    }
}
