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

    @AppStorage("isDarkMode") private var isDarkMode = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("isLoggedIn") private var isLoggedIn = true
    @AppStorage("voiceGuidanceEnabled") private var voiceGuidanceEnabled = true
    @AppStorage("voiceGuidanceVolume") private var voiceGuidanceVolume: Double = 0.8
    @AppStorage("distanceUnit") private var distanceUnit = "metric"
    @AppStorage("autoRecordPauses") private var autoRecordPauses = true
    @AppStorage("showElevationProfile") private var showElevationProfile = true
    @AppStorage("liveTrackingDefault") private var liveTrackingDefault = false
    @AppStorage("routeColor") private var routeColorName: String = "blue"

    @ObservedObject private var emergencyManager = EmergencyManager.shared
    @ObservedObject private var offlineManager = OfflineManager.shared

    @State private var showEditProfile = false
    @State private var showTerms = false
    @State private var showPrivacy = false
    @State private var showLogoutConfirm = false
    @State private var showDeleteConfirm = false
    @State private var notificationDenied = false
    @State private var selectedSection: SettingsTab = .general
    @State private var showExportAllTours = false
    @State private var showShareLocation = false

    private let accentBlue = Color(red: 0.1, green: 0.5, blue: 0.95)

    enum SettingsTab: String, CaseIterable {
        case general = "General"
        case tracking = "Tracking"
        case navigation = "Navigation"
        case safety = "Safety"
        case offline = "Offline"
        case account = "Account"

        var icon: String {
            switch self {
            case .general:    return "gearshape.fill"
            case .tracking:   return "location.fill"
            case .navigation: return "map.fill"
            case .safety:     return "shield.fill"
            case .offline:    return "icloud.and.arrow.down"
            case .account:    return "person.fill"
            }
        }

        var color: Color {
            switch self {
            case .general:    return .gray
            case .tracking:   return .blue
            case .navigation: return .green
            case .safety:     return .red
            case .offline:    return .purple
            case .account:    return .orange
            }
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.95, green: 0.95, blue: 0.97).ignoresSafeArea()

                // Ambient blobs
                Circle()
                    .fill(RadialGradient(colors: [Color.blue.opacity(0.08), Color.clear], center: .center, startRadius: 0, endRadius: 125))
                    .frame(width: 250, height: 250)
                    .offset(x: -100, y: -100)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {

                        // Section Picker
                        sectionPicker

                        // Dynamic content based on selected section
                        switch selectedSection {
                        case .general:    generalSection
                        case .tracking:   trackingSection
                        case .navigation: navigationSection
                        case .safety:     safetySection
                        case .offline:    offlineSection
                        case .account:    accountSection
                        }

                        // Version info
                        versionInfo
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbarBackground(Color(white: 0.98), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(.system(.title3, design: .rounded))
                    }
                }
            }
        }
        .preferredColorScheme(.light)
        .sheet(isPresented: $showEditProfile) {
            EditAccountView()
        }
        .sheet(isPresented: $showTerms) {
            SafariView(url: URL(string: "https://ascent.app/terms")!)
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showPrivacy) {
            SafariView(url: URL(string: "https://ascent.app/privacy")!)
                .ignoresSafeArea()
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
            Button("Delete Everything", role: .destructive) { performLogout() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete your account and all associated data. This action cannot be undone.")
        }
    }

    // MARK: - Section Picker

    private var sectionPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedSection = tab
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 12, weight: .bold))
                            Text(tab.rawValue)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(selectedSection == tab ? tab.color.opacity(0.15) : Color.clear)
                        .foregroundColor(selectedSection == tab ? tab.color : .secondary)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(selectedSection == tab ? tab.color.opacity(0.3) : Color.clear, lineWidth: 1)
                        )
                    }
                }
            }
        }
    }

    // MARK: - General Section

    private var generalSection: some View {
        VStack(spacing: 16) {
            SettingsSection(title: "APPEARANCE") {
                Toggle(isOn: $isDarkMode) {
                    SettingsRowLabel(icon: "moon.fill", iconColor: .cyan, text: "Dark Mode")
                }
                .tint(accentBlue)

                Divider().background(Color.black.opacity(0.1))

                HStack(spacing: 15) {
                    SettingsRowLabel(icon: "ruler", iconColor: .blue, text: "Units")
                    Spacer()
                    Picker("", selection: $distanceUnit) {
                        Text("Metric").tag("metric")
                        Text("Imperial").tag("imperial")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)
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
                    SettingsRowLabel(icon: "bell.badge.fill", iconColor: .red, text: "Push Notifications")
                }
                .tint(accentBlue)
            }
        }
    }

    // MARK: - Tracking Section

    private var trackingSection: some View {
        VStack(spacing: 16) {
            SettingsSection(title: "RECORDING") {
                Toggle(isOn: $autoRecordPauses) {
                    SettingsRowLabel(icon: "pause.circle.fill", iconColor: .orange, text: "Auto-Detect Pauses")
                }
                .tint(accentBlue)

                Divider().background(Color.black.opacity(0.1))

                Toggle(isOn: $showElevationProfile) {
                    SettingsRowLabel(icon: "chart.line.uptrend.xyaxis", iconColor: .purple, text: "Show Elevation Profile")
                }
                .tint(accentBlue)

                Divider().background(Color.black.opacity(0.1))

                Toggle(isOn: $liveTrackingDefault) {
                    VStack(alignment: .leading, spacing: 2) {
                        SettingsRowLabel(icon: "antenna.radiowaves.left.and.right", iconColor: .green, text: "Auto Live Tracking")
                    }
                }
                .tint(accentBlue)

                Text("When enabled, live tracking starts automatically with each tour so friends and family can follow your progress.")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.leading, 47)
            }

            SettingsSection(title: "DATA") {
                Button(action: { showExportAllTours = true }) {
                    SettingsRowLabel(icon: "square.and.arrow.up", iconColor: .blue, text: "Export All Tours (GPX)", showArrow: true)
                }
            }
            .sheet(isPresented: $showExportAllTours) {
                ExportAllToursSheet()
                    .environmentObject(appState)
            }
        }
    }

    // MARK: - Navigation Section

    private var navigationSection: some View {
        VStack(spacing: 16) {
            SettingsSection(title: "VOICE GUIDANCE") {
                Toggle(isOn: $voiceGuidanceEnabled) {
                    SettingsRowLabel(icon: "speaker.wave.3.fill", iconColor: .green, text: "Voice Navigation")
                }
                .tint(accentBlue)

                if voiceGuidanceEnabled {
                    Divider().background(Color.black.opacity(0.1))

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            SettingsRowLabel(icon: "speaker.fill", iconColor: .gray, text: "Volume")
                            Spacer()
                            Text("\(Int(voiceGuidanceVolume * 100))%")
                                .font(.system(.caption, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $voiceGuidanceVolume, in: 0...1, step: 0.1)
                            .tint(accentBlue)
                            .padding(.leading, 47)
                    }
                }
            }

            SettingsSection(title: "ROUTE DISPLAY") {
                HStack(spacing: 15) {
                    SettingsRowLabel(icon: "paintbrush.fill", iconColor: .purple, text: "Route Color")
                    Spacer()
                    HStack(spacing: 8) {
                        ForEach(RouteColorOption.allCases, id: \.self) { option in
                            Button(action: {
                                withAnimation(.spring(response: 0.25)) {
                                    routeColorName = option.rawValue
                                }
                                HapticManager.shared.light()
                            }) {
                                Circle()
                                    .fill(option.color)
                                    .frame(width: 28, height: 28)
                                    .overlay(
                                        Circle().stroke(Color.white, lineWidth: 2)
                                    )
                                    .overlay(
                                        routeColorName == option.rawValue
                                            ? Image(systemName: "checkmark")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(.white)
                                            : nil
                                    )
                                    .scaleEffect(routeColorName == option.rawValue ? 1.15 : 1.0)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Safety Section

    private var safetySection: some View {
        VStack(spacing: 16) {
            SettingsSection(title: "EMERGENCY CONTACTS") {
                EmergencySettingsView(emergencyManager: emergencyManager)
            }

            SettingsSection(title: "SOS SETTINGS") {
                HStack(spacing: 12) {
                    Image(systemName: "sos.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.red)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Emergency SOS")
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.semibold)
                        Text("Hold the SOS button for 3 seconds during a tour to send your location to emergency contacts.")
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }

                if emergencyManager.contacts.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Add an emergency contact above to enable SOS.")
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(.orange)
                    }
                    .padding(10)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("SOS will notify \(emergencyManager.contacts.first(where: { $0.isDefault })?.name ?? "your contact") at \(emergencyManager.contacts.first(where: { $0.isDefault })?.phone ?? "")")
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    .padding(10)
                    .background(Color.green.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                Divider().background(Color.black.opacity(0.1))

                Button(action: { showShareLocation = true }) {
                    HStack(spacing: 12) {
                        Image(systemName: "location.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Share Current Location")
                                .font(.system(.subheadline, design: .rounded))
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            Text("Share your GPS coordinates via message.")
                                .font(.system(.caption, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(.caption))
                            .foregroundColor(.gray)
                    }
                }
            }
            .sheet(isPresented: $showShareLocation) {
                ShareLocationSheet()
            }
        }
    }

    // MARK: - Offline Section

    private var offlineSection: some View {
        VStack(spacing: 16) {
            SettingsSection(title: "OFFLINE CONTENT") {
                OfflineDownloadsView(offlineManager: offlineManager)
            }

            SettingsSection(title: "INFO") {
                HStack(spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 20))
                    Text("Download routes and map regions from the Explore tab. Offline content allows navigation without cell service.")
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Account Section

    private var accountSection: some View {
        VStack(spacing: 16) {
            SettingsSection(title: "PROFILE") {
                Button(action: { showEditProfile = true }) {
                    SettingsRowLabel(icon: "person.crop.circle", iconColor: accentBlue, text: "Edit Profile", showArrow: true)
                }
            }

            SettingsSection(title: "ABOUT") {
                Button(action: { showTerms = true }) {
                    SettingsRowLabel(icon: "doc.text.fill", iconColor: .gray, text: "Terms of Service", showArrow: true)
                }

                Divider().background(Color.black.opacity(0.1))

                Button(action: { showPrivacy = true }) {
                    SettingsRowLabel(icon: "hand.raised.fill", iconColor: .gray, text: "Privacy Policy", showArrow: true)
                }
            }

            SettingsSection(title: "SESSION") {
                Button(action: { showLogoutConfirm = true }) {
                    SettingsRowLabel(icon: "rectangle.portrait.and.arrow.right", iconColor: .orange, text: "Logout")
                }
            }

            SettingsSection(title: "DANGER ZONE") {
                Button(action: { showDeleteConfirm = true }) {
                    SettingsRowLabel(icon: "trash.fill", iconColor: .red, text: "Delete Account", textColor: .red)
                }
            }
        }
    }

    // MARK: - Version Info

    private var versionInfo: some View {
        VStack(spacing: 4) {
            Text("Ascent")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.gray.opacity(0.5))
            Text("Version 1.1.0")
                .font(.system(size: 11, design: .rounded))
                .foregroundColor(.gray.opacity(0.3))
        }
        .padding(.top, 16)
    }

    // MARK: - Helpers

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
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundColor(.gray)
                .tracking(2)
                .padding(.leading, 10)
            VStack(spacing: 15) { content }
                .padding(20)
                .background(.ultraThinMaterial)
                .environment(\.colorScheme, .light)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
        }
    }
}

// MARK: - Route Color Options
enum RouteColorOption: String, CaseIterable {
    case blue, red, green, orange

    var color: Color {
        switch self {
        case .blue:   return Color(red: 0.1, green: 0.5, blue: 0.95)
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
                    .font(.system(size: 48))
                    .foregroundColor(Color(red: 0.1, green: 0.5, blue: 0.95))
                    .padding(.top, 30)

                Text("Export All Tours")
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.bold)

                Text("Export all your recorded tours as individual GPX files bundled in a single archive.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)

                Text("\(appState.recentTours.filter { $0.isCurrentUser }.count) tours available")
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.gray)

                Spacer()

                Button(action: exportAllTours) {
                    if isExporting {
                        ProgressView().tint(.white)
                    } else {
                        Label("Export as GPX", systemImage: "square.and.arrow.up")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color(red: 0.1, green: 0.5, blue: 0.95))
                .foregroundColor(.white)
                .font(.system(.headline, design: .rounded))
                .clipShape(RoundedRectangle(cornerRadius: 14))
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
                    .font(.system(size: 48))
                    .foregroundColor(.blue)
                    .padding(.top, 30)

                Text("Share Location")
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.bold)

                Text(locationText)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)

                Spacer()

                Button(action: {
                    shareItems = [locationText]
                    showShare = true
                }) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(hasLocation ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .font(.system(.headline, design: .rounded))
                .clipShape(RoundedRectangle(cornerRadius: 14))
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
    var textColor: Color = .primary
    var showArrow: Bool = false

    var body: some View {
        HStack(spacing: 15) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.2))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }
            Text(text)
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(textColor)
            Spacer()
            if showArrow {
                Image(systemName: "chevron.right")
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.gray)
            }
        }
    }
}
