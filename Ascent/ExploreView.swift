import SwiftUI
import MapKit
import CoreLocation
import Combine

// =========================================
// === DATEI: ExploreView.swift ===
// === Map mit Commence Mission Button ===
// =========================================

class ExploreLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var userLocation: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        userLocation = location
        manager.stopUpdatingLocation()
    }
}

struct ExploreView: View {
    @StateObject private var mountainManager = MountainManager()
    @StateObject private var locationManager = ExploreLocationManager()
    
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var selectedMountain: Mountain? = nil
    
    @State private var isSearching = false
    @State private var searchText = ""
    
    // === NEU: Variablen, um den Tracker zu öffnen ===
    @State private var showTracker = false
    @State private var mountainToTrack: Mountain? = nil

    var mapMountains: [Mountain] {
        let validMountains = mountainManager.mountains.filter { $0.latitude != nil && $0.longitude != nil }
        if searchText.isEmpty { return validMountains }
        else {
            return validMountains.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.region.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            
            Map(position: $cameraPosition) {
                ForEach(mapMountains, id: \.id) { mountain in
                    // Ersetze 'Marker' wieder durch 'Annotation' mit unserem Custom-Design,
                    // wenn der Simulator bei dir Custom-Pins unterstützt!
                    Marker(mountain.name, coordinate: CLLocationCoordinate2D(latitude: mountain.latitude!, longitude: mountain.longitude!))
                        .tint(mountain.elevation > 2500 ? Color.orange : Color.cyan)
                }
            }
            .preferredColorScheme(.dark)
            .environment(\.colorScheme, .dark)
            .ignoresSafeArea()
            
            LinearGradient(colors: [.black.opacity(0.8), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 160)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    if isSearching {
                        HStack {
                            Image(systemName: "magnifyingglass").foregroundColor(.gray)
                            TextField("Search peaks or regions...", text: $searchText)
                                .foregroundColor(.white)
                                .autocapitalization(.none)
                            
                            Button(action: {
                                withAnimation(.spring()) {
                                    searchText = ""
                                    isSearching = false
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                            }
                        }
                        .padding(10).background(Color.white.opacity(0.15)).cornerRadius(12)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                        
                    } else {
                        HStack {
                            Button(action: {
                                withAnimation(.spring()) { isSearching = true }
                            }) {
                                Image(systemName: "magnifyingglass").font(.title2).fontWeight(.bold).foregroundColor(.white)
                            }
                            Text("Quest Board").font(.title2).fontWeight(.bold).foregroundColor(.white)
                        }
                        .transition(.opacity)
                    }
                    Spacer()
                }
                
                if !isSearching {
                    Text("\(mapMountains.count) Missions loaded").font(.subheadline).foregroundColor(.green)
                } else if !searchText.isEmpty {
                    Text("\(mapMountains.count) Results found").font(.subheadline).foregroundColor(.orange)
                }
            }
            .padding(.horizontal, 20).padding(.top, 10)

            VStack {
                Spacer()
                if let mountain = selectedMountain {
                    // Wir geben hier den Berg an die Karte und fangen den Klick-Event auf
                    MissionDetailCard(mountain: mountain, onDismiss: {
                        withAnimation(.spring()) { selectedMountain = nil }
                    }, onCommence: {
                        // === HIER WIRD DER TRACKER GESTARTET ===
                        mountainToTrack = mountain
                        showTracker = true
                    })
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 150)
                }
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .task {
            await mountainManager.fetchMountainsFromDatabase()
            zoomToClosestMountain(userLoc: locationManager.userLocation)
        }
        .onChange(of: locationManager.userLocation) { newLocation in
            zoomToClosestMountain(userLoc: newLocation)
        }
        .onChange(of: searchText) { _ in
            if let firstMatch = mapMountains.first, let lat = firstMatch.latitude, let lon = firstMatch.longitude {
                withAnimation(.easeInOut(duration: 1.0)) {
                    cameraPosition = .region(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: lat, longitude: lon), span: MKCoordinateSpan(latitudeDelta: 1.5, longitudeDelta: 1.5)))
                }
            }
        }
        // === NEU: Ruft den Tracker im Vollbild auf ===
        .fullScreenCover(isPresented: $showTracker) {
            // Übergibt den Berg an den Tracker
            LiveRecordView(targetMountain: mountainToTrack)
        }
    }
    
    func zoomToClosestMountain(userLoc: CLLocation?) {
        guard let userLoc = userLoc, !mapMountains.isEmpty else { return }
        if let closestMountain = mapMountains.min(by: { m1, m2 in
            let loc1 = CLLocation(latitude: m1.latitude!, longitude: m1.longitude!)
            let loc2 = CLLocation(latitude: m2.latitude!, longitude: m2.longitude!)
            return userLoc.distance(from: loc1) < userLoc.distance(from: loc2)
        }), let lat = closestMountain.latitude, let lon = closestMountain.longitude {
            withAnimation(.easeInOut(duration: 2.0)) {
                cameraPosition = .region(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: lat, longitude: lon), span: MKCoordinateSpan(latitudeDelta: 1.5, longitudeDelta: 1.5)))
            }
        }
    }
}

// =========================================
// === HILFS-VIEW: DIE MISSION CARD ===
// =========================================
struct MissionDetailCard: View {
    let mountain: Mountain
    let onDismiss: () -> Void
    let onCommence: () -> Void // === NEU: Aktion für den Button ===

    var isElite: Bool { mountain.elevation > 2500 }
    var prestigePoints: Int { mountain.elevation / 10 }
    var mockConquerors: Int { max(10, 5000 - mountain.elevation) / 10 }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(mountain.name) Ascent").font(.title2).fontWeight(.bold).foregroundColor(.white)
                    Text(mountain.region).font(.subheadline).foregroundColor(.gray)
                }
                Spacer()
                if isElite {
                    Text("ELITE MISSION").font(.system(size: 10, weight: .black)).padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color(red: 0.85, green: 0.65, blue: 0.13)).foregroundColor(.black).cornerRadius(6)
                }
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatBox(value: "\(mountain.elevation)m", label: "PEAK ELEVATION")
                StatBox(value: "+\(prestigePoints)", label: "PRESTIGE POINTS", valueColor: Color(red: 0.4, green: 0.8, blue: 0.9))
                StatBox(value: "\(mockConquerors)", label: "CONQUERORS")
                StatBox(value: isElite ? "Gold" : "Silver", label: "BADGE TIER")
            }

            // === HIER WIRD 'onCommence' AUSGEFÜHRT ===
            Button(action: {
                let impactMed = UIImpactFeedbackGenerator(style: .heavy)
                impactMed.impactOccurred()
                onCommence() // Startet den Tracker
            }) {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Commence Mission")
                }
                .font(.headline).fontWeight(.bold).foregroundColor(.black).frame(maxWidth: .infinity)
                .padding(.vertical, 16).background(Color.white).cornerRadius(16)
            }
        }
        .padding(25).background(Color(red: 0.08, green: 0.08, blue: 0.1)).cornerRadius(30)
        .overlay(Button(action: onDismiss) { Image(systemName: "xmark.circle.fill").font(.title2).foregroundStyle(.gray, .white.opacity(0.1)) }.padding(20), alignment: .topTrailing)
        .padding(.horizontal, 15).shadow(color: .black.opacity(0.6), radius: 25, y: 10)
    }
}

struct StatBox: View {
    let value: String; let label: String; var valueColor: Color = .white
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.headline).fontWeight(.bold).foregroundColor(valueColor)
            Text(label).font(.system(size: 9, weight: .bold)).foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(12).background(Color.white.opacity(0.05)).cornerRadius(12)
    }
}
