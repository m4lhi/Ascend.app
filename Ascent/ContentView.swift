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
            
            Color(red: 0.05, green: 0.05, blue: 0.08).ignoresSafeArea()
            
            TabView(selection: $selectedTab) {
                BasecampView().tag(0)
                ExploreView().tag(1)
                ArenaView().tag(2)
                TrophyRoomView().tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
            
            CustomTabBar(selectedTab: $selectedTab, showTracker: $showTracker)
        }
        // HIER WAR DER FEHLER: Der extra X-Button ist jetzt weg!
        // Er öffnet jetzt einfach nur noch sauber die LiveRecordView.
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
                .fill(Color(red: 0.1, green: 0.1, blue: 0.12).opacity(0.98))
                .clipShape(RoundedRectangle(cornerRadius: 40))
                .frame(height: 85)
                .shadow(color: .black.opacity(0.5), radius: 20, y: 10)
            
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
                let impactMed = UIImpactFeedbackGenerator(style: .heavy)
                impactMed.impactOccurred()
                showTracker = true
            }) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .background(.regularMaterial)
                        .environment(\.colorScheme, .light)
                        .clipShape(Circle())
                        .frame(width: 70, height: 70)
                        .shadow(color: .white.opacity(0.2), radius: 15, y: 0)
                    
                    Image(systemName: "play.fill")
                        .font(.system(size: 30, weight: .black))
                        .foregroundColor(.black)
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
                .font(.system(size: 26, weight: isSelected ? .bold : .regular))
                .foregroundColor(isSelected ? .white : .gray.opacity(0.5))
                .frame(maxWidth: .infinity)
        }
    }
}
