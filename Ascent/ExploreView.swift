import SwiftUI
import MapKit
import CoreLocation
import Combine

// =========================================
// === DATEI: ExploreView.swift ===
// === Strava-style 3D Map with Discovery ===
// =========================================

// MARK: - Location Manager

class ExploreLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var userLocation: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        userLocation = location
        manager.stopUpdatingLocation()
    }
}

// MARK: - ExploreView

struct ExploreView: View {
    @StateObject private var mountainManager = MountainManager()
    @StateObject private var locationManager = ExploreLocationManager()

    // Map state
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var selectedMarkerTag: UUID? = nil
    @State private var selectedMountain: Mountain? = nil

    // Search state
    @FocusState private var isSearchFocused: Bool
    @State private var isSearchActive = false
    @State private var searchText = ""
    @State private var searchTask: Task<Void, Never>? = nil

    // Filter state
    @State private var selectedDifficulty: Difficulty? = nil

    // Nearby state
    @State private var showNearby = false
    @State private var nearbyRadiusKm: Double = 25

    // 3D toggle
    @State private var is3DMode = true

    // Discovery
    @State private var discoveryRegionName = ""

    // Tracker
    @State private var showTracker = false
    @State private var mountainToTrack: Mountain? = nil

    private let gold = Color(red: 0.85, green: 0.65, blue: 0.13)

    // MARK: - Computed Properties

    var mapMountains: [Mountain] {
        var source = showNearby ? mountainManager.nearbyMountains : mountainManager.mountains
        if let diff = selectedDifficulty {
            source = source.filter { $0.difficulty == diff }
        }
        return source.filter { $0.latitude != nil && $0.longitude != nil }
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {

            // === 1. FULL-SCREEN 3D MAP ===
            mapLayer

            // === 2. TOP GRADIENT ===
            LinearGradient(
                colors: [.black.opacity(0.75), .black.opacity(0.3), .clear],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 180)
            .ignoresSafeArea()
            .allowsHitTesting(false)

            // === 3. TOP CONTROLS ===
            VStack(spacing: 8) {
                searchBar
                filterChips

                if isSearchActive {
                    searchSuggestionsView
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)

            // === 4. BOTTOM: Discovery or Detail Card ===
            VStack {
                Spacer()

                if let mountain = selectedMountain {
                    detailCard(for: mountain)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else if !isSearchActive {
                    discoverySheet
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: selectedMountain?.id)

            // === 5. FLOATING MAP CONTROLS (Nearby left, 3D right) ===
            if !isSearchActive && selectedMountain == nil {
                VStack {
                    Spacer()
                    HStack(alignment: .bottom) {
                        nearbyControls
                        Spacer()
                        mapModeButton
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 280)
                }
            }

            // === 6. 3D BUTTON (always visible top-right when detail/search active) ===
            if isSearchActive || selectedMountain != nil {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        mapModeButton
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, selectedMountain != nil ? 420 : 100)
                }
            }
        }
        .task {
            await mountainManager.fetchMountainsFromDatabase()
            if let loc = locationManager.userLocation {
                flyToUserArea(location: loc)
                await reverseGeocode(loc)
            }
        }
        .onChange(of: locationManager.userLocation) { _, newLoc in
            if let loc = newLoc, selectedMountain == nil, !isSearchActive {
                flyToUserArea(location: loc)
                Task { await reverseGeocode(loc) }
            }
        }
        .onChange(of: isSearchFocused) { _, focused in
            withAnimation(.spring()) { isSearchActive = focused }
            if focused {
                // Load top suggestions immediately when search opens
                Task { await mountainManager.fetchTopMountains() }
            }
        }
        .onChange(of: searchText) { _, _ in
            performDebouncedSearch()
        }
        .onChange(of: selectedDifficulty) { _, _ in
            Task { await refreshResults() }
        }
        .onChange(of: showNearby) { _, _ in
            Task { await refreshResults() }
        }
        .onChange(of: nearbyRadiusKm) { _, _ in
            performDebouncedSearch()
        }
        .onChange(of: selectedMarkerTag) { _, newTag in
            withAnimation(.spring()) {
                if let tag = newTag {
                    selectedMountain = mapMountains.first { $0.id == tag }
                    if let m = selectedMountain, let lat = m.latitude, let lon = m.longitude {
                        flyTo(lat: lat, lon: lon, distance: 8000)
                    }
                } else {
                    selectedMountain = nil
                }
            }
        }
        .fullScreenCover(isPresented: $showTracker) {
            LiveRecordView(targetMountain: mountainToTrack)
        }
    }

    // MARK: - Map Layer

    @ViewBuilder
    var mapLayer: some View {
        Map(position: $cameraPosition, selection: $selectedMarkerTag) {
            UserAnnotation()

            ForEach(mapMountains, id: \.id) { mountain in
                if mountain.isPrestigePeak {
                    Marker(
                        mountain.name,
                        systemImage: "crown.fill",
                        coordinate: CLLocationCoordinate2D(
                            latitude: mountain.latitude!,
                            longitude: mountain.longitude!
                        )
                    )
                    .tint(gold)
                    .tag(mountain.id)
                } else {
                    Marker(
                        mountain.name,
                        coordinate: CLLocationCoordinate2D(
                            latitude: mountain.latitude!,
                            longitude: mountain.longitude!
                        )
                    )
                    .tint(difficultyColor(mountain.difficulty))
                    .tag(mountain.id)
                }
            }

            // POI annotations in nearby mode
            if showNearby {
                ForEach(mountainManager.nearbyPOIs) { poi in
                    Annotation(poi.name, coordinate: CLLocationCoordinate2D(
                        latitude: poi.latitude, longitude: poi.longitude
                    )) {
                        Image(systemName: poiIcon(for: poi.type))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 26, height: 26)
                            .background(poiColor(for: poi.type))
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                    }
                }
            }
        }
        .mapStyle(.hybrid(elevation: is3DMode ? .realistic : .flat))
        .ignoresSafeArea()
    }

    // MARK: - Search Bar (Frosted Glass)

    @ViewBuilder
    var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
                .font(.system(size: 16, weight: .medium))

            TextField("Search peaks or regions…", text: $searchText)
                .focused($isSearchFocused)
                .foregroundColor(.white)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            if isSearchActive || !searchText.isEmpty {
                Button {
                    withAnimation(.spring()) {
                        searchText = ""
                        isSearchFocused = false
                        isSearchActive = false
                        selectedDifficulty = nil
                    }
                    Task { await mountainManager.fetchMountainsFromDatabase() }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
        )
    }

    // MARK: - Filter Chips

    @ViewBuilder
    var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                DifficultyChip(label: "All", color: gold, isSelected: selectedDifficulty == nil) {
                    selectedDifficulty = nil
                }
                ForEach(Difficulty.allCases, id: \.self) { diff in
                    DifficultyChip(
                        label: diff.rawValue,
                        color: difficultyColor(diff),
                        isSelected: selectedDifficulty == diff
                    ) {
                        selectedDifficulty = diff
                    }
                }
            }
        }
    }

    // MARK: - Search Suggestions Dropdown

    @ViewBuilder
    var searchSuggestionsView: some View {
        let suggestions = Array(mapMountains.prefix(10))

        VStack(spacing: 0) {
            // Result count header
            if !searchText.isEmpty {
                HStack {
                    Text("\(mapMountains.count) results")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.gray)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.03))
            } else {
                HStack {
                    Text("Top Peaks")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(gold)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.03))
            }

            if suggestions.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "mountain.2")
                        .font(.title2).foregroundColor(.gray.opacity(0.4))
                    Text("No peaks found")
                        .font(.caption).foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, mountain in
                            Button { selectMountain(mountain) } label: {
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(difficultyColor(mountain.difficulty))
                                        .frame(width: 8, height: 8)

                                    Image(systemName: mountain.isPrestigePeak ? "crown.fill" : "mountain.2.fill")
                                        .foregroundColor(mountain.isPrestigePeak ? gold : .gray)
                                        .frame(width: 20)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(mountain.name)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.white)
                                        Text("\(mountain.region) · \(mountain.elevation)m")
                                            .font(.system(size: 11))
                                            .foregroundColor(.gray)
                                    }

                                    Spacer()

                                    Text(mountain.difficulty.rawValue)
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(difficultyColor(mountain.difficulty))
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                            }
                            if index < suggestions.count - 1 {
                                Divider().background(Color.white.opacity(0.06))
                            }
                        }
                    }
                }
                .frame(maxHeight: 320)
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        )
    }

    // MARK: - Nearby Controls

    @ViewBuilder
    var nearbyControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.spring()) { showNearby.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: showNearby ? "location.fill" : "location")
                        .font(.system(size: 12, weight: .bold))
                    Text("Nearby")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(showNearby ? .black : .white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(showNearby ? gold : Color.black.opacity(0.7))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(showNearby ? 0 : 0.2), lineWidth: 0.5)
                )
            }

            if showNearby {
                HStack(spacing: 6) {
                    ForEach([10.0, 25.0, 50.0], id: \.self) { radius in
                        Button {
                            nearbyRadiusKm = radius
                        } label: {
                            Text("\(Int(radius))km")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(nearbyRadiusKm == radius ? .black : .white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(nearbyRadiusKm == radius ? gold : Color.black.opacity(0.7))
                                .clipShape(Capsule())
                        }
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
    }

    // MARK: - 2D / 3D Toggle

    @ViewBuilder
    var mapModeButton: some View {
        Button {
            withAnimation(.spring()) {
                is3DMode.toggle()
                // Re-apply current camera with new pitch
                if let loc = locationManager.userLocation {
                    let coord = cameraPosition.camera?.centerCoordinate ?? loc.coordinate
                    let dist = cameraPosition.camera?.distance ?? 30000
                    cameraPosition = .camera(MapCamera(
                        centerCoordinate: coord,
                        distance: dist,
                        heading: 0,
                        pitch: is3DMode ? 45 : 0
                    ))
                }
            }
        } label: {
            Text(is3DMode ? "2D" : "3D")
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundColor(is3DMode ? .white : .black)
                .frame(width: 44, height: 44)
                .background(is3DMode ? Color.black.opacity(0.7) : gold)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(is3DMode ? 0.2 : 0), lineWidth: 0.5)
                )
        }
    }

    // MARK: - Discovery Sheet (Bottom Cards)

    @ViewBuilder
    var discoverySheet: some View {
        let cards = Array(mapMountains.prefix(12))
        if !cards.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Discover \(discoveryRegionName.isEmpty ? "Nearby" : discoveryRegionName)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        Spacer().frame(width: 6)
                        ForEach(cards, id: \.id) { mountain in
                            ExploreDiscoveryCard(
                                mountain: mountain,
                                userLocation: locationManager.userLocation
                            ) {
                                selectMountain(mountain)
                            }
                        }
                        Spacer().frame(width: 6)
                    }
                }
            }
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.8), .black.opacity(0.95)],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .padding(.bottom, 90)
        }
    }

    // MARK: - Detail Card (Bottom Sheet)

    @ViewBuilder
    func detailCard(for mountain: Mountain) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // === Image Header ===
            ZStack(alignment: .topTrailing) {
                if let urlStr = mountain.imageUrl, !urlStr.isEmpty, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        if let img = phase.image {
                            img.resizable().scaledToFill()
                        } else {
                            goldGradientPlaceholder
                        }
                    }
                    .frame(height: 150)
                    .clipped()
                } else {
                    goldGradientPlaceholder
                        .frame(height: 150)
                }

                LinearGradient(
                    colors: [.clear, Color(red: 0.08, green: 0.08, blue: 0.1)],
                    startPoint: .center, endPoint: .bottom
                )

                // Close button
                Button {
                    withAnimation(.spring()) {
                        selectedMountain = nil
                        selectedMarkerTag = nil
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.white.opacity(0.7), .black.opacity(0.4))
                }
                .padding(12)
            }

            // === Content ===
            VStack(alignment: .leading, spacing: 14) {
                // Title row
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(mountain.name)
                            .font(.title2).fontWeight(.bold).foregroundColor(.white)
                        Text("\(mountain.region), \(mountain.country)")
                            .font(.subheadline).foregroundColor(.gray)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(mountain.difficulty.rawValue.uppercased())
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(.black)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(difficultyColor(mountain.difficulty))
                            .clipShape(Capsule())

                        if mountain.isPrestigePeak {
                            HStack(spacing: 3) {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 8))
                                Text("PRESTIGE")
                                    .font(.system(size: 8, weight: .black))
                            }
                            .foregroundColor(gold)
                        }
                    }
                }

                // Stats row
                HStack(spacing: 0) {
                    DetailStat(icon: "arrow.up.right", value: "\(mountain.elevation)m", label: "Elevation")
                    DetailStat(icon: "chart.line.uptrend.xyaxis", value: "~\(mountain.elevation / 2)m", label: "Est. Gain")
                    DetailStat(icon: "clock", value: estimatedDuration(for: mountain), label: "Est. Time")
                    if let userLoc = locationManager.userLocation,
                       let lat = mountain.latitude, let lon = mountain.longitude {
                        let dist = userLoc.distance(from: CLLocation(latitude: lat, longitude: lon)) / 1000
                        DetailStat(icon: "location", value: String(format: "%.0fkm", dist), label: "Away")
                    }
                }

                // Description
                if !mountain.description.isEmpty {
                    Text(mountain.description)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }

                // Commence Mission button
                Button {
                    HapticManager.shared.heavy()
                    mountainToTrack = mountain
                    showTracker = true
                } label: {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Commence Mission")
                    }
                    .font(.headline).fontWeight(.bold)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(gold)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                // Thumbnail row
                if let urlStr = mountain.imageUrl, !urlStr.isEmpty, let url = URL(string: urlStr) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(0..<3, id: \.self) { _ in
                                AsyncImage(url: url) { phase in
                                    if let img = phase.image {
                                        img.resizable().scaledToFill()
                                    } else {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.white.opacity(0.05))
                                    }
                                }
                                .frame(width: 80, height: 55)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(Color(red: 0.08, green: 0.08, blue: 0.1))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.5), radius: 20, y: -5)
        .padding(.horizontal, 12)
        .padding(.bottom, 100)
    }

    // MARK: - Helpers

    @ViewBuilder
    var goldGradientPlaceholder: some View {
        LinearGradient(
            colors: [gold.opacity(0.3), Color(red: 0.08, green: 0.08, blue: 0.1)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        .overlay(
            Image(systemName: "mountain.2.fill")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.1))
        )
    }

    func difficultyColor(_ diff: Difficulty) -> Color {
        switch diff {
        case .easy: return .green
        case .medium: return .yellow
        case .hard: return .orange
        case .extreme: return .red
        }
    }

    func estimatedDuration(for mountain: Mountain) -> String {
        let hours = Double(mountain.elevation) / 800.0
        if hours < 1 { return "\(Int(hours * 60))min" }
        return String(format: "%.0f-%.0fh", hours, hours * 1.3)
    }

    func poiIcon(for type: String) -> String {
        switch type {
        case "viewpoint": return "eye.fill"
        case "hut":       return "house.fill"
        case "water":     return "drop.fill"
        case "summit":    return "mountain.2.fill"
        default:          return "mappin"
        }
    }

    func poiColor(for type: String) -> Color {
        switch type {
        case "viewpoint": return .green
        case "hut":       return .brown
        case "water":     return .blue
        case "summit":    return .purple
        default:          return .gray
        }
    }

    func selectMountain(_ mountain: Mountain) {
        withAnimation(.spring()) {
            selectedMountain = mountain
            selectedMarkerTag = mountain.id
            isSearchFocused = false
            isSearchActive = false
            searchText = ""
        }
        if let lat = mountain.latitude, let lon = mountain.longitude {
            flyTo(lat: lat, lon: lon, distance: 8000)
        }
    }

    func flyTo(lat: Double, lon: Double, distance: Double) {
        withAnimation(.easeInOut(duration: 1.5)) {
            cameraPosition = .camera(MapCamera(
                centerCoordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                distance: distance,
                heading: 0,
                pitch: is3DMode ? 45 : 0
            ))
        }
    }

    func flyToUserArea(location: CLLocation) {
        let mountains = mapMountains
        guard !mountains.isEmpty else {
            withAnimation(.easeInOut(duration: 2.0)) {
                cameraPosition = .camera(MapCamera(
                    centerCoordinate: location.coordinate,
                    distance: 50000, heading: 0, pitch: 45
                ))
            }
            return
        }

        if let closest = mountains.min(by: {
            let l1 = CLLocation(latitude: $0.latitude!, longitude: $0.longitude!)
            let l2 = CLLocation(latitude: $1.latitude!, longitude: $1.longitude!)
            return location.distance(from: l1) < location.distance(from: l2)
        }), let lat = closest.latitude, let lon = closest.longitude {
            let midLat = (location.coordinate.latitude + lat) / 2
            let midLon = (location.coordinate.longitude + lon) / 2
            let dist = location.distance(from: CLLocation(latitude: lat, longitude: lon))

            withAnimation(.easeInOut(duration: 2.0)) {
                cameraPosition = .camera(MapCamera(
                    centerCoordinate: CLLocationCoordinate2D(latitude: midLat, longitude: midLon),
                    distance: max(dist * 3, 30000),
                    heading: 0,
                    pitch: 45
                ))
            }
        }
    }

    // 300ms debounce for search and radius inputs
    func performDebouncedSearch() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await refreshResults()
        }
    }

    func refreshResults() async {
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
        } else if !searchText.isEmpty || selectedDifficulty != nil {
            await mountainManager.searchMountains(query: searchText, difficulty: selectedDifficulty)
        } else {
            await mountainManager.clearNearby()
            await mountainManager.fetchMountainsFromDatabase()
        }
    }

    func reverseGeocode(_ location: CLLocation) async {
        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let p = placemarks.first {
                discoveryRegionName = p.locality ?? p.administrativeArea ?? p.country ?? ""
            }
        } catch {
            print("⚠️ Geocoding error: \(error)")
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
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? color : Color.white.opacity(0.15))
                .cornerRadius(8)
        }
    }
}

// =========================================
// === DISCOVERY CARD (matches app style) ===
// =========================================

struct ExploreDiscoveryCard: View {
    let mountain: Mountain
    let userLocation: CLLocation?
    let onTap: () -> Void

    @State private var isPressed = false
    private let gold = Color(red: 0.85, green: 0.65, blue: 0.13)

    private var distanceText: String? {
        guard let loc = userLocation,
              let lat = mountain.latitude,
              let lon = mountain.longitude else { return nil }
        let d = loc.distance(from: CLLocation(latitude: lat, longitude: lon)) / 1000
        return String(format: "%.0f km", d)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Mountain photo or gradient placeholder
                if let urlString = mountain.imageUrl, !urlString.isEmpty, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(LinearGradient(colors: [gold.opacity(0.15), Color(red: 0.12, green: 0.12, blue: 0.15)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .overlay(ProgressView().tint(.white).scaleEffect(0.7))
                        }
                    }
                    .frame(width: 185, height: 90).clipped().cornerRadius(10)
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(LinearGradient(colors: [gold.opacity(0.15), Color(red: 0.12, green: 0.12, blue: 0.15)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 185, height: 90)
                        .overlay(
                            Image(systemName: "mountain.2.fill").font(.title2).foregroundColor(.white.opacity(0.2))
                        )
                }

                Text(mountain.name)
                    .font(.subheadline).fontWeight(.bold).foregroundColor(.white)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text("\(mountain.elevation)m").font(.caption2).foregroundColor(.gray)
                    Text("·").foregroundColor(.gray)
                    Text(mountain.region).font(.caption2).foregroundColor(.gray).lineLimit(1)
                    Spacer()
                    Text(mountain.difficulty.rawValue.uppercased())
                        .font(.system(size: 8, weight: .black))
                        .foregroundColor(.black)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(mountain.difficulty.color)
                        .cornerRadius(3)
                }

                HStack(spacing: 6) {
                    if mountain.isPrestigePeak {
                        HStack(spacing: 4) {
                            Image(systemName: "crown.fill").font(.system(size: 8)).foregroundColor(gold)
                            Text("PRESTIGE").font(.system(size: 8, weight: .black)).foregroundColor(gold).tracking(0.5)
                        }
                    }
                    Spacer()
                    if let dist = distanceText {
                        HStack(spacing: 3) {
                            Image(systemName: "location.fill").font(.system(size: 7))
                            Text(dist).font(.system(size: 9, weight: .semibold))
                        }
                        .foregroundColor(gold.opacity(0.8))
                    }
                }
            }
            .padding(10)
            .frame(width: 205)
            .background(Color(red: 0.12, green: 0.12, blue: 0.15))
            .cornerRadius(16)
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

// =========================================
// === DETAIL STAT ===
// =========================================

struct DetailStat: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.gray)
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
}
