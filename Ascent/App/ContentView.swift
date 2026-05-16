import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 0
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
        // .preferredColorScheme(.dark) removed — design system has light + dark; let system pick.
        .fullScreenCover(isPresented: $showAIChat) { AIChatGuideView() }
        .fullScreenCover(isPresented: $showCoachingGateway) {
            AICoachingGatewayView().environmentObject(appState)
        }
        .onChange(of: appState.pendingTab) { _, newTab in
            guard let t = newTab else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) { selectedTab = t }
            appState.pendingTab = nil
        }
        .sheet(isPresented: $showAIChat) { AIChatGuideView() }
    }

    // MARK: - iOS 26+ native tab bar

    @available(iOS 26, *)
    private var nativeTabLayout: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                Tab("Basecamp", systemImage: "house.fill", value: 0) {
                    HealthDashboardView()
                }
                Tab("Fortschritt", systemImage: "chart.bar.fill", value: 1) {
                    TrainingAnalyticsView()
                }
                Tab("Explore", systemImage: "map.fill", value: 2) {
                    ExploreView()
                }
            }
            .tint(DesignSystem.Colors.accent)

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
                VStack(spacing: 0) {
                    Spacer()
                        .allowsHitTesting(false)
                    MiniTrackerPlayer()
                        .environmentObject(appState)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 56)
                }
                .ignoresSafeArea(.keyboard)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(90)
            }
        }
    }

    // MARK: - iOS < 26 custom tab bar

    private var customTabLayout: some View {
        ZStack(alignment: .bottom) {

            DesignSystem.Colors.background.ignoresSafeArea()

            Group {
                switch selectedTab {
                case 0: HealthDashboardView()
                case 1: TrainingAnalyticsView()
                case 2: ExploreView()
                default: HealthDashboardView()
                }
            }
            .transition(.opacity)

            if !appState.isTrackerActive || appState.isTrackerMinimized {
                CustomTabBar(selectedTab: $selectedTab)
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


// MARK: - Custom Tab Bar (3 tabs, no center record button)

struct CustomTabBar: View {
    @Binding var selectedTab: Int

    private let tabs: [(icon: String, label: String, tag: Int)] = [
        ("house.fill", "Basecamp", 0),
        ("chart.bar.fill", "Fortschritt", 1),
        ("map.fill", "Explore", 2),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.tag) { tab in
                tabButton(tab)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 10)
        .padding(.bottom, 24)
        .background(
            Rectangle()
                .fill(DesignSystem.Colors.surface)
                .overlay(
                    Rectangle()
                        .fill(Color.white.opacity(0.05))
                        .frame(height: 0.5),
                    alignment: .top
                )
                .ignoresSafeArea(.all, edges: .bottom)
        )
    }

    private func tabButton(_ tab: (icon: String, label: String, tag: Int)) -> some View {
        let isActive = selectedTab == tab.tag
        return Button {
            HapticManager.shared.light()
            withAnimation(DesignSystem.Animations.quick) { selectedTab = tab.tag }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 20, weight: isActive ? .semibold : .regular))
                    .foregroundColor(isActive ? DesignSystem.Colors.accent : DesignSystem.Colors.tertiaryText)
                Text(tab.label)
                    .font(.appMono(size: 9, weight: .bold))
                    .foregroundColor(isActive ? DesignSystem.Colors.accent : DesignSystem.Colors.tertiaryText)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}
