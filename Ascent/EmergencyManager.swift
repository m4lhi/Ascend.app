import Foundation
import Combine
import CoreLocation
import SwiftUI
import MessageUI
import Supabase

// =========================================
// === DATEI: EmergencyManager.swift ===
// === SOS, Live-Tracking, Standort teilen ===
// =========================================

struct EmergencyContact: Identifiable, Codable {
    let id: UUID
    var name: String
    var phone: String
    var isDefault: Bool

    init(id: UUID = UUID(), name: String, phone: String, isDefault: Bool = false) {
        self.id = id; self.name = name; self.phone = phone; self.isDefault = isDefault
    }
}

struct LiveTrackingSession: Codable {
    let session_id: UUID
    let user_id: UUID
    var latitude: Double
    var longitude: Double
    var altitude: Double
    var last_updated: Date
    var is_active: Bool
    var tour_name: String?
}

@MainActor
class EmergencyManager: ObservableObject {
    static let shared = EmergencyManager()

    @Published var contacts: [EmergencyContact] = []
    @Published var isLiveTracking = false
    @Published var liveTrackingLink: String?
    @Published var sosTriggered = false

    private var liveTrackingSessionId: UUID?
    private let contactsKey = "emergency_contacts"

    init() {
        loadContacts()
    }

    // MARK: - Contact Management

    func addContact(name: String, phone: String) {
        let contact = EmergencyContact(name: name, phone: phone, isDefault: contacts.isEmpty)
        contacts.append(contact)
        saveContacts()
    }

    func removeContact(id: UUID) {
        contacts.removeAll { $0.id == id }
        if contacts.first(where: { $0.isDefault }) == nil {
            contacts.indices.first.map { contacts[$0].isDefault = true }
        }
        saveContacts()
    }

    func setDefaultContact(id: UUID) {
        for i in contacts.indices {
            contacts[i].isDefault = contacts[i].id == id
        }
        saveContacts()
    }

    private func saveContacts() {
        if let data = try? JSONEncoder().encode(contacts) {
            UserDefaults.standard.set(data, forKey: contactsKey)
        }
    }

    private func loadContacts() {
        if let data = UserDefaults.standard.data(forKey: contactsKey),
           let saved = try? JSONDecoder().decode([EmergencyContact].self, from: data) {
            contacts = saved
        }
    }

    // MARK: - SOS

    func triggerSOS(location: CLLocation?) {
        sosTriggered = true
        HapticManager.shared.heavy()

        // Direct call to emergency contact
        if let defaultContact = contacts.first(where: { $0.isDefault }) {
            let cleaned = defaultContact.phone.replacingOccurrences(of: " ", with: "")
            if let url = URL(string: "tel://\(cleaned)") {
                UIApplication.shared.open(url)
            }
        }
    }

    func cancelSOS() {
        sosTriggered = false
    }

    // MARK: - Live Tracking

    func startLiveTracking(tourName: String?) async {
        do {
            let userId = try await supabase.auth.session.user.id
            let sessionId = UUID()
            liveTrackingSessionId = sessionId

            let session = LiveTrackingSession(
                session_id: sessionId,
                user_id: userId,
                latitude: 0, longitude: 0, altitude: 0,
                last_updated: Date(),
                is_active: true,
                tour_name: tourName
            )

            try await supabase.from("live_tracking").insert(session).execute()
            isLiveTracking = true
            liveTrackingLink = "ascent://live/\(sessionId.uuidString)"
        } catch {
            print("❌ Start live tracking error: \(error)")
        }
    }

    private struct LiveLocationUpdate: Codable {
        let latitude: Double
        let longitude: Double
        let altitude: Double
        let last_updated: String
    }

    private struct LiveTrackingStop: Codable {
        let is_active: Bool
    }

    func updateLiveLocation(_ location: CLLocation) async {
        guard isLiveTracking, let sessionId = liveTrackingSessionId else { return }

        do {
            let update = LiveLocationUpdate(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                altitude: location.altitude,
                last_updated: ISO8601DateFormatter().string(from: Date())
            )
            try await supabase.from("live_tracking")
                .update(update)
                .eq("session_id", value: sessionId)
                .execute()
        } catch {
            print("⚠️ Update live location error: \(error)")
        }
    }

    func stopLiveTracking() async {
        guard let sessionId = liveTrackingSessionId else { return }

        do {
            try await supabase.from("live_tracking")
                .update(LiveTrackingStop(is_active: false))
                .eq("session_id", value: sessionId)
                .execute()
        } catch {
            print("⚠️ Stop live tracking error: \(error)")
        }

        isLiveTracking = false
        liveTrackingSessionId = nil
        liveTrackingLink = nil
    }

    // MARK: - Share Location

    func shareCurrentLocation(_ location: CLLocation) -> String {
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        return "My current location (Ascent): \(Int(location.altitude))m altitude\nhttps://maps.apple.com/?ll=\(lat),\(lon)&q=My%20Location"
    }

    private func shareViaSMS(to phone: String, body: String) {
        guard let url = URL(string: "sms:\(phone)&body=\(body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - SOS Button View
struct SOSButtonView: View {
    @ObservedObject var emergencyManager: EmergencyManager
    let currentLocation: CLLocation?
    @State private var holdProgress: Double = 0
    @State private var holdTimer: Timer?
    @State private var showSOSConfirm = false

    private let holdDuration: Double = 3.0

    var body: some View {
        ZStack {
            Circle()
                .fill(emergencyManager.sosTriggered ? Color.red : Color.red.opacity(0.15))
                .frame(width: 40, height: 40)

            Circle()
                .trim(from: 0, to: holdProgress)
                .stroke(Color.red, lineWidth: 3)
                .frame(width: 40, height: 40)
                .rotationEffect(.degrees(-90))

            Image(systemName: emergencyManager.sosTriggered ? "sos.circle.fill" : "sos")
                .font(.system(size: emergencyManager.sosTriggered ? 18 : 13, weight: .black))
                .foregroundColor(emergencyManager.sosTriggered ? .white : .red)
        }
        .contentShape(Circle())
        .gesture(
            LongPressGesture(minimumDuration: holdDuration)
                .onEnded { _ in
                    triggerSOS()
                }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if holdTimer == nil {
                        startHoldTimer()
                    }
                }
                .onEnded { _ in
                    cancelHold()
                }
        )
        .alert("SOS Active", isPresented: $showSOSConfirm) {
            Button("Cancel SOS", role: .cancel) {
                emergencyManager.cancelSOS()
            }
        } message: {
            Text("Emergency message sent to your emergency contacts with your current location.")
        }
    }

    private func startHoldTimer() {
        holdProgress = 0
        holdTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            Task { @MainActor in
                holdProgress += 0.05 / holdDuration
                if holdProgress >= 1.0 {
                    triggerSOS()
                }
            }
        }
    }

    private func triggerSOS() {
        holdTimer?.invalidate()
        holdTimer = nil
        holdProgress = 0
        emergencyManager.triggerSOS(location: currentLocation)
        showSOSConfirm = true
    }

    private func cancelHold() {
        if holdProgress < 1.0 {
            holdTimer?.invalidate()
            holdTimer = nil
            withAnimation { holdProgress = 0 }
        }
    }
}

// MARK: - Emergency Settings Section
struct EmergencySettingsView: View {
    @ObservedObject var emergencyManager: EmergencyManager
    @State private var showAddContact = false
    @State private var newName = ""
    @State private var newPhone = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Contacts list
            if emergencyManager.contacts.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.badge.exclamationmark")
                        .font(.system(size: 28))
                        .foregroundColor(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("No Emergency Contacts")
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.semibold)
                        Text("Add a contact to enable SOS features")
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                ForEach(emergencyManager.contacts) { contact in
                    HStack(spacing: 12) {
                        Image(systemName: contact.isDefault ? "star.circle.fill" : "person.circle")
                            .foregroundColor(contact.isDefault ? .orange : .gray)
                            .font(.system(size: 22))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(contact.name)
                                .font(.system(.subheadline, design: .rounded))
                                .fontWeight(.semibold)
                            Text(contact.phone)
                                .font(.system(.caption, design: .rounded))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if !contact.isDefault {
                            Button(action: { emergencyManager.setDefaultContact(id: contact.id) }) {
                                Text("Set Default")
                                    .font(.system(.caption2, design: .rounded))
                                    .foregroundColor(DesignSystem.Colors.accent)
                            }
                        }

                        Button(action: { emergencyManager.removeContact(id: contact.id) }) {
                            Image(systemName: "trash")
                                .font(.system(size: 14))
                                .foregroundColor(.red)
                        }
                    }

                    if contact.id != emergencyManager.contacts.last?.id {
                        Divider()
                    }
                }
            }

            // Add contact button
            if showAddContact {
                VStack(spacing: 10) {
                    TextField("Name", text: $newName)
                        .textFieldStyle(.roundedBorder)
                    TextField("Phone Number", text: $newPhone)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.phonePad)
                    HStack {
                        Button("Cancel") {
                            showAddContact = false
                            newName = ""; newPhone = ""
                        }
                        .foregroundColor(.secondary)
                        Spacer()
                        Button("Add") {
                            emergencyManager.addContact(name: newName, phone: newPhone)
                            showAddContact = false
                            newName = ""; newPhone = ""
                        }
                        .disabled(newName.isEmpty || newPhone.isEmpty)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.accent)
                    }
                }
                .padding(12)
                .background(Color.gray.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                Button(action: { showAddContact = true }) {
                    Label("Add Emergency Contact", systemImage: "plus.circle.fill")
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.accent)
                }
            }
        }
    }
}
