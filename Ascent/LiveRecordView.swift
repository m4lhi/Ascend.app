import SwiftUI
import MapKit
import Combine
import CoreLocation

// =========================================
// === DATEI: LiveRecordView.swift ===
// === Tracker mit Smartem Gipfel-Check ===
// =========================================


class LiveGPSManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    
    @Published var distance: Double = 0.0
    @Published var elevationGain: Double = 0.0
    @Published var currentLocation: CLLocation?
    @Published var routePoints: [CLLocationCoordinate2D] = []
    private var lastLocation: CLLocation?
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 5
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
        manager.requestWhenInUseAuthorization()
    }
    
    func startTracking() { manager.startUpdatingLocation() }
    func stopTracking() { manager.stopUpdatingLocation() }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation = locations.last else { return }
        currentLocation = newLocation
        routePoints.append(newLocation.coordinate)
        
        if let last = lastLocation {
            let distanceDelta = newLocation.distance(from: last)
            distance += distanceDelta
            let elevationDelta = newLocation.altitude - last.altitude
            if elevationDelta > 0 { elevationGain += elevationDelta }
        }
        lastLocation = newLocation
    }
}

struct LiveRecordView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    
    var targetMountain: Mountain?
    
    @StateObject private var gpsManager = LiveGPSManager()
    @State private var timeElapsed: Int = 0
    @State private var isRunning: Bool = false
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 47.421, longitude: 10.984),
        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
    )))
    
    @State private var showSaveForm = false
    
    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.08).ignoresSafeArea()
            
            VStack {
                HStack {
                    if isRunning {
                        Circle().fill(Color.red).frame(width: 10, height: 10).shadow(color: .red, radius: 5)
                            .opacity(timeElapsed % 2 == 0 ? 1.0 : 0.3).animation(.easeInOut, value: timeElapsed)
                    }
                    Text(isRunning ? "RECORDING" : (targetMountain?.name.uppercased() ?? "FREERIDE"))
                        .font(.caption).fontWeight(.bold).foregroundColor(isRunning ? .red : .gray).tracking(2)
                    
                    Spacer()
                    Button(action: { dismiss() }) { Image(systemName: "xmark.circle.fill").font(.system(size: 32)).foregroundColor(.white.opacity(0.5)) }
                }
                .padding(.horizontal, 25).padding(.top, 20)
                
                Spacer().frame(height: 30)
                
                Text(timeString(from: timeElapsed)).font(.system(size: 64, weight: .light, design: .monospaced)).foregroundColor(.white)
                
                Map(position: $cameraPosition) {
                    UserAnnotation()
                    if !gpsManager.routePoints.isEmpty {
                        MapPolyline(coordinates: gpsManager.routePoints)
                            .stroke(Color(red: 0.85, green: 0.65, blue: 0.13), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                    }
                }
                .preferredColorScheme(.dark).frame(height: 250).cornerRadius(25).padding(.horizontal, 25).padding(.top, 20)
                .shadow(color: .black.opacity(0.3), radius: 15, y: 10)
                
                HStack(spacing: 50) {
                    VStack(spacing: 8) {
                        Text("\(Int(gpsManager.elevationGain))m").font(.title2).fontWeight(.bold).foregroundColor(.white)
                        Text("ELEVATION").font(.caption).fontWeight(.bold).foregroundColor(.gray)
                    }
                    VStack(spacing: 8) {
                        Text(String(format: "%.1f km", gpsManager.distance / 1000)).font(.title2).fontWeight(.bold).foregroundColor(.white)
                        Text("DISTANCE").font(.caption).fontWeight(.bold).foregroundColor(.gray)
                    }
                }
                .padding(.vertical, 30)
                
                Spacer()
                
                HStack(spacing: 30) {
                    if !isRunning && timeElapsed > 0 {
                        Button(action: endMission) {
                            Image(systemName: "stop.fill").font(.title).foregroundColor(.white).frame(width: 70, height: 70)
                                .background(Color.red).clipShape(Circle()).shadow(color: .red.opacity(0.5), radius: 10, y: 5)
                        }
                    }
                    
                    Button(action: {
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        isRunning.toggle()
                        if isRunning { gpsManager.startTracking() } else { gpsManager.stopTracking() }
                    }) {
                        Image(systemName: isRunning ? "pause.fill" : "play.fill").font(.system(size: 32, weight: .black)).foregroundColor(.black)
                            .frame(width: 90, height: 90).background(Color(red: 0.85, green: 0.65, blue: 0.13)).clipShape(Circle())
                            .shadow(color: Color(red: 0.85, green: 0.65, blue: 0.13).opacity(0.5), radius: 15, y: 5)
                    }
                }
                .padding(.bottom, 60)
            }
        }
        .onReceive(timer) { _ in if isRunning { timeElapsed += 1 } }
        .sheet(isPresented: $showSaveForm) {
            // Wir übergeben jetzt den KOMPLETTEN Berg an das Formular
            MissionSaveView(
                targetMountain: targetMountain,
                elevationMeters: Int(gpsManager.elevationGain),
                durationSeconds: TimeInterval(timeElapsed),
                distanceKm: gpsManager.distance / 1000.0,
                onDismissTracker: { dismiss() }
            )
        }
    }
    
    func timeString(from seconds: Int) -> String {
        let h = seconds / 3600; let m = (seconds % 3600) / 60; let s = seconds % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
    
    func endMission() {
        isRunning = false
        gpsManager.stopTracking()
        showSaveForm = true
    }
}

// =========================================
// === HILFS-VIEW: Das smarte Save-Formular ===
// =========================================
struct MissionSaveView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    
    var targetMountain: Mountain?
    var elevationMeters: Int
    var durationSeconds: TimeInterval
    var distanceKm: Double
    var onDismissTracker: () -> Void
    
    @State private var summitName: String = ""
    @State private var storyComment: String = ""
    
    // === DER GIPFEL-CHECK ===
    // (Wir sagen einfach: Wenn er mindestens 80% der Höhenmeter des Berges geschafft hat, gilt es als geschafft!)
    var isVerifiedSummit: Bool {
        guard let mountain = targetMountain else { return false }
        return elevationMeters >= Int(Double(mountain.elevation) * 0.8)
    }
    
    // Basis XP + Bonus XP wenn verifiziert
    var xpGained: Int {
        let baseXP = 100 + elevationMeters
        return isVerifiedSummit ? baseXP + 500 : baseXP
    }
    
    var formattedDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: durationSeconds) ?? "0m"
    }

    var body: some View {
        NavigationView {
            Form {
                // === DIE NEUE VERIFIKATIONS-ANZEIGE ===
                if let mountain = targetMountain {
                    Section {
                        HStack {
                            if isVerifiedSummit {
                                Image(systemName: "checkmark.seal.fill").foregroundColor(.green).font(.title)
                                VStack(alignment: .leading) {
                                    Text("Verified Summit").font(.headline).foregroundColor(.green)
                                    Text("You conquered \(mountain.name)! (+500 Bonus XP)").font(.caption).foregroundColor(.gray)
                                }
                            } else {
                                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange).font(.title)
                                VStack(alignment: .leading) {
                                    Text("Mission Attempt").font(.headline).foregroundColor(.orange)
                                    Text("Elevation too low to verify summit.").font(.caption).foregroundColor(.gray)
                                }
                            }
                        }
                        .padding(.vertical, 5)
                    }
                }
                
                Section(header: Text("Summit Info")) {
                    TextField("Summit Name (e.g., Zugspitze)", text: $summitName)
                }
                
                Section(header: Text("Your Story")) {
                    TextEditor(text: $storyComment)
                        .frame(height: 100)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                }
                
                Section(header: Text("Live Tracker Stats")) {
                    HStack { Text("Elevation:"); Spacer(); Text("\(elevationMeters) m").foregroundColor(.gray) }
                    HStack { Text("Duration:"); Spacer(); Text(formattedDuration).foregroundColor(.gray) }
                    HStack { Text("Distance:"); Spacer(); Text(String(format: "%.1f km", distanceKm)).foregroundColor(.gray) }
                    HStack { Text("XP Gained:"); Spacer(); Text("+\(xpGained) XP").foregroundColor(.blue).fontWeight(.bold) }
                }
            }
            .navigationTitle("Save Your Mission")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Discard") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        // Optional: Du könntest in der Cloud auch speichern, ob es verifiziert ist!
                        appState.addCompletedTour(
                            summit: summitName,
                            comment: storyComment,
                            elevation: elevationMeters,
                            duration: durationSeconds,
                            distance: distanceKm,
                            xp: xpGained
                        )
                        dismiss()
                        onDismissTracker()
                    }
                    .fontWeight(.bold)
                    .disabled(summitName.isEmpty || storyComment.isEmpty)
                }
            }
            .onAppear {
                if let prefilledName = targetMountain?.name {
                    summitName = prefilledName
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
