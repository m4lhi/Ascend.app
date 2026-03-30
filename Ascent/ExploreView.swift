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
        // Strenges Limit für die Karte, um bei 70k Bergen Lags zu verhindern
        switch currentZoomLevel {
        case .far:    return Array(mapMountains.filter { $0.isPrestigePeak }.prefix(30))
        case .medium: return Array(mapMountains.prefix(100))
        case .close:  return Array(mapMountains.prefix(200))
        }
    }

    var showPOIs: Bool { showNearby && currentZoomLevel == .close }

    // MARK: - Body
    var body: some View {
        ZStack(alignment: .top) {
            // === 1. FULL-SCREEN 3D MAP ===
            mapLayer

            // === 2. TOP GRADIENT (Damit Text oben lesbar bleibt) ===
            LinearGradient(
                colors: [.black.opacity(0.8), .black.opacity(0.3), .clear],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 180)
            .ignoresSafeArea()
            .allowsHitTesting(false)

            // === 3. TOP CONTROLS (Search & Filters) ===
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

            // === 4. SCHWEBENDE KARTEN-BUTTONS (Rechts, zentriert) ===
            // So stören sie weder die Bottom-Sheets noch die Tab-Bar
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        FloatingMapButton(icon: "square.3.layers.3d") { showLayersSheet = true }
                        FloatingMapButton(icon: is3DMode ? "view.2d" : "view.3d", isActive: is3DMode) { toggle3D() }
                        FloatingMapButton(icon: "location.fill") { flyToMyLocation() }
                    }
                    .padding(.trailing, 12)
                }
                Spacer()
            }

            // === 5. BOTTOM SHEETS (Abgesetzt als schwebende Inseln) ===
            if isRouteCreationMode {
                VStack {
                    Spacer()
                    routeCreationPanel
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
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
            if focused { Task { await mountainManager.fetchTopMountains() } }
        }
        .onChange(of: searchText) { _, _ in performDebouncedSearch() }
        .onChange(of: selectedDifficulty) { _, _ in Task { await refreshResults() } }
        .onChange(of: showNearby) { _, _ in Task { await refreshResults() } }
        .onChange(of: nearbyRadiusKm) { _, _ in performDebouncedSearch() }
        .onChange(of: selectedMarkerTag) { _, newTag in
            withAnimation(.spring()) {
                if let tag = newTag {
                    if isRouteCreationMode {
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
            layersSheet.presentationDetents([.medium]).presentationDragIndicator(.visible)
        }
    }

    // MARK: - Map Layer
    @ViewBuilder
    var mapLayer: some View {
        Map(position: $cameraPosition, selection: $selectedMarkerTag) {
            UserAnnotation()

            ForEach(visibleMountains, id: \.id) { mountain in
                if isRouteCreationMode {
                    if let idx = routeMountains.firstIndex(where: { $0.id == mountain.id }) {
                        Annotation("\(idx + 1)", coordinate: CLLocationCoordinate2D(latitude: mountain.latitude!, longitude: mountain.longitude!)) {
                            ZStack {
                                Circle().fill(gold).frame(width: 32, height: 32)
                                Text("\(idx + 1)").font(.system(size: 14, weight: .black)).foregroundColor(.black)
                            }
                            .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                        }
                        .tag(mountain.id)
                    } else {
                        Marker(mountain.name, systemImage: "plus.circle.fill", coordinate: CLLocationCoordinate2D(latitude: mountain.latitude!, longitude: mountain.longitude!))
                            .tint(.white.opacity(0.7))
                            .tag(mountain.id)
                    }
                } else if mountain.isPrestigePeak {
                    Marker(mountain.name, systemImage: "crown.fill", coordinate: CLLocationCoordinate2D(latitude: mountain.latitude!, longitude: mountain.longitude!))
                        .tint(gold)
                        .tag(mountain.id)
                } else {
                    Marker(mountain.name, systemImage: "mountain.2.fill", coordinate: CLLocationCoordinate2D(latitude: mountain.latitude!, longitude: mountain.longitude!))
                        .tint(difficultyColor(mountain.difficulty))
                        .tag(mountain.id)
                }
            }

            if isRouteCreationMode && routeMountains.count >= 2 {
                let coords = routeMountains.compactMap { m -> CLLocationCoordinate2D? in
                    guard let lat = m.latitude, let lon = m.longitude else { return nil }
                    return CLLocationCoordinate2D(latitude: lat, longitude: lon)
                }
                MapPolyline(coordinates: coords).stroke(gold, lineWidth: 3)
            }

            if let route = selectedRouteToShow {
                let coords = route.mountains.compactMap { m -> CLLocationCoordinate2D? in
                    guard let lat = m.latitude, let lon = m.longitude else { return nil }
                    return CLLocationCoordinate2D(latitude: lat, longitude: lon)
                }
                MapPolyline(coordinates: coords).stroke(gold, lineWidth: 3)
            }
        }
        .mapStyle(mapStyleForCurrentLayer)
        // DIESER PADDING FIXT DEN KOMPASS! Er wird unterhalb der Suchleiste gezeichnet.
        .safeAreaPadding(.top, 160)
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
    }

    var mapStyleForCurrentLayer: MapStyle {
        switch currentMapLayer {
        case .standard:  return .standard(elevation: is3DMode ? .realistic : .flat)
        case .satellite: return .hybrid(elevation: is3DMode ? .realistic : .flat)
        case .terrain:   return .standard(elevation: .realistic)
        case .night:     return .standard(elevation: is3DMode ? .realistic : .flat)
        case .elevation: return .hybrid(elevation: is3DMode ? .realistic : .flat)
        }
    }

    // MARK: - Search Bar
    @ViewBuilder
    var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundColor(.gray).font(.system(size: 16, weight: .medium))
            TextField("Search peaks or regions…", text: $searchText)
                .focused($isSearchFocused).foregroundColor(.white).autocorrectionDisabled().textInputAutocapitalization(.never)

            if isSearchActive || !searchText.isEmpty {
                Button {
                    withAnimation(.spring()) {
                        searchText = ""
                        isSearchFocused = false
                        isSearchActive = false
                        selectedDifficulty = nil
                    }
                    Task { await mountainManager.fetchMountainsFromDatabase() }
                } label: { Image(systemName: "xmark.circle.fill").foregroundColor(.gray) }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12).background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.12), lineWidth: 0.5))
    }

    // MARK: - Top Toolbar
    @ViewBuilder
    var toolbarRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ToolbarButton(icon: showNearby ? "location.fill" : "location", label: "Nearby", isActive: showNearby) {
                    withAnimation(.spring()) { showNearby.toggle() }
                }

                if showNearby {
                    ForEach([10.0, 25.0, 50.0], id: \.self) { radius in
                        Button { nearbyRadiusKm = radius } label: {
                            Text("\(Int(radius))km").font(.system(size: 10, weight: .bold))
                                .foregroundColor(nearbyRadiusKm == radius ? .black : .white.opacity(0.7))
                                .padding(.horizontal, 8).padding(.vertical, 6)
                                .background(nearbyRadiusKm == radius ? gold : Color.white.opacity(0.1)).clipShape(Capsule())
                        }
                    }
                }

                ToolbarButton(icon: isRouteCreationMode ? "xmark" : "pencil.line", label: isRouteCreationMode ? "Cancel" : "Route", isActive: isRouteCreationMode) {
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
                    selectedDifficulty = nil; showRoutesFilter = false
                }
                ForEach(Difficulty.allCases, id: \.self) { diff in
                    DifficultyChip(label: diff.rawValue, color: difficultyColor(diff), isSelected: selectedDifficulty == diff) {
                        selectedDifficulty = diff; showRoutesFilter = false
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
                HStack { Text("\(mapMountains.count) results").font(.system(size: 11, weight: .semibold)).foregroundColor(.gray); Spacer() }
                    .padding(.horizontal, 14).padding(.vertical, 8).background(Color.white.opacity(0.03))
            }

            if suggestions.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "mountain.2").font(.title2).foregroundColor(.gray.opacity(0.4))
                    Text("No peaks found").font(.caption).foregroundColor(.gray)
                }.frame(maxWidth: .infinity).padding(.vertical, 24)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, mountain in
                            Button { selectMountain(mountain) } label: {
                                HStack(spacing: 12) {
                                    Circle().fill(difficultyColor(mountain.difficulty)).frame(width: 8, height: 8)
                                    Image(systemName: mountain.isPrestigePeak ? "crown.fill" : "mountain.2.fill")
                                        .foregroundColor(mountain.isPrestigePeak ? gold : .gray).frame(width: 20)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(mountain.name).font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                                        Text("\(mountain.region) · \(mountain.elevation)m").font(.system(size: 11)).foregroundColor(.gray)
                                    }
                                    Spacer()
                                    Text(mountain.difficulty.rawValue).font(.system(size: 10, weight: .bold)).foregroundColor(difficultyColor(mountain.difficulty))
                                }.padding(.horizontal, 14).padding(.vertical, 10)
                            }
                            if index < suggestions.count - 1 { Divider().background(Color.white.opacity(0.06)) }
                        }
                    }
                }.frame(maxHeight: 320)
            }
        }
        .background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 0.5))
    }

    // MARK: - Layers Sheet
    @ViewBuilder
    var layersSheet: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                    ForEach(MapLayerType.allCases) { layer in
                        Button {
                            withAnimation(.spring()) { currentMapLayer = layer }
                            showLayersSheet = false
                        } label: {
                            VStack(spacing: 8) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12).fill(layerPreviewColor(layer)).frame(height: 80)
                                    Image(systemName: layer.icon).font(.system(size: 28)).foregroundColor(.white)
                                }.overlay(RoundedRectangle(cornerRadius: 12).stroke(currentMapLayer == layer ? gold : Color.clear, lineWidth: 2))
                                Text(layer.rawValue).font(.system(size: 13, weight: .bold)).foregroundColor(currentMapLayer == layer ? gold : .white)
                                Text(layer.subtitle).font(.system(size: 10)).foregroundColor(.gray)
                            }
                        }
                    }
                }.padding(16)
            }
            .background(Color(red: 0.08, green: 0.08, blue: 0.1)).navigationTitle("Map Layers").navigationBarTitleDisplayMode(.inline)
        }.preferredColorScheme(.dark)
    }

    func layerPreviewColor(_ layer: MapLayerType) -> LinearGradient {
        switch layer {
        case .standard: return LinearGradient(colors: [.gray.opacity(0.3), .gray.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .satellite: return LinearGradient(colors: [.green.opacity(0.3), .blue.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .terrain: return LinearGradient(colors: [.brown.opacity(0.3), .green.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .night: return LinearGradient(colors: [.indigo.opacity(0.4), .black.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .elevation: return LinearGradient(colors: [.green.opacity(0.3), .red.opacity(0.3)], startPoint: .bottom, endPoint: .top)
        }
    }

    // MARK: - Route Creation Panel
    @ViewBuilder
    var routeCreationPanel: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "pencil.line").foregroundColor(gold)
                Text("Route Creator").font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                Spacer()
                Text("\(routeMountains.count) peaks").font(.system(size: 12, weight: .semibold)).foregroundColor(gold)
            }

            TextField("Route name…", text: $routeName).textFieldStyle(.plain).padding(10)
                .background(Color.white.opacity(0.08)).cornerRadius(10).foregroundColor(.white)

            if !routeMountains.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(routeMountains.enumerated()), id: \.element.id) { index, mountain in
                            HStack(spacing: 4) {
                                Text("\(index + 1)").font(.system(size: 10, weight: .black)).foregroundColor(.black).frame(width: 18, height: 18).background(gold).clipShape(Circle())
                                Text(mountain.name).font(.system(size: 11, weight: .semibold)).foregroundColor(.white).lineLimit(1)
                                Button { routeMountains.removeAll { $0.id == mountain.id } } label: { Image(systemName: "xmark.circle.fill").font(.system(size: 12)).foregroundColor(.gray) }
                            }.padding(.horizontal, 8).padding(.vertical, 6).background(Color.white.opacity(0.1)).cornerRadius(8)
                        }
                    }
                }
            }

            if routeMountains.count >= 2 {
                let stats = calculateRouteStats(routeMountains)
                HStack(spacing: 0) {
                    DetailStat(icon: "point.topleft.down.to.point.bottomright.curvepath", value: String(format: "%.1fkm", stats.distance), label: "Distance")
                    DetailStat(icon: "arrow.up.right", value: "\(stats.elevation)m", label: "Elevation")
                    DetailStat(icon: "clock", value: "\(stats.durationMin)min", label: "Est. Time")
                    DetailStat(icon: "mountain.2.fill", value: "\(routeMountains.count)", label: "Peaks")
                }
            }

            HStack(spacing: 12) {
                Button { withAnimation(.spring()) { isRouteCreationMode = false; routeMountains = []; routeName = "" } } label: {
                    Text("Cancel").font(.system(size: 14, weight: .bold)).foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 12).background(Color.white.opacity(0.15)).cornerRadius(12)
                }
                Button { saveCreatedRoute() } label: {
                    HStack(spacing: 4) { Image(systemName: "checkmark"); Text("Save Route") }.font(.system(size: 14, weight: .bold)).foregroundColor(.black).frame(maxWidth: .infinity).padding(.vertical, 12).background(routeMountains.count >= 2 ? gold : gold.opacity(0.3)).cornerRadius(12)
                }.disabled(routeMountains.count < 2)
            }
        }
        .padding(16).background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(gold.opacity(0.3), lineWidth: 0.5))
        .padding(.horizontal, 16)
        .padding(.bottom, 100) // Schwebend über Tab-Bar
    }

    // MARK: - Discovery Sheet (Neues Slick-Design)
    @ViewBuilder
    var discoverySheet: some View {
        let nearbyCards = Array(mapMountains.prefix(10))
        let routes = mountainManager.nearbyRoutes
        let savedRoutes = mountainManager.savedRoutes

        VStack(alignment: .leading, spacing: 0) {
            // Ein eleganter Drag-Handle in der Mitte
            HStack { Spacer(); Capsule().fill(Color.white.opacity(0.4)).frame(width: 40, height: 4); Spacer() }
                .padding(.top, 12).padding(.bottom, 8).contentShape(Rectangle())
                .onTapGesture { withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { discoverySheetExpanded.toggle() } }

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    
                    if !nearbyCards.isEmpty && !showRoutesFilter {
                        discoverySectionHeader(title: "Nearby Missions", icon: "mountain.2.fill")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                Spacer().frame(width: 4)
                                ForEach(nearbyCards, id: \.id) { mountain in
                                    ExploreDiscoveryCard(mountain: mountain, userLocation: locationManager.userLocation, compact: true) { selectMountain(mountain) }
                                }
                                Spacer().frame(width: 4)
                            }
                        }
                    }

                    if (!routes.isEmpty || showRoutesFilter) && (discoverySheetExpanded || nearbyCards.isEmpty) {
                        discoverySectionHeader(title: "Nearby Routes", icon: "point.topleft.down.to.point.bottomright.curvepath")
                        if routes.isEmpty {
                            HStack { Spacer(); VStack(spacing: 6) { Image(systemName: "map.fill").font(.title2).foregroundColor(.gray.opacity(0.4)); Text("Enable Nearby to see routes").font(.caption).foregroundColor(.gray) }; Spacer() }.padding(.vertical, 16)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    Spacer().frame(width: 4)
                                    ForEach(routes) { route in
                                        RouteCard(route: route) {
                                            withAnimation(.spring()) {
                                                selectedRouteToShow = route
                                                if let first = route.mountains.first, let lat = first.latitude, let lon = first.longitude { flyTo(lat: lat, lon: lon, distance: 12000) }
                                            }
                                        }
                                    }
                                    Spacer().frame(width: 4)
                                }
                            }
                        }
                    }

                    if (discoverySheetExpanded || showRoutesFilter) {
                        discoverySectionHeader(title: "My Routes", icon: "bookmark.fill")
                        if savedRoutes.isEmpty {
                            HStack { Spacer(); VStack(spacing: 6) { Image(systemName: "map").font(.title2).foregroundColor(.gray.opacity(0.3)); Text("No saved routes yet.").font(.caption).foregroundColor(.gray) }; Spacer() }.padding(.vertical, 16)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    Spacer().frame(width: 4)
                                    ForEach(savedRoutes) { route in
                                        SavedRouteCard(route: route, onTap: { showSavedRouteOnMap(route) }, onDelete: { Task { await mountainManager.deleteRoute(id: route.id) } })
                                    }
                                    Spacer().frame(width: 4)
                                }
                            }
                        }
                    }
                }.padding(.bottom, 16)
            }
            .frame(maxHeight: discoverySheetExpanded ? 350 : 130) // Kompakte Höhe
        }
        .background(.ultraThinMaterial.opacity(0.95)) // Eleganter Glas-Effekt statt harter Schwarzton
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.3), radius: 15, y: 5)
        .padding(.horizontal, 16) // Lässt Platz am Rand (Floating Island)
        .padding(.bottom, 100) // Gibt der Tab-Bar genug Luft zum Atmen
    }

    @ViewBuilder
    func discoverySectionHeader(title: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon).font(.system(size: 13, weight: .bold)).foregroundColor(gold)
            Text(title).font(.system(size: 15, weight: .bold)).foregroundColor(.white)
            Spacer()
            if !discoverySheetExpanded {
                Button { withAnimation(.spring()) { discoverySheetExpanded = true } } label: { Text("See All").font(.system(size: 12, weight: .semibold)).foregroundColor(gold) }
            }
        }.padding(.horizontal, 16)
    }

    // MARK: - Detail Card (Slick Design)
    @ViewBuilder
    func detailCard(for mountain: Mountain) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                if let urlStr = mountain.imageUrl, !urlStr.isEmpty, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        if let img = phase.image { img.resizable().scaledToFill() } else { goldGradientPlaceholder }
                    }.frame(height: 140).clipped()
                } else { goldGradientPlaceholder.frame(height: 140) }

                LinearGradient(colors: [.clear, Color(red: 0.1, green: 0.1, blue: 0.12)], startPoint: .center, endPoint: .bottom)

                Button { withAnimation(.spring()) { selectedMountain = nil; selectedMarkerTag = nil; selectedRouteToShow = nil } } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 26)).foregroundStyle(.white.opacity(0.8), .black.opacity(0.5))
                }.padding(12)
            }

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(mountain.name).font(.title3).fontWeight(.bold).foregroundColor(.white)
                        Text("\(mountain.region), \(mountain.country)").font(.caption).foregroundColor(.gray)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(mountain.difficulty.rawValue.uppercased()).font(.system(size: 9, weight: .black)).foregroundColor(.black).padding(.horizontal, 8).padding(.vertical, 4).background(difficultyColor(mountain.difficulty)).clipShape(Capsule())
                        if mountain.isPrestigePeak {
                            HStack(spacing: 3) { Image(systemName: "crown.fill").font(.system(size: 8)); Text("PRESTIGE").font(.system(size: 8, weight: .black)) }.foregroundColor(gold)
                        }
                    }
                }

                HStack(spacing: 0) {
                    DetailStat(icon: "arrow.up.right", value: "\(mountain.elevation)m", label: "Elevation")
                    DetailStat(icon: "chart.line.uptrend.xyaxis", value: "~\(mountain.elevation / 2)m", label: "Est. Gain")
                    DetailStat(icon: "clock", value: estimatedDuration(for: mountain), label: "Est. Time")
                    if let userLoc = locationManager.userLocation, let lat = mountain.latitude, let lon = mountain.longitude {
                        let dist = userLoc.distance(from: CLLocation(latitude: lat, longitude: lon)) / 1000
                        DetailStat(icon: "location", value: String(format: "%.0fkm", dist), label: "Away")
                    }
                }

                if !mountain.description.isEmpty { Text(mountain.description).font(.caption2).foregroundColor(.gray).lineLimit(2) }

                Button { HapticManager.shared.heavy(); mountainToTrack = mountain; showTracker = true } label: {
                    HStack { Image(systemName: "play.fill"); Text("Commence Mission") }.font(.subheadline).fontWeight(.bold).foregroundColor(.black).frame(maxWidth: .infinity).padding(.vertical, 12).background(gold).clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }.padding(16)
        }
        .background(Color(red: 0.1, green: 0.1, blue: 0.12)).clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.4), radius: 15, y: 5)
        .padding(.horizontal, 16)
        .padding(.bottom, 100) // Schwebend über Tab-Bar
    }

    // MARK: - Helpers
    func toggle3D() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            is3DMode.toggle()
            let currentCenter = cameraPosition.camera?.centerCoordinate ?? locationManager.userLocation?.coordinate ?? CLLocationCoordinate2D(latitude: 47.0, longitude: 11.0)
            let currentDistance = cameraPosition.camera?.distance ?? 15000
            
            cameraPosition = .camera(MapCamera(
                centerCoordinate: currentCenter,
                distance: currentDistance,
                heading: cameraPosition.camera?.heading ?? 0,
                pitch: is3DMode ? 65 : 0
            ))
        }
    }

    @ViewBuilder
    var goldGradientPlaceholder: some View {
        LinearGradient(colors: [gold.opacity(0.2), Color(red: 0.1, green: 0.1, blue: 0.12)], startPoint: .topLeading, endPoint: .bottomTrailing).overlay(Image(systemName: "mountain.2.fill").font(.system(size: 30)).foregroundColor(.white.opacity(0.05)))
    }

    func difficultyColor(_ diff: Difficulty) -> Color {
        switch diff {
        case .easy: return .green
        case .medium: return .yellow
        case .hard: return .orange
        case .extreme: return .red
        case .expert: return .purple // 🟢 HIER NEU HINZUGEFÜGT
        }
    }

    func estimatedDuration(for mountain: Mountain) -> String {
        let hours = Double(mountain.elevation) / 800.0
        if hours < 1 { return "\(Int(hours * 60))min" }
        return String(format: "%.0f-%.0fh", hours, hours * 1.3)
    }

    func selectMountain(_ mountain: Mountain) {
        withAnimation(.spring()) {
            selectedMountain = mountain; selectedMarkerTag = mountain.id; isSearchFocused = false; isSearchActive = false; searchText = ""; selectedRouteToShow = nil
        }
        if let lat = mountain.latitude, let lon = mountain.longitude { flyToMountain(lat: lat, lon: lon) }
    }

    func flyToMountain(lat: Double, lon: Double) {
        var heading: Double = 0
        if let userLoc = locationManager.userLocation {
            let lat1 = userLoc.coordinate.latitude * .pi / 180
            let lon1 = userLoc.coordinate.longitude * .pi / 180
            let lat2 = lat * .pi / 180
            let lon2 = lon * .pi / 180
            let y = sin(lon2 - lon1) * cos(lat2)
            let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(lon2 - lon1)
            heading = (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
        }
        withAnimation(.easeInOut(duration: 1.5)) {
            cameraPosition = .camera(MapCamera(centerCoordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon), distance: 8000, heading: heading, pitch: is3DMode ? 65 : 0))
        }
    }

    func flyTo(lat: Double, lon: Double, distance: Double) {
        withAnimation(.easeInOut(duration: 1.5)) { cameraPosition = .camera(MapCamera(centerCoordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon), distance: distance, heading: 0, pitch: is3DMode ? 60 : 0)) }
    }

    func flyToUserArea(location: CLLocation) {
        withAnimation(.easeInOut(duration: 2.0)) {
            cameraPosition = .camera(MapCamera(centerCoordinate: location.coordinate, distance: 15000, heading: 0, pitch: is3DMode ? 60 : 0))
        }
    }

    func flyToMyLocation() {
        switch locationManager.authorizationStatus {
        case .denied, .restricted: showLocationDeniedAlert = true
        default:
            locationManager.requestLocation()
            if let loc = locationManager.userLocation {
                withAnimation(.easeInOut(duration: 1.5)) { cameraPosition = .camera(MapCamera(centerCoordinate: loc.coordinate, distance: 5000, heading: 0, pitch: is3DMode ? 45 : 0)) }
            }
        }
    }

    func calculateRouteStats(_ mountains: [Mountain]) -> (distance: Double, elevation: Int, durationMin: Int) {
        var totalDist = 0.0
        for i in 0..<(mountains.count - 1) {
            if let lat1 = mountains[i].latitude, let lon1 = mountains[i].longitude, let lat2 = mountains[i+1].latitude, let lon2 = mountains[i+1].longitude {
                let loc1 = CLLocation(latitude: lat1, longitude: lon1); let loc2 = CLLocation(latitude: lat2, longitude: lon2)
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
        let route = SavedRoute(id: UUID(), name: routeName.isEmpty ? "\(routeMountains[0].region) Custom Route" : routeName, mountainIds: routeMountains.map { $0.id }, createdAt: Date(), totalDistanceKm: stats.distance, totalElevationGain: stats.elevation, estimatedDurationMinutes: stats.durationMin, difficulty: routeMountains.map { $0.difficulty.rawValue }.max() ?? "Medium")
        Task { await mountainManager.saveRoute(route) }
        HapticManager.shared.success()
        withAnimation(.spring()) { isRouteCreationMode = false; routeMountains = []; routeName = "" }
    }

    func showSavedRouteOnMap(_ route: SavedRoute) {
        let routeMountainsList = route.mountainIds.compactMap { id in mountainManager.mountains.first { $0.id == id } }
        guard let first = routeMountainsList.first, let lat = first.latitude, let lon = first.longitude else { return }
        if !routeMountainsList.isEmpty {
            withAnimation(.spring()) {
                selectedRouteToShow = NearbyRoute(name: route.name, mountains: routeMountainsList, totalDistanceKm: route.totalDistanceKm, totalElevationGain: route.totalElevationGain, difficulty: Difficulty(rawValue: route.difficulty) ?? .medium, estimatedDurationMinutes: route.estimatedDurationMinutes)
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
            await mountainManager.fetchNearbyMountains(latitude: loc.coordinate.latitude, longitude: loc.coordinate.longitude, radiusKm: nearbyRadiusKm)
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
            if let p = placemarks.first { discoveryRegionName = p.locality ?? p.administrativeArea ?? p.country ?? "" }
        } catch {}
    }
}

// =========================================
// === FLOATING MAP BUTTON (Slick Design) ===
// =========================================
struct FloatingMapButton: View {
    let icon: String
    var isActive: Bool = false
    let action: () -> Void
    private let gold = Color(red: 0.85, green: 0.65, blue: 0.13)

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(isActive ? .black : .white)
                .frame(width: 44, height: 44) // Etwas kompakter für einen edlen Look
                .background(isActive ? gold : Color(red: 0.1, green: 0.1, blue: 0.12).opacity(0.85))
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 1))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// =========================================
// === RESTLICHE KOMPONENTEN ===
// =========================================

struct ToolbarButton: View {
    let icon: String; let label: String; let isActive: Bool; let action: () -> Void
    private let gold = Color(red: 0.85, green: 0.65, blue: 0.13)
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) { Image(systemName: icon).font(.system(size: 11, weight: .bold)); Text(label).font(.system(size: 11, weight: .bold)) }
            .foregroundColor(isActive ? .black : .white).padding(.horizontal, 10).padding(.vertical, 8)
            .background(isActive ? gold : Color.black.opacity(0.5)).clipShape(Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(isActive ? 0 : 0.15), lineWidth: 0.5))
        }
    }
}

struct DifficultyChip: View {
    let label: String; var color: Color = .white; let isSelected: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label).font(.system(size: 12, weight: .bold)).foregroundColor(isSelected ? .black : .white)
                .padding(.horizontal, 12).padding(.vertical, 6).background(isSelected ? color : Color.white.opacity(0.15)).cornerRadius(8)
        }
    }
}

// Kompakte Version der Explore Discovery Card
struct ExploreDiscoveryCard: View {
    let mountain: Mountain; let userLocation: CLLocation?; var compact: Bool = false; let onTap: () -> Void
    @State private var isPressed = false; private let gold = Color(red: 0.85, green: 0.65, blue: 0.13)
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                if let urlString = mountain.imageUrl, let url = URL(string: urlString) {
                    AsyncImage(url: url) { p in if let i = p.image { i.resizable().scaledToFill() } else { Color.white.opacity(0.05) } }.frame(width: 140, height: 65).clipped().cornerRadius(8)
                } else {
                    RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.05)).frame(width: 140, height: 65)
                }
                Text(mountain.name).font(.system(size: 12, weight: .bold)).foregroundColor(.white).lineLimit(1)
                HStack {
                    Text("\(mountain.elevation)m").font(.system(size: 10)).foregroundColor(.gray)
                    Spacer()
                    Text(mountain.difficulty.rawValue.uppercased()).font(.system(size: 7, weight: .black)).foregroundColor(.black).padding(.horizontal, 4).padding(.vertical, 2).background(mountain.difficulty.color).cornerRadius(3)
                }
            }.padding(8).frame(width: 156).background(Color.white.opacity(0.08)).cornerRadius(12)
        }.buttonStyle(PlainButtonStyle())
    }
}

struct RouteCard: View {
    let route: NearbyRoute; let onTap: () -> Void
    var body: some View { Button(action: onTap) { Text(route.name).font(.caption).fontWeight(.semibold).foregroundColor(.white).padding().background(Color.white.opacity(0.08)).cornerRadius(12) } }
}

struct SavedRouteCard: View {
    let route: SavedRoute; let onTap: () -> Void; let onDelete: () -> Void
    var body: some View { Button(action: onTap) { Text(route.name).font(.caption).fontWeight(.semibold).foregroundColor(.white).padding().background(Color.white.opacity(0.08)).cornerRadius(12) } }
}

struct DetailStat: View {
    let icon: String; let value: String; let label: String
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 12)).foregroundColor(.gray)
            Text(value).font(.system(size: 13, weight: .bold)).foregroundColor(.white)
            Text(label).font(.system(size: 9, weight: .medium)).foregroundColor(.gray)
        }.frame(maxWidth: .infinity)
    }
}
