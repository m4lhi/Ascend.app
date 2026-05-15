import SwiftUI
import Combine
import Supabase
import UserNotifications
import CoreLocation

// =========================================
// === DATEI: Settings.swift ===
// === Redesigned Settings — Full Featured ===
// =========================================

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState

    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("isLoggedIn") private var isLoggedIn = true

    @ObservedObject private var emergencyManager = EmergencyManager.shared
    @ObservedObject private var offlineManager = OfflineManager.shared

    @State private var showEditProfile = false
    @State private var showLogoutConfirm = false
    @State private var showDeleteConfirm = false
    @State private var notificationDenied = false
    @State private var showExportAllTours = false
    @State private var showShareLocation = false
    @State private var showResetCoachConfirm = false
    @State private var healthData: OnboardingData? = nil

    private let accentBlue = DesignSystem.Colors.accent
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {

                        SettingsSection(title: "ACCOUNT") {
                            Button(action: { showEditProfile = true }) {
                                SettingsRowLabel(icon: "person.crop.circle", iconColor: accentBlue, text: "Edit Profile", showArrow: true)
                            }
                            AscentDivider()
                            Button(action: { showLogoutConfirm = true }) {
                                SettingsRowLabel(icon: "rectangle.portrait.and.arrow.right", iconColor: .orange, text: "Logout")
                            }
                        }

                        SettingsSection(title: "DATA") {
                            Button(action: { showExportAllTours = true }) {
                                SettingsRowLabel(icon: "square.and.arrow.up", iconColor: DesignSystem.Colors.metricDistance, text: "Export All Tours (GPX)", showArrow: true)
                            }
                        }

                        SettingsSection(title: "SAFETY & SHARING") {
                            Button(action: { showShareLocation = true }) {
                                SettingsRowLabel(icon: "location.circle.fill", iconColor: DesignSystem.Colors.metricDistance, text: "Share Current Location")
                            }
                            AscentDivider()
                            EmergencySettingsView(emergencyManager: emergencyManager)
                        }

                        SettingsSection(title: "OFFLINE") {
                            OfflineDownloadsView(offlineManager: offlineManager)
                        }

                        if let hd = healthData {
                            SettingsSection(title: "HEALTH & BODY") {
                                healthRow(icon: "ruler", label: "Height", value: "\(hd.heightCm) cm")
                                AscentDivider()
                                healthRow(icon: "scalemass", label: "Weight", value: "\(hd.weightKg) kg")
                                AscentDivider()
                                healthRow(icon: "calendar", label: "Age", value: "\(hd.age) yrs")
                                AscentDivider()
                                healthRow(icon: "lungs", label: "VO₂max", value: hd.vo2max > 0 ? "\(hd.vo2max) ml/kg/min" : "Not set")
                                AscentDivider()
                                healthRow(icon: "flame", label: "Active hours/week", value: "\(hd.weeklyActiveHours) h")
                                AscentDivider()
                                healthRow(icon: "figure.run", label: "Endurance", value: hd.endurance.rawValue)
                                AscentDivider()
                                Button(action: { showResetCoachConfirm = true }) {
                                    SettingsRowLabel(icon: "arrow.counterclockwise", iconColor: .orange, text: "Reset AI Coach")
                                }
                            }
                        }

                        SettingsSection(title: "NOTIFICATIONS") {
                            Toggle(isOn: Binding(
                                get: { notificationsEnabled },
                                set: { newValue in
                                    if newValue { requestNotificationPermission() }
                                    else { notificationsEnabled = false }
                                }
                            )) {
                                SettingsRowLabel(icon: "bell.badge.fill", iconColor: DesignSystem.Colors.metricHeart, text: "Push Notifications")
                            }
                            .tint(accentBlue)
                        }

                        SettingsSection(title: "DANGER ZONE") {
                            Button(action: { showDeleteConfirm = true }) {
                                SettingsRowLabel(icon: "trash.fill", iconColor: .red, text: "Delete Account", textColor: .red)
                            }
                        }

                        versionInfo
                    }
                    .padding(.horizontal, DesignSystem.Spacing.screenInset)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(DesignSystem.Colors.surface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                            .frame(width: 30, height: 30)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showEditProfile) {
            EditAccountView()
        }
        .sheet(isPresented: $showExportAllTours) {
            ExportAllToursSheet().environmentObject(appState)
        }
        .sheet(isPresented: $showShareLocation) {
            ShareLocationSheet()
        }
        .alert("Notification Access Denied", isPresented: $notificationDenied) {
            Button("Open Settings") {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Notifications are disabled for Ascent. Please enable them in your device Settings.")
        }
        .confirmationDialog("Logout", isPresented: $showLogoutConfirm, titleVisibility: .visible) {
            Button("Logout", role: .destructive) { performLogout() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to logout? Your data is saved in the cloud.")
        }
        .confirmationDialog("Delete Account", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete Everything", role: .destructive) { deleteAccount() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete your account and all associated data. This action cannot be undone.")
        }
        .confirmationDialog("Reset AI Coach", isPresented: $showResetCoachConfirm, titleVisibility: .visible) {
            Button("Reset", role: .destructive) {
                CoachingViewModel.clearSavedData()
                healthData = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will clear your AI coaching plan and body data. You'll need to redo the onboarding next time you open the AI Coach.")
        }
        .onAppear {
            healthData = CoachingViewModel.loadOnboardingData()
        }
    }

    // MARK: - Version Info

    private var versionInfo: some View {
        VStack(spacing: 4) {
            Text("Ascent")
                .font(.appMono(size: 12, weight: .bold))
                .foregroundColor(DesignSystem.Colors.tertiaryText)
            Text("Version 1.1.0")
                .font(.appMono(size: 10, weight: .medium))
                .foregroundColor(DesignSystem.Colors.tertiaryText.opacity(0.6))
        }
        .padding(.top, 16)
    }

    // MARK: - Helpers

    private func healthRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(accentBlue)
                .frame(width: 24)
            Text(label)
                .font(.app(size: 14, weight: .medium))
                .foregroundColor(.white)
            Spacer()
            Text(value)
                .font(.appMono(size: 14, weight: .bold))
                .foregroundColor(.white)
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async {
                if granted { notificationsEnabled = true }
                else { notificationsEnabled = false; notificationDenied = true }
            }
        }
    }

    private func performLogout() {
        Task {
            do { try await supabase.auth.signOut() }
            catch { print("❌ Logout error: \(error.localizedDescription)") }
            await MainActor.run {
                isLoggedIn = false
                dismiss()
            }
        }
    }
    
    private func deleteAccount() {
        Task {
            do {
                let userId = try await supabase.auth.session.user.id
                
                // Erase data from Profiles (If database triggers are configured, this cascades to auth.users or alerts)
                try await supabase.from("profiles").delete().eq("id", value: userId).execute()
                
                // Attempt to call RPC delete_user if the DB supports it
                _ = try? await supabase.rpc("delete_user").execute()
                
                try await supabase.auth.signOut()
            } catch {
                print("❌ Delete Account error: \(error.localizedDescription)")
            }
            await MainActor.run {
                isLoggedIn = false
                dismiss()
            }
        }
    }
}

// === Reusable Helper Views ===

struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.appMono(size: 11, weight: .bold))
                .foregroundColor(DesignSystem.Colors.tertiaryText)
                .tracking(2)
                .padding(.leading, 4)
            VStack(spacing: 0) { content }
                .padding(.horizontal, DesignSystem.Spacing.cardPadding)
                .padding(.vertical, 12)
                .ascentCard()
        }
    }
}

// MARK: - Route Color Options
enum RouteColorOption: String, CaseIterable {
    case blue, red, green, orange

    var color: Color {
        switch self {
        case .blue:   return DesignSystem.Colors.accent
        case .red:    return .red
        case .green:  return .green
        case .orange: return .orange
        }
    }
}

// MARK: - Export All Tours Sheet
struct ExportAllToursSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var isExporting = false
    @State private var shareURL: URL?
    @State private var showShareSheet = false

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Image(systemName: "square.and.arrow.up.on.square")
                    .font(.app(size: 48))
                    .foregroundColor(DesignSystem.Colors.accent)
                    .padding(.top, 30)

                Text("Export All Tours")
                    .font(.app(.title2))
                    .fontWeight(.bold)

                Text("Export all your recorded tours as individual GPX files bundled in a single archive.")
                    .font(.app(.subheadline))
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)

                Text("\(appState.recentTours.filter { $0.isCurrentUser }.count) tours available")
                    .font(.app(.caption))
                    .foregroundColor(.gray)

                Spacer()

                Button(action: exportAllTours) {
                    if isExporting {
                        ProgressView().tint(.white)
                    } else {
                        Label("Export as GPX", systemImage: "square.and.arrow.up")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isExporting)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                    }
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = shareURL {
                ShareSheet(activityItems: [url])
            }
        }
    }

    private func exportAllTours() {
        isExporting = true
        let myTours = appState.recentTours.filter { $0.isCurrentUser }
        guard !myTours.isEmpty else { isExporting = false; return }

        // Create a combined GPX with all tours as separate tracks
        var gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="Ascent App"
             xmlns="http://www.topografix.com/GPX/1/1">
          <metadata>
            <name>All Tours - \(appState.userName)</name>
            <time>\(ISO8601DateFormatter().string(from: Date()))</time>
          </metadata>
        """

        for tour in myTours {
            gpx += "\n  <trk>\n    <name>\(tour.summitName)</name>\n    <trkseg>"
            for coord in tour.routeCoordinates {
                gpx += "\n      <trkpt lat=\"\(coord.latitude)\" lon=\"\(coord.longitude)\"></trkpt>"
            }
            gpx += "\n    </trkseg>\n  </trk>"
        }

        gpx += "\n</gpx>"

        if let url = GPXExporter.exportToFile(content: gpx, filename: "Ascent_All_Tours.gpx") {
            shareURL = url
            isExporting = false
            showShareSheet = true
        } else {
            isExporting = false
        }
    }
}

// MARK: - Share Location Sheet
struct ShareLocationSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var locationText: String = "Fetching location..."
    @State private var shareItems: [String] = []
    @State private var showShare = false
    @State private var hasLocation = false

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "location.fill")
                    .font(.app(size: 48))
                    .foregroundColor(.blue)
                    .padding(.top, 30)

                Text("Share Location")
                    .font(.app(.title2))
                    .fontWeight(.bold)

                Text(locationText)
                    .font(.app(.subheadline))
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)

                Spacer()

                Button(action: {
                    shareItems = [locationText]
                    showShare = true
                }) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(PrimaryButtonStyle(fillColor: hasLocation ? DesignSystem.Colors.accent : Color.gray))
                .disabled(!hasLocation)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .navigationTitle("Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                    }
                }
            }
            .onAppear { fetchLocation() }
        }
        .sheet(isPresented: $showShare) {
            ShareSheet(activityItems: shareItems)
        }
    }

    private func fetchLocation() {
        // CLLocationManager already authorized by the app — just read last known location
        let locManager = CLLocationManager()
        if let loc = locManager.location {
            let lat = String(format: "%.6f", loc.coordinate.latitude)
            let lon = String(format: "%.6f", loc.coordinate.longitude)
            locationText = "My location (Ascent):\n\(Int(loc.altitude))m altitude\nhttps://maps.apple.com/?ll=\(lat),\(lon)&q=My%20Location"
            hasLocation = true
        } else {
            locationText = "Location not available. Start a tour first to enable GPS tracking."
            hasLocation = false
        }
    }
}

struct SettingsRowLabel: View {
    let icon: String
    let iconColor: Color
    let text: String
    var textColor: Color = .white
    var showArrow: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(iconColor)
                .frame(width: 24)
            Text(text)
                .font(.app(size: 15, weight: .medium))
                .foregroundColor(textColor)
            Spacer()
            if showArrow {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
            }
        }
        .padding(.vertical, 6)
    }
}
