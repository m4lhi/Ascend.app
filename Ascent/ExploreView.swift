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
    @State private var selectedMarkerTag: UUID? = nil

    @State private var isSearching = false
    @State private var searchText = ""
    @State private var selectedDifficulty: Difficulty? = nil
    @State private var showNearby = false
    @State private var nearbyRadiusKm: Double = 25

    // Debounce
    @State private var searchTask: Task<Void, Never>? = nil

    // === Variablen, um den Tracker zu öffnen ===
    @State private var showTracker = false
    @State private var mountainToTrack: Mountain? = nil

    var mapMountains: [Mountain] {
        var source: [Mountain]
        if showNearby {
            source = mountainManager.nearbyMountains
            // Client-side filters on top of spatial results
            if !searchText.isEmpty {
                source = source.filter {
                    $0.name.localizedCaseInsensitiveContains(searchText) ||
                    $0.region.localizedCaseInsensitiveContains(searchText)
                }
            }
            if let diff = selectedDifficulty {
                source = source.filter { $0.difficulty == diff }
            }
        } else {
            source = mountainManager.mountains
        }
        return source.filter { $0.latitude != nil && $0.longitude != nil }
    }

    var body: some View {
        ZStack(alignment: .top) {

            Map(position: $cameraPosition, selection: $selectedMarkerTag) {
                ForEach(mapMountains, id: \.id) { mountain in
                    Marker(mountain.name, coordinate: CLLocationCoordinate2D(latitude: mountain.latitude!, longitude: mountain.longitude!))
                        .tint(mountain.elevation > 2500 ? Color.orange : Color.cyan)
                        .tag(mountain.id)
                }

                // POI annotations (visible in nearby mode)
                if showNearby {
                    ForEach(mountainManager.nearbyPOIs) { poi in
                        Annotation(poi.name, coordinate: CLLocationCoordinate2D(latitude: poi.latitude, longitude: poi.longitude)) {
                            Image(systemName: poiIcon(for: poi.type))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 24, height: 24)
                                .background(poiColor(for: poi.type))
                                .clipShape(Circle())
                        }
                    }
                }
            }
            .preferredColorScheme(.dark)
            .environment(\.colorScheme, .dark)
            .ignoresSafeArea()

            LinearGradient(colors: [.black.opacity(0.8), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 180)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 10) {
                // --- Search bar ---
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
                                    selectedDifficulty = nil
                                    isSearching = false
                                    Task { await mountainManager.fetchMountainsFromDatabase() }
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

                // --- Difficulty filter chips ---
                if isSearching {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            DifficultyChip(label: "All", color: .white, isSelected: selectedDifficulty == nil) {
                                selectedDifficulty = nil
                            }
                            ForEach(Difficulty.allCases, id: \.self) { diff in
                                DifficultyChip(label: diff.rawValue, color: diff.color, isSelected: selectedDifficulty == diff) {
                                    selectedDifficulty = diff
                                }
                            }
                        }
                    }
                }

                // --- Nearby toggle ---
                HStack(spacing: 12) {
                    Button(action: { withAnimation(.spring()) { showNearby.toggle() } }) {
                        HStack(spacing: 6) {
                            Image(systemName: showNearby ? "location.fill" : "location")
                                .font(.system(size: 12, weight: .bold))
                            Text("Nearby")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundColor(showNearby ? .black : .white)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(showNearby ? Color(red: 0.85, green: 0.65, blue: 0.13) : Color.white.opacity(0.15))
                        .cornerRadius(8)
                    }

                    if showNearby {
                        Picker("", selection: $nearbyRadiusKm) {
                            Text("10 km").tag(10.0)
                            Text("25 km").tag(25.0)
                            Text("50 km").tag(50.0)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 180)
                        .transition(.opacity)
                    }
                }

                // --- Result count ---
                if !isSearching {
                    Text("\(mapMountains.count) Missions loaded").font(.subheadline).foregroundColor(.green)
                } else if !searchText.isEmpty {
                    Text("\(mapMountains.count) Results found").font(.subheadline).foregroundColor(.orange)
                }
            }
            .padding(.horizontal, 20).padding(.top, 10)

            // --- Mountain detail card ---
            VStack {
                Spacer()
                if let mountain = selectedMountain {
                    MissionDetailCard(mountain: mountain, onDismiss: {
                        withAnimation(.spring()) {
                            selectedMountain = nil
                            selectedMarkerTag = nil
                        }
                    }, onCommence: {
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
            if !isSearching && !showNearby {
                zoomToClosestMountain(userLoc: newLocation)
            }
        }
        // Debounced search (300ms) on text input
        .onChange(of: searchText) { _ in
            performDebouncedSearch()
        }
        // Immediate refresh on difficulty change
        .onChange(of: selectedDifficulty) { _ in
            Task { await refreshResults() }
        }
        // Immediate refresh on nearby toggle
        .onChange(of: showNearby) { _ in
            Task { await refreshResults() }
        }
        // Debounced refresh on radius change
        .onChange(of: nearbyRadiusKm) { _ in
            performDebouncedSearch()
        }
        // Map marker selection → show detail card
        .onChange(of: selectedMarkerTag) { newTag in
            withAnimation(.spring()) {
                if let tag = newTag {
                    selectedMountain = mapMountains.first { $0.id == tag }
                } else {
                    selectedMountain = nil
                }
            }
        }
        .fullScreenCover(isPresented: $showTracker) {
            LiveRecordView(targetMountain: mountainToTrack)
        }
    }

    // --- Debounce helper ---
    private func performDebouncedSearch() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
            guard !Task.isCancelled else { return }
            await refreshResults()
        }
    }

    // --- Executes the appropriate query based on current filter state ---
    private func refreshResults() async {
        if showNearby, let loc = locationManager.userLocation {
            await mountainManager.fetchNearbyMountains(
                latitude: loc.coordinate.latitude,
                longitude: loc.coordinate.longitude,
                radiusKm: nearbyRadiusKm
            )
            await mountainManager.fetchNearbyPOIs(
                latitude: loc.coordinate.latitude,
                longitude: loc.coordinate.longitude,
                radiusKm: nearbyRadiusKm
            )
        } else {
            await mountainManager.clearNearby()
            await mountainManager.searchMountains(query: searchText, difficulty: selectedDifficulty)
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

    // --- POI icon/color helpers ---
    func poiIcon(for type: String) -> String {
        switch type {
        case "viewpoint": return "eye.fill"
        case "summit": return "mountain.2.fill"
        case "hut": return "house.fill"
        case "water": return "drop.fill"
        default: return "mappin"
        }
    }

    func poiColor(for type: String) -> Color {
        switch type {
        case "viewpoint": return .green
        case "summit": return .purple
        case "hut": return .brown
        case "water": return .blue
        default: return .gray
        }
    }
}

// =========================================
// === DIFFICULTY CHIP ===
// =========================================
struct DifficultyChip: View {
    let label: String
    var color: Color = .white
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(isSelected ? .black : .white)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(isSelected ? color : Color.white.opacity(0.15))
                .cornerRadius(8)
        }
    }
}

// =========================================
// === HILFS-VIEW: DIE MISSION CARD ===
// =========================================
struct MissionDetailCard: View {
    let mountain: Mountain
    let onDismiss: () -> Void
    let onCommence: () -> Void

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

            Button(action: {
                let impactMed = UIImpactFeedbackGenerator(style: .heavy)
                impactMed.impactOccurred()
                onCommence()
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
