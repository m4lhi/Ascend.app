import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 0
    @State private var prevTab = 0
    @State private var showAIChat = false
    @State private var showCoachingGateway = false

    var body: some View {
        Group {
            if #available(iOS 26, *) {
                nativeTabLayout
            } else {
                customTabLayout
            }
        }
        .preferredColorScheme(.light)
        .fullScreenCover(isPresented: $showAIChat) { AIChatGuideView() }
        .fullScreenCover(isPresented: $showCoachingGateway) {
            AICoachingGatewayView().environmentObject(appState)
        }
        .onChange(of: appState.pendingTab) { _, newTab in
            guard let t = newTab else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) { selectedTab = t }
            appState.pendingTab = nil
        }
        .onChange(of: appState.exploreSelectedMountain) { _, newMountain in
            if newMountain != nil { selectedTab = 1 }
        }
        .sheet(isPresented: $showAIChat) { AIChatGuideView() }
    }

    // MARK: - iOS 26+ native Liquid Glass tab bar

    @available(iOS 26, *)
    private var nativeTabLayout: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                Tab("Basecamp", systemImage: "house.fill",    value: 0) { BasecampView()   }
                Tab("Explore",  systemImage: "map.fill",      value: 1) { ExploreView()    }
                Tab(value: -1) {
                    Color.clear.ignoresSafeArea()
                } label: {
                    // Visually distinct: filled circle icon + accent tint
                    Label {
                        Text("Record")
                    } icon: {
                        Image(systemName: "figure.walk.circle.fill")
                            .foregroundStyle(DesignSystem.Colors.accent)
                            .symbolRenderingMode(.hierarchical)
                    }
                }
                Tab("Profile",  systemImage: "person.fill",    value: 3) { TrophyRoomView() }
            }
            .tint(DesignSystem.Colors.accent)
            .onChange(of: selectedTab) { _, newVal in
                guard newVal == -1 else { prevTab = newVal; return }
                HapticManager.shared.heavy()
                if appState.isTrackerActive {
                    // Tracker already running (minimized) — just maximize it
                    appState.isTrackerMinimized = false
                    withAnimation(.none) { selectedTab = prevTab }
                } else {
                    // Start new tracker session; selectedTab stays at -1
                    // until minimized or closed (see onChanges below)
                    appState.isTrackerActive = true
                }
            }
            .onChange(of: appState.isTrackerMinimized) { _, isMinimized in
                // When minimized, show the real tab content underneath
                if isMinimized { withAnimation(.none) { selectedTab = prevTab } }
            }
            .onChange(of: appState.isTrackerActive) { _, isActive in
                if !isActive {
                    withAnimation(.none) { selectedTab = prevTab }
                }
            }

            if appState.isTrackerActive {
                GeometryReader { geo in
                    LiveRecordView(targetMountain: appState.activeMountain)
                        .environmentObject(appState)
                        .offset(y: appState.isTrackerMinimized ? geo.size.height + 200 : 0)
                        .opacity(appState.isTrackerMinimized ? 0 : 1)
                        .allowsHitTesting(!appState.isTrackerMinimized)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: appState.isTrackerMinimized)
                }
                .zIndex(100)
            }

            // Mini Player — fixe Nike-Run-style Bottom-Bar über der Tab Bar
            if appState.isTrackerActive && appState.isTrackerMinimized {
                // Pass-through container so only the MiniTrackerPlayer button receives taps,
                // and the area above (where map/tab content lives) keeps working.
                VStack(spacing: 0) {
                    Spacer()
                        .allowsHitTesting(false)
                    MiniTrackerPlayer()
                        .environmentObject(appState)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 56) // Platz für Tab Bar
                }
                .ignoresSafeArea(.keyboard)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(90)
            }
        }
    }

    // MARK: - iOS < 26 custom tab bar fallback

    private var customTabLayout: some View {
        ZStack(alignment: .bottom) {

            LinearGradient(
                colors: [
                    Color(red: 0.94, green: 0.97, blue: 1.00),
                    Color(red: 0.88, green: 0.93, blue: 1.00),
                    Color(red: 0.85, green: 0.90, blue: 0.98)
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ).ignoresSafeArea()

            Group {
                switch selectedTab {
                case 0: BasecampView()
                case 1: ExploreView()
                case 3: TrophyRoomView()
                default: BasecampView()
                }
            }
            .transition(.opacity)

            if !appState.isTrackerActive || appState.isTrackerMinimized {
                CustomTabBar(selectedTab: $selectedTab, showTracker: $appState.isTrackerActive)
            }

            if appState.isTrackerActive {
                GeometryReader { geo in
                    LiveRecordView(targetMountain: appState.activeMountain)
                        .environmentObject(appState)
                        .offset(y: appState.isTrackerMinimized ? geo.size.height + 200 : 0)
                        .opacity(appState.isTrackerMinimized ? 0 : 1)
                        .allowsHitTesting(!appState.isTrackerMinimized)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: appState.isTrackerMinimized)
                }
                .zIndex(100)
            }

            if appState.isTrackerActive && appState.isTrackerMinimized {
                VStack {
                    Spacer()
                        .allowsHitTesting(false)
                    MiniTrackerPlayer().environmentObject(appState)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 110)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(90)
            }
        }
    }
}


// MARK: - Custom Tab Bar (iOS < 26 fallback)

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    @Binding var showTracker: Bool
    @State private var dragX: CGFloat? = nil
    @State private var isDragging = false

    // 3 tabs (Basecamp, Explore, Profile) split around the central record button.
    // Layout: [0] [1]  [center 80pt record]  [3]
    private func tabWidth(in bw: CGFloat) -> CGFloat { (bw - 120) / 3 }

    private func tabCenter(for tab: Int, in bw: CGFloat) -> CGFloat {
        let w = tabWidth(in: bw)
        switch tab {
        case 0: return 20 + w * 0.5
        case 1: return 20 + w * 1.5
        case 3: return 20 + w * 2.5 + 80
        default: return 20 + w * 0.5
        }
    }

    private func nearestTab(for x: CGFloat, in bw: CGFloat) -> Int {
        let candidates = [0, 1, 3]
        return candidates.min(by: { abs(tabCenter(for: $0, in: bw) - x) < abs(tabCenter(for: $1, in: bw) - x) }) ?? 0
    }

    var body: some View {
        GeometryReader { geo in
            let bw = geo.size.width
            let tw = tabWidth(in: bw)
            let pillX = dragX ?? tabCenter(for: selectedTab, in: bw)

            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 40)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .light)
                    .frame(height: 85)
                    .overlay(RoundedRectangle(cornerRadius: 40).stroke(.white.opacity(0.5), lineWidth: 0.8))
                    .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 6)
                    .zIndex(0)

                HStack(spacing: 0) {
                    tabButton("house.fill", 0)
                    tabButton("map.fill", 1)
                    Spacer().frame(width: 80)
                    tabButton("person.fill", 3)
                }
                .padding(.horizontal, 20)
                .padding(.top, 25)
                .zIndex(1)

                Capsule()
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .light)
                    .overlay(Capsule().stroke(.white.opacity(0.85), lineWidth: 1))
                    .frame(width: tw - 4, height: 50)
                    .scaleEffect(isDragging ? 1.08 : 1.0)
                    .shadow(color: .black.opacity(isDragging ? 0.18 : 0.1), radius: isDragging ? 20 : 10, x: 0, y: isDragging ? 8 : 3)
                    .offset(x: pillX - bw / 2, y: 17)
                    .allowsHitTesting(false)
                    .animation(.spring(response: 0.28, dampingFraction: 0.65), value: isDragging)
                    .animation(
                        isDragging ? .interactiveSpring(response: 0.1, dampingFraction: 0.9) : .spring(response: 0.35, dampingFraction: 0.72),
                        value: pillX
                    )
                    .zIndex(2)

                Button(action: { HapticManager.shared.heavy(); showTracker = true }) {
                    ZStack {
                        Circle()
                            .fill(DesignSystem.Colors.accent)
                            .frame(width: 70, height: 70)
                            .shadow(color: DesignSystem.Colors.accent.opacity(0.4), radius: 15, y: 4)
                        Image(systemName: "figure.walk")
                            .font(.app(size: 28, weight: .black))
                            .foregroundColor(.white)
                            .offset(x: 2)
                    }
                }
                .offset(y: -25)
                .zIndex(10)
            }
            .frame(height: 85, alignment: .top)
            .contentShape(Rectangle().size(width: bw, height: 85))
            .simultaneousGesture(
                DragGesture(minimumDistance: 6)
                    .onChanged { value in
                        if !isDragging { isDragging = true }
                        dragX = max(tabCenter(for: 0, in: bw), min(tabCenter(for: 3, in: bw), value.location.x))
                    }
                    .onEnded { value in
                        isDragging = false
                        let nearest = nearestTab(for: value.location.x, in: bw)
                        if nearest != selectedTab { HapticManager.shared.light() }
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) { selectedTab = nearest; dragX = nil }
                    }
            )
        }
        .frame(height: 85)
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
    }

    @ViewBuilder
    private func tabButton(_ icon: String, _ tag: Int) -> some View {
        Button(action: {
            HapticManager.shared.light()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) { selectedTab = tag }
        }) {
            Image(systemName: icon)
                .font(.app(size: 22, weight: selectedTab == tag ? .bold : .regular))
                .foregroundColor(selectedTab == tag ? DesignSystem.Colors.accent : .gray.opacity(0.7))
                .scaleEffect(selectedTab == tag ? 1.06 : 1.0)
                .symbolEffect(.bounce, value: selectedTab == tag)
                .frame(maxWidth: .infinity)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedTab == tag)
        }
        .buttonStyle(PressableButtonStyle())
    }
}
