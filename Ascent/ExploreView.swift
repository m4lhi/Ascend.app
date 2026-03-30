import SwiftUI
import MapKit
import CoreLocation
import Combine

// =========================================
// === DATEI: ExploreView.swift ===
// === 3D Terrain Map with Discovery ===
// =========================================

// MARK: - Location Manager

class ExploreLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var userLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

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

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        authorizationStatus = status
    }

    func requestLocation() {
        manager.requestLocation()
        manager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("⚠️ Location error: \(error.localizedDescription)")
    }
}

// MARK: - Map Layer Type

enum MapLayerType: String, CaseIterable, Identifiable {
    case standard = "Standard"
    case satellite = "Satellite"
    case terrain = "Terrain"
    case night = "Night"
    case elevation = "Elevation"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .standard:  return "map"
        case .satellite: return "globe.americas.fill"
        case .terrain:   return "mountain.2.fill"
        case .night:     return "moon.stars.fill"
        case .elevation: return "chart.bar.fill"
        }
    }

    var subtitle: String {
        switch self {
        case .standard:  return "Default map"
        case .satellite: return "Hybrid with labels"
        case .terrain:   return "Elevation emphasis"
        case .night:     return "Dark map style"
        case .elevation: return "Color-coded height"
        }
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
    @State private var showRoutesFilter = false

    // Nearby state
    @State private var showNearby = false
    @State private var nearbyRadiusKm: Double = 25

    // 3D toggle
    @State private var is3DMode = true

    // Map layers
    @State private var currentMapLayer: MapLayerType = .satellite
    @State private var showLayersSheet = false

    // My Location
    @State private var showLocationDeniedAlert = false

    // Route creation mode
    @State private var isRouteCreationMode = false
    @State private var routeMountains: [Mountain] = []
    @State private var routeName = ""

    // Discovery sheet
    @State private var discoverySheetExpanded = false

    // Zoom-based marker visibility
    @State private var currentZoomLevel: ZoomLevel = .medium

    // Discovery
    @State private var discoveryRegionName = ""

    // Tracker
    @State private var showTracker = false
    @State private var mountainToTrack: Mountain? = nil

    // Selected route to show on map
    @State private var selectedRouteToShow: NearbyRoute? = nil

    private let gold = Color(red: 0.85, green: 0.65, blue: 0.13)

    enum ZoomLevel {
        case far, medium, close
    }

    // MARK: - Computed Properties

    var mapMountains: [Mountain] {
        var source = showNearby ? mountainManager.nearbyMountains : mountainManager.mountains
        if let diff = selectedDifficulty {
            source = source.filter { $0.difficulty == diff }
        }
        return source.filter { $0.latitude != nil && $0.longitude != nil }
    }

    var visibleMountains: [Mountain] {
        switch currentZoomLevel {
        case .far:    return Array(mapMountains.filter { $0.isPrestigePeak }.prefix(20))
        case .medium: return Array(mapMountains.prefix(50))
        case .close:  return Array(mapMountains.prefix(80))
        }
    }

    var showPOIs: Bool { showNearby && currentZoomLevel == .close }

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
            .frame(height: 200)
            .ignoresSafeArea()
            .allowsHitTesting(false)

            // === 3. TOP CONTROLS ===
            VStack(spacing: 8) {
                searchBar
                toolbarRow
                filterChips

                if isSearchActive {
                    searchSuggestionsView
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)

            // === 4. ROUTE CREATION PANEL ===
            if isRouteCreationMode {
                VStack {
                    Spacer()
                    routeCreationPanel
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            // === 5. BOTTOM: Detail Card or Discovery Sheet ===
            else {
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
            }
        }
        .task {
            await mountainManager.fetchMountainsFromDatabase()
            await mountainManager.fetchSavedRoutes()
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
                Task { await mountainManager.fetchTopMountains() }
            }
        }
        .onChange(of: searchText) { _, _ in performDebouncedSearch() }
        .onChange(of: selectedDifficulty) { _, _ in Task { await refreshResults() } }
        .onChange(of: showNearby) { _, _ in Task { await refreshResults() } }
        .onChange(of: nearbyRadiusKm) { _, _ in performDebouncedSearch() }
        .onChange(of: selectedMarkerTag) { _, newTag in
            withAnimation(.spring()) {
                if let tag = newTag {
                    if isRouteCreationMode {
                        // Add mountain to route
                        if let mountain = mapMountains.first(where: { $0.id == tag }) {
                            if !routeMountains.contains(where: { $0.id == mountain.id }) {
                                routeMountains.append(mountain)
                                HapticManager.shared.medium()
                            }
                        }
                        selectedMarkerTag = nil
                    } else {
                        selectedMountain = mapMountains.first { $0.id == tag }
                        if let m = selectedMountain, let lat = m.latitude, let lon = m.longitude {
                            flyToMountain(lat: lat, lon: lon)
                        }
                    }
                } else {
                    selectedMountain = nil
                }
            }
        }
        .fullScreenCover(isPresented: $showTracker) {
            LiveRecordView(targetMountain: mountainToTrack)
        }
        .sheet(isPresented: $showLayersSheet) {
            layersSheet
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .alert("Location Access Needed", isPresented: $showLocationDeniedAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Location access is needed to show your position on the map and find nearby mountains. Please enable it in Settings.")
        }
    }

    // MARK: - Map Layer

    @ViewBuilder
    var mapLayer: some View {
        Map(position: $cameraPosition, selection: $selectedMarkerTag) {
            UserAnnotation()

            // Mountain markers
            ForEach(visibleMountains, id: \.id) { mountain in
                if isRouteCreationMode {
                    let index = routeMountains.firstIndex(where: { $0.id == mountain.id })
                    if let idx = index {
                        // Numbered marker for mountains in current route
                        Annotation("\(idx + 1)", coordinate: CLLocationCoordinate2D(
                            latitude: mountain.latitude!, longitude: mountain.longitude!
                        )) {
                            ZStack {
                                Circle()
                                    .fill(gold)
                                    .frame(width: 32, height: 32)
                                Text("\(idx + 1)")
                                    .font(.system(size: 14, weight: .black))
                                    .foregroundColor(.black)
                            }
                            .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                        }
                        .tag(mountain.id)
                    } else {
                        Marker(
                            mountain.name,
                            systemImage: "plus.circle.fill",
                            coordinate: CLLocationCoordinate2D(
                                latitude: mountain.latitude!, longitude: mountain.longitude!
                            )
                        )
                        .tint(.white.opacity(0.7))
                        .tag(mountain.id)
                    }
                } else if mountain.isPrestigePeak {
                    Marker(
                        mountain.name,
                        systemImage: "crown.fill",
                        coordinate: CLLocationCoordinate2D(
                            latitude: mountain.latitude!, longitude: mountain.longitude!
                        )
                    )
                    .tint(gold)
                    .tag(mountain.id)
                } else {
                    Marker(
                        mountain.name,
                        systemImage: "mountain.2.fill",
                        coordinate: CLLocationCoordinate2D(
                            latitude: mountain.latitude!, longitude: mountain.longitude!
                        )
                    )
                    .tint(difficultyColor(mountain.difficulty))
                    .tag(mountain.id)
                }
            }

            // Route creation polyline
            if isRouteCreationMode && routeMountains.count >= 2 {
                let coords = routeMountains.compactMap { m -> CLLocationCoordinate2D? in
                    guard let lat = m.latitude, let lon = m.longitude else { return nil }
                    return CLLocationCoordinate2D(latitude: lat, longitude: lon)
                }
                MapPolyline(coordinates: coords)
                    .stroke(gold, lineWidth: 3)
            }

            // Show selected route polyline
            if let route = selectedRouteToShow {
                let coords = route.mountains.compactMap { m -> CLLocationCoordinate2D? in
                    guard let lat = m.latitude, let lon = m.longitude else { return nil }
                    return CLLocationCoordinate2D(latitude: lat, longitude: lon)
                }
                MapPolyline(coordinates: coords)
                    .stroke(gold, lineWidth: 3)
            }

            // POI annotations
            if showPOIs {
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
        .mapStyle(mapStyleForCurrentLayer)
        .onMapCameraChange(frequency: .onEnd) { context in
            let span = context.region.span
            let spanKm = span.latitudeDelta * 111
            withAnimation(.easeInOut(duration: 0.2)) {
                if spanKm > 100 {
                    currentZoomLevel = .far
                } else if spanKm > 20 {
                    currentZoomLevel = .medium
                } else {
                    currentZoomLevel = .close
                }
            }
        }
        .ignoresSafeArea()
        .overlay(alignment: .center) {
            // Elevation color overlay
            if currentMapLayer == .elevation {
                elevationOverlay
            }
        }
    }

    var mapStyleForCurrentLayer: MapStyle {
        switch currentMapLayer {
        case .standard:
            return .standard(elevation: is3DMode ? .realistic : .flat)
        case .satellite:
            return .hybrid(elevation: is3DMode ? .realistic : .flat)
        case .terrain:
            return .standard(elevation: .realistic)
        case .night:
            return .standard(elevation: is3DMode ? .realistic : .flat)
        case .elevation:
            return .hybrid(elevation: is3DMode ? .realistic : .flat)
        }
    }

    @ViewBuilder
    var elevationOverlay: some View {
        LinearGradient(
            stops: [
                .init(color: .green.opacity(0.15), location: 0.0),
                .init(color: .yellow.opacity(0.12), location: 0.3),
                .init(color: .orange.opacity(0.12), location: 0.6),
                .init(color: .red.opacity(0.15), location: 1.0)
            ],
            startPoint: .bottom,
            endPoint: .top
        )
        .allowsHitTesting(false)
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

    // MARK: - Top Toolbar (below search bar)

    @ViewBuilder
    var toolbarRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Nearby button
                ToolbarButton(
                    icon: showNearby ? "location.fill" : "location",
                    label: "Nearby",
                    isActive: showNearby
                ) {
                    withAnimation(.spring()) { showNearby.toggle() }
                }

                // Nearby radius pills (shown when nearby is active)
                if showNearby {
                    ForEach([10.0, 25.0, 50.0], id: \.self) { radius in
                        Button {
                            nearbyRadiusKm = radius
                        } label: {
                            Text("\(Int(radius))km")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(nearbyRadiusKm == radius ? .black : .white.opacity(0.7))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(nearbyRadiusKm == radius ? gold : Color.white.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                }

                // 2D/3D toggle
                ToolbarButton(
                    icon: is3DMode ? "view.3d" : "view.2d",
                    label: is3DMode ? "3D" : "2D",
                    isActive: is3DMode
                ) {
                    withAnimation(.spring()) {
                        is3DMode.toggle()
                        if let loc = locationManager.userLocation {
                            let coord = cameraPosition.camera?.centerCoordinate ?? loc.coordinate
                            let dist = cameraPosition.camera?.distance ?? 15000
                            cameraPosition = .camera(MapCamera(
                                centerCoordinate: coord,
                                distance: dist,
                                heading: 0,
                                pitch: is3DMode ? 60 : 0
                            ))
                        }
                    }
                }

                // Layers button
                ToolbarButton(icon: "square.3.layers.3d", label: "Layers", isActive: false) {
                    showLayersSheet = true
                }

                // My Location button
                ToolbarButton(icon: "location.fill", label: "My Loc", isActive: false) {
                    flyToMyLocation()
                }

                // Route creation button
                ToolbarButton(
                    icon: isRouteCreationMode ? "xmark" : "pencil.line",
                    label: isRouteCreationMode ? "Cancel" : "Route",
                    isActive: isRouteCreationMode
                ) {
                    withAnimation(.spring()) {
                        if isRouteCreationMode {
                            isRouteCreationMode = false
                            routeMountains = []
                            routeName = ""
                        } else {
                            isRouteCreationMode = true
                            selectedMountain = nil
                            selectedMarkerTag = nil
                        }
                    }
                }
            }
        }
    }

    // MARK: - Filter Chips

    @ViewBuilder
    var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                DifficultyChip(label: "All", color: gold, isSelected: selectedDifficulty == nil && !showRoutesFilter) {
                    selectedDifficulty = nil
                    showRoutesFilter = false
                }
                ForEach(Difficulty.allCases, id: \.self) { diff in
                    DifficultyChip(
                        label: diff.rawValue,
                        color: difficultyColor(diff),
                        isSelected: selectedDifficulty == diff
                    ) {
                        selectedDifficulty = diff
                        showRoutesFilter = false
                    }
                }
                DifficultyChip(label: "Routes", color: .cyan, isSelected: showRoutesFilter) {
                    showRoutesFilter.toggle()
                    if showRoutesFilter { selectedDifficulty = nil }
                }
            }
        }
    }

    // MARK: - Search Suggestions

    @ViewBuilder
    var searchSuggestionsView: some View {
        let suggestions = Array(mapMountains.prefix(10))

        VStack(spacing: 0) {
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

    // MARK: - Layers Sheet

    @ViewBuilder
    var layersSheet: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                    ForEach(MapLayerType.allCases) { layer in
                        Button {
                            withAnimation(.spring()) {
                                currentMapLayer = layer
                            }
                            showLayersSheet = false
                        } label: {
                            VStack(spacing: 8) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(layerPreviewColor(layer))
                                        .frame(height: 80)

                                    Image(systemName: layer.icon)
                                        .font(.system(size: 28))
                                        .foregroundColor(.white)
                                }
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(currentMapLayer == layer ? gold : Color.clear, lineWidth: 2)
                                )

                                Text(layer.rawValue)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(currentMapLayer == layer ? gold : .white)

                                Text(layer.subtitle)
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(Color(red: 0.08, green: 0.08, blue: 0.1))
            .navigationTitle("Map Layers")
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
    }

    func layerPreviewColor(_ layer: MapLayerType) -> LinearGradient {
        switch layer {
        case .standard:
            return LinearGradient(colors: [.gray.opacity(0.3), .gray.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .satellite:
            return LinearGradient(colors: [.green.opacity(0.3), .blue.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .terrain:
            return LinearGradient(colors: [.brown.opacity(0.3), .green.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .night:
            return LinearGradient(colors: [.indigo.opacity(0.4), .black.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .elevation:
            return LinearGradient(colors: [.green.opacity(0.3), .red.opacity(0.3)], startPoint: .bottom, endPoint: .top)
        }
    }

    // MARK: - Route Creation Panel

    @ViewBuilder
    var routeCreationPanel: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Image(systemName: "pencil.line")
                    .foregroundColor(gold)
                Text("Route Creator")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text("\(routeMountains.count) peaks")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(gold)
            }

            // Route name field
            TextField("Route name…", text: $routeName)
                .textFieldStyle(.plain)
                .padding(10)
                .background(Color.white.opacity(0.08))
                .cornerRadius(10)
                .foregroundColor(.white)

            // Selected mountains list
            if !routeMountains.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(routeMountains.enumerated()), id: \.element.id) { index, mountain in
                            HStack(spacing: 4) {
                                Text("\(index + 1)")
                                    .font(.system(size: 10, weight: .black))
                                    .foregroundColor(.black)
                                    .frame(width: 18, height: 18)
                                    .background(gold)
                                    .clipShape(Circle())
                                Text(mountain.name)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Button {
                                    routeMountains.removeAll { $0.id == mountain.id }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }
            }

            // Route stats
            if routeMountains.count >= 2 {
                let stats = calculateRouteStats(routeMountains)
                HStack(spacing: 0) {
                    DetailStat(icon: "point.topleft.down.to.point.bottomright.curvepath", value: String(format: "%.1fkm", stats.distance), label: "Distance")
                    DetailStat(icon: "arrow.up.right", value: "\(stats.elevation)m", label: "Elevation")
                    DetailStat(icon: "clock", value: "\(stats.durationMin)min", label: "Est. Time")
                    DetailStat(icon: "mountain.2.fill", value: "\(routeMountains.count)", label: "Peaks")
                }
            }

            // Buttons
            HStack(spacing: 12) {
                Button {
                    withAnimation(.spring()) {
                        isRouteCreationMode = false
                        routeMountains = []
                        routeName = ""
                    }
                } label: {
                    Text("Cancel")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(12)
                }

                Button {
                    saveCreatedRoute()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                        Text("Save Route")
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(routeMountains.count >= 2 ? gold : gold.opacity(0.3))
                    .cornerRadius(12)
                }
                .disabled(routeMountains.count < 2)
            }

            Text("Tap mountain markers to add them to your route")
                .font(.system(size: 10))
                .foregroundColor(.gray)
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(gold.opacity(0.3), lineWidth: 0.5)
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 100)
    }

    // MARK: - Discovery Sheet (3 sections)

    @ViewBuilder
    var discoverySheet: some View {
        let nearbyCards = Array(mapMountains.prefix(10))
        let routes = mountainManager.nearbyRoutes
        let savedRoutes = mountainManager.savedRoutes

        VStack(alignment: .leading, spacing: 0) {
            // Drag handle
            HStack {
                Spacer()
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 36, height: 4)
                Spacer()
            }
            .padding(.top, 8)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring()) { discoverySheetExpanded.toggle() }
            }

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {

                    // SECTION 1: Nearby Missions
                    if !nearbyCards.isEmpty && !showRoutesFilter {
                        discoverySectionHeader(title: "Nearby Missions", icon: "mountain.2.fill")

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                Spacer().frame(width: 6)
                                ForEach(nearbyCards, id: \.id) { mountain in
                                    ExploreDiscoveryCard(
                                        mountain: mountain,
                                        userLocation: locationManager.userLocation,
                                        compact: true
                                    ) {
                                        selectMountain(mountain)
                                    }
                                }
                                Spacer().frame(width: 6)
                            }
                        }
                    }

                    // SECTION 2: Nearby Routes
                    if !routes.isEmpty || showRoutesFilter {
                        discoverySectionHeader(title: "Nearby Routes", icon: "point.topleft.down.to.point.bottomright.curvepath")

                        if routes.isEmpty {
                            HStack {
                                Spacer()
                                VStack(spacing: 6) {
                                    Image(systemName: "map.fill")
                                        .font(.title2).foregroundColor(.gray.opacity(0.4))
                                    Text("Enable Nearby to see routes")
                                        .font(.caption).foregroundColor(.gray)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 16)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    Spacer().frame(width: 6)
                                    ForEach(routes) { route in
                                        RouteCard(route: route) {
                                            withAnimation(.spring()) {
                                                selectedRouteToShow = route
                                                // Zoom to fit route
                                                if let first = route.mountains.first,
                                                   let lat = first.latitude, let lon = first.longitude {
                                                    flyTo(lat: lat, lon: lon, distance: 12000)
                                                }
                                            }
                                        }
                                    }
                                    Spacer().frame(width: 6)
                                }
                            }
                        }
                    }

                    // SECTION 3: My Routes
                    if discoverySheetExpanded || showRoutesFilter {
                        discoverySectionHeader(title: "My Routes", icon: "bookmark.fill")

                        if savedRoutes.isEmpty {
                            HStack {
                                Spacer()
                                VStack(spacing: 6) {
                                    Image(systemName: "map")
                                        .font(.title2).foregroundColor(.gray.opacity(0.3))
                                    Text("No saved routes yet. Create your first route!")
                                        .font(.caption).foregroundColor(.gray)
                                        .multilineTextAlignment(.center)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 16)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    Spacer().frame(width: 6)
                                    ForEach(savedRoutes) { route in
                                        SavedRouteCard(route: route) {
                                            // Show saved route on map
                                            showSavedRouteOnMap(route)
                                        } onDelete: {
                                            Task { await mountainManager.deleteRoute(id: route.id) }
                                        }
                                    }
                                    Spacer().frame(width: 6)
                                }
                            }
                        }
                    }
                }
                .padding(.top, 4)
                .padding(.bottom, 8)
            }
            .frame(maxHeight: discoverySheetExpanded ? 400 : 180)
        }
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.7), .black.opacity(0.9)],
                startPoint: .top, endPoint: .bottom
            )
            .background(.ultraThinMaterial.opacity(0.5))
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.bottom, 90)
    }

    @ViewBuilder
    func discoverySectionHeader(title: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(gold)
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
            Spacer()
            if !discoverySheetExpanded {
                Button {
                    withAnimation(.spring()) { discoverySheetExpanded = true }
                } label: {
                    Text("See All")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(gold)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Detail Card

    @ViewBuilder
    func detailCard(for mountain: Mountain) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image Header
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

                Button {
                    withAnimation(.spring()) {
                        selectedMountain = nil
                        selectedMarkerTag = nil
                        selectedRouteToShow = nil
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.white.opacity(0.7), .black.opacity(0.4))
                }
                .padding(12)
            }

            VStack(alignment: .leading, spacing: 14) {
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
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(difficultyColor(mountain.difficulty))
                            .clipShape(Capsule())

                        if mountain.isPrestigePeak {
                            HStack(spacing: 3) {
                                Image(systemName: "crown.fill").font(.system(size: 8))
                                Text("PRESTIGE").font(.system(size: 8, weight: .black))
                            }
                            .foregroundColor(gold)
                        }
                    }
                }

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

                if !mountain.description.isEmpty {
                    Text(mountain.description)
                        .font(.caption).foregroundColor(.gray).lineLimit(2)
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

                if let photographer = mountain.photographer_name, !photographer.isEmpty {
                    Text("Photo: \(photographer)")
                        .font(.system(size: 9)).foregroundColor(.gray.opacity(0.6))
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
            selectedRouteToShow = nil
        }
        if let lat = mountain.latitude, let lon = mountain.longitude {
            flyToMountain(lat: lat, lon: lon)
        }
    }

    func flyToMountain(lat: Double, lon: Double) {
        // Calculate bearing from user to mountain
        var heading: Double = 0
        if let userLoc = locationManager.userLocation {
            heading = bearingBetween(
                lat1: userLoc.coordinate.latitude, lon1: userLoc.coordinate.longitude,
                lat2: lat, lon2: lon
            )
        }
        withAnimation(.easeInOut(duration: 1.5)) {
            cameraPosition = .camera(MapCamera(
                centerCoordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                distance: 8000,
                heading: heading,
                pitch: is3DMode ? 65 : 0
            ))
        }
    }

    func flyTo(lat: Double, lon: Double, distance: Double) {
        withAnimation(.easeInOut(duration: 1.5)) {
            cameraPosition = .camera(MapCamera(
                centerCoordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                distance: distance,
                heading: 0,
                pitch: is3DMode ? 60 : 0
            ))
        }
    }

    func flyToUserArea(location: CLLocation) {
        let mountains = mapMountains
        guard !mountains.isEmpty else {
            withAnimation(.easeInOut(duration: 2.0)) {
                cameraPosition = .camera(MapCamera(
                    centerCoordinate: location.coordinate,
                    distance: 15000, heading: 0, pitch: is3DMode ? 60 : 0
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
                    distance: max(dist * 3, 15000),
                    heading: 0,
                    pitch: is3DMode ? 60 : 0
                ))
            }
        }
    }

    func flyToMyLocation() {
        switch locationManager.authorizationStatus {
        case .denied, .restricted:
            showLocationDeniedAlert = true
        default:
            locationManager.requestLocation()
            if let loc = locationManager.userLocation {
                withAnimation(.easeInOut(duration: 1.5)) {
                    cameraPosition = .camera(MapCamera(
                        centerCoordinate: loc.coordinate,
                        distance: 5000,
                        heading: 0,
                        pitch: is3DMode ? 45 : 0
                    ))
                }
            }
        }
    }

    func bearingBetween(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let dLon = (lon2 - lon1) * .pi / 180
        let lat1R = lat1 * .pi / 180
        let lat2R = lat2 * .pi / 180
        let y = sin(dLon) * cos(lat2R)
        let x = cos(lat1R) * sin(lat2R) - sin(lat1R) * cos(lat2R) * cos(dLon)
        let bearing = atan2(y, x) * 180 / .pi
        return (bearing + 360).truncatingRemainder(dividingBy: 360)
    }

    func calculateRouteStats(_ mountains: [Mountain]) -> (distance: Double, elevation: Int, durationMin: Int) {
        var totalDist = 0.0
        for i in 0..<(mountains.count - 1) {
            if let lat1 = mountains[i].latitude, let lon1 = mountains[i].longitude,
               let lat2 = mountains[i+1].latitude, let lon2 = mountains[i+1].longitude {
                let loc1 = CLLocation(latitude: lat1, longitude: lon1)
                let loc2 = CLLocation(latitude: lat2, longitude: lon2)
                totalDist += loc1.distance(from: loc2) / 1000.0
            }
        }
        let totalElev = mountains.reduce(0) { $0 + $1.elevation / 10 }
        let duration = Int((totalDist / 3.5) * 60)
        return (totalDist, totalElev, max(duration, 30))
    }

    func saveCreatedRoute() {
        guard routeMountains.count >= 2 else { return }
        let stats = calculateRouteStats(routeMountains)
        let hardest = routeMountains.map { $0.difficulty.rawValue }.max() ?? "Medium"
        let finalName = routeName.isEmpty ? "\(routeMountains[0].region) Custom Route" : routeName

        let route = SavedRoute(
            id: UUID(),
            name: finalName,
            mountainIds: routeMountains.map { $0.id },
            createdAt: Date(),
            totalDistanceKm: stats.distance,
            totalElevationGain: stats.elevation,
            estimatedDurationMinutes: stats.durationMin,
            difficulty: hardest
        )

        Task {
            await mountainManager.saveRoute(route)
        }

        HapticManager.shared.success()
        withAnimation(.spring()) {
            isRouteCreationMode = false
            routeMountains = []
            routeName = ""
        }
    }

    func showSavedRouteOnMap(_ route: SavedRoute) {
        // Find mountains by ID to show on map
        let routeMountainsList = route.mountainIds.compactMap { id in
            mountainManager.mountains.first { $0.id == id }
        }
        guard let first = routeMountainsList.first,
              let lat = first.latitude, let lon = first.longitude else { return }

        // Create a NearbyRoute for display
        if !routeMountainsList.isEmpty {
            let nearbyRoute = NearbyRoute(
                name: route.name,
                mountains: routeMountainsList,
                totalDistanceKm: route.totalDistanceKm,
                totalElevationGain: route.totalElevationGain,
                difficulty: Difficulty(rawValue: route.difficulty) ?? .medium,
                estimatedDurationMinutes: route.estimatedDurationMinutes
            )
            withAnimation(.spring()) {
                selectedRouteToShow = nearbyRoute
            }
            flyTo(lat: lat, lon: lon, distance: 12000)
        }
    }

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
// === TOOLBAR BUTTON ===
// =========================================

struct ToolbarButton: View {
    let icon: String
    let label: String
    let isActive: Bool
    let action: () -> Void
    private let gold = Color(red: 0.85, green: 0.65, blue: 0.13)

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                Text(label)
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundColor(isActive ? .black : .white)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isActive ? gold : Color.black.opacity(0.5))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(isActive ? 0 : 0.15), lineWidth: 0.5)
            )
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
// === DISCOVERY CARD ===
// =========================================

struct ExploreDiscoveryCard: View {
    let mountain: Mountain
    let userLocation: CLLocation?
    var compact: Bool = false
    let onTap: () -> Void

    @State private var isPressed = false
    private let gold = Color(red: 0.85, green: 0.65, blue: 0.13)

    private var cardWidth: CGFloat { compact ? 160 : 205 }
    private var imageHeight: CGFloat { compact ? 65 : 90 }

    private var distanceText: String? {
        guard let loc = userLocation,
              let lat = mountain.latitude,
              let lon = mountain.longitude else { return nil }
        let d = loc.distance(from: CLLocation(latitude: lat, longitude: lon)) / 1000
        return String(format: "%.0f km", d)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: compact ? 5 : 8) {
                if let urlString = mountain.imageUrl, !urlString.isEmpty, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(LinearGradient(colors: [gold.opacity(0.15), Color(red: 0.12, green: 0.12, blue: 0.15)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .overlay(ProgressView().tint(.white).scaleEffect(0.6))
                        }
                    }
                    .frame(width: cardWidth - 16, height: imageHeight).clipped().cornerRadius(8)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(colors: [gold.opacity(0.15), Color(red: 0.12, green: 0.12, blue: 0.15)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: cardWidth - 16, height: imageHeight)
                        .overlay(
                            Image(systemName: "mountain.2.fill").font(compact ? .body : .title2).foregroundColor(.white.opacity(0.2))
                        )
                }

                Text(mountain.name)
                    .font(compact ? .caption : .subheadline).fontWeight(.bold).foregroundColor(.white)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text("\(mountain.elevation)m").font(.system(size: compact ? 9 : 11)).foregroundColor(.gray)
                    if !compact {
                        Text("·").foregroundColor(.gray)
                        Text(mountain.region).font(.caption2).foregroundColor(.gray).lineLimit(1)
                    }
                    Spacer()
                    Text(mountain.difficulty.rawValue.uppercased())
                        .font(.system(size: compact ? 7 : 8, weight: .black))
                        .foregroundColor(.black)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(mountain.difficulty.color)
                        .cornerRadius(3)
                }

                if !compact {
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
            }
            .padding(8)
            .frame(width: cardWidth)
            .background(Color(red: 0.12, green: 0.12, blue: 0.15))
            .cornerRadius(compact ? 12 : 16)
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
// === ROUTE CARD ===
// =========================================

struct RouteCard: View {
    let route: NearbyRoute
    let onTap: () -> Void

    private let gold = Color(red: 0.85, green: 0.65, blue: 0.13)

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                        .font(.system(size: 10))
                        .foregroundColor(gold)
                    Text(route.name)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    Label(String(format: "%.1fkm", route.totalDistanceKm), systemImage: "arrow.left.and.right")
                    Label("\(route.totalElevationGain)m", systemImage: "arrow.up.right")
                }
                .font(.system(size: 9))
                .foregroundColor(.gray)

                HStack(spacing: 8) {
                    Label("\(route.estimatedDurationMinutes)min", systemImage: "clock")
                        .font(.system(size: 9))
                        .foregroundColor(.gray)

                    Spacer()

                    Text("\(route.peakCount) peaks")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(gold)
                }

                Text(route.difficulty.rawValue.uppercased())
                    .font(.system(size: 7, weight: .black))
                    .foregroundColor(.black)
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(route.difficulty.color)
                    .cornerRadius(3)
            }
            .padding(10)
            .frame(width: 180)
            .background(Color(red: 0.12, green: 0.12, blue: 0.15))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// =========================================
// === SAVED ROUTE CARD ===
// =========================================

struct SavedRouteCard: View {
    let route: SavedRoute
    let onTap: () -> Void
    let onDelete: () -> Void

    private let gold = Color(red: 0.85, green: 0.65, blue: 0.13)

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 10))
                        .foregroundColor(gold)
                    Text(route.name)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Spacer()
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                            .foregroundColor(.red.opacity(0.7))
                    }
                }

                HStack(spacing: 8) {
                    Label(String(format: "%.1fkm", route.totalDistanceKm), systemImage: "arrow.left.and.right")
                    Label("\(route.totalElevationGain)m", systemImage: "arrow.up.right")
                    Label("\(route.mountainIds.count) peaks", systemImage: "mountain.2.fill")
                }
                .font(.system(size: 9))
                .foregroundColor(.gray)

                HStack {
                    Text(route.createdAt, style: .date)
                        .font(.system(size: 9))
                        .foregroundColor(.gray.opacity(0.7))
                    Spacer()
                    Text(route.difficulty.uppercased())
                        .font(.system(size: 7, weight: .black))
                        .foregroundColor(.black)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(difficultyColorFromString(route.difficulty))
                        .cornerRadius(3)
                }
            }
            .padding(10)
            .frame(width: 200)
            .background(Color(red: 0.12, green: 0.12, blue: 0.15))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }

    func difficultyColorFromString(_ d: String) -> Color {
        switch d {
        case "Easy": return .green
        case "Medium": return .yellow
        case "Hard": return .orange
        case "Extreme": return .red
        default: return .gray
        }
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
