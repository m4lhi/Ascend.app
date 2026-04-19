import SwiftUI

// =========================================
// === DATEI: ContentView.swift ===
// === Steuert das Menü und die Tabs ===
// =========================================


// MARK: - Content View

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 0
    @State private var showAIChat = false
    @State private var showCoachingGateway = false

    init() {
        UITabBar.appearance().isHidden = true
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            
            LinearGradient(
                colors: [
                    Color(red: 0.96, green: 0.98, blue: 1.00),
                    Color(red: 0.90, green: 0.94, blue: 1.00)
                ],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()
            
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
            
            // Custom Tab Bar overlay
            if !appState.isTrackerActive || appState.isTrackerMinimized {
                CustomTabBar(selectedTab: $selectedTab, showTracker: $appState.isTrackerActive)
                
                // AI Coach is accessible from dashboard widget — no floating button needed
            }

            // --- Live Tracker Overlay (Full Screen & Mini Player) ---
            if appState.isTrackerActive {
                GeometryReader { geo in
                    LiveRecordView(targetMountain: appState.activeMountain)
                        .environmentObject(appState)
                        // Push the view completely off-screen if minimized (add safe padding)
                        .offset(y: appState.isTrackerMinimized ? geo.size.height + 200 : 0)
                        .opacity(appState.isTrackerMinimized ? 0 : 1)
                        .allowsHitTesting(!appState.isTrackerMinimized)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: appState.isTrackerMinimized)
                }
                .zIndex(100)
            }
            
            // --- Mini Player Banner ---
            if appState.isTrackerActive && appState.isTrackerMinimized {
                HStack {
                    MiniTrackerPlayer()
                        .environmentObject(appState)
                    Spacer()
                }
                // Height of CustomTabBar is ~105 padding included, place it right above
                .padding(.bottom, 115) 
                .padding(.horizontal, 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(90)
            }

        }
        .preferredColorScheme(.light)
        
        .fullScreenCover(isPresented: $showAIChat) {
            AIChatGuideView()
        }
        .fullScreenCover(isPresented: $showCoachingGateway) {
            AICoachingGatewayView()
                .environmentObject(appState)
        }
        .onChange(of: selectedTab) { _, _ in
            // Reset FAB when switching tabs
            withAnimation(.easeOut(duration: 0.2)) {
                appState.isFABVisible = true
            }
        }
        .onChange(of: appState.pendingTab) { _, newTab in
            guard let t = newTab else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                selectedTab = t
            }
            appState.pendingTab = nil
        }
        .onChange(of: appState.exploreSelectedMountain) { _, newMountain in
            if newMountain != nil {
                showAIChat = false
                showCoachingGateway = false
                selectedTab = 1
            }
        }
        .sheet(isPresented: $showAIChat) {
            AIChatGuideView()
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
                TabBarIcon(icon: "house.fill", isSelected: selectedTab == 0) { withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) { selectedTab = 0 } }
                TabBarIcon(icon: "map.fill", isSelected: selectedTab == 1) { withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) { selectedTab = 1 } }
                Spacer().frame(width: 80)
                TabBarIcon(icon: "chart.bar.fill", isSelected: selectedTab == 2) { withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) { selectedTab = 2 } }
                TabBarIcon(icon: "person.fill", isSelected: selectedTab == 3) { withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) { selectedTab = 3 } }
            }
            .padding(.horizontal, 20)
            .padding(.top, 25)
            
            Button(action: {
                HapticManager.shared.heavy()
                showTracker = true
            }) {
                ZStack {
                    Circle()
                        .fill(DesignSystem.Colors.accent)
                        .clipShape(Circle())
                        .frame(width: 70, height: 70)
                        .shadow(color: DesignSystem.Colors.accent.opacity(0.4), radius: 15, y: 4)
                    
                    Image(systemName: "figure.walk")
                        .font(.app(size: 28, weight: .black))
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
        Button(action: {
            HapticManager.shared.light()
            action()
        }) {
            ZStack {
                if isSelected {
                    Circle()
                        .fill(DesignSystem.Colors.accent.opacity(0.14))
                        .frame(width: 44, height: 44)
                        .transition(.scale.combined(with: .opacity))
                }
                Image(systemName: icon)
                    .font(.app(size: 24, weight: isSelected ? .bold : .regular))
                    .foregroundColor(isSelected ? DesignSystem.Colors.accent : .gray.opacity(0.55))
                    .scaleEffect(isSelected ? 1.08 : 1.0)
                    .symbolEffect(.bounce, value: isSelected)
            }
            .frame(maxWidth: .infinity)
            .animation(.spring(response: 0.38, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(PressableButtonStyle())
    }
}
