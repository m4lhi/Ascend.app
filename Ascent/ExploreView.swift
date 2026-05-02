import SwiftUI
import Supabase
import PostgREST
@_spi(Experimental) import MapboxMaps
import CoreLocation
import Combine
import Charts

// =========================================
// === DATEI: ExploreView.swift ===
// === 2D Terrain Map with Discovery ===
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
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        authorizationStatus = status
    }

    func requestLocationSafely() {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("⚠️ Location error: \(error.localizedDescription)")
    }
}

// MARK: - Map Layer Type
enum MapLayerType: String, CaseIterable, Identifiable {
    case standard = "Standard"
    case satellite = "Satellite"
    case night = "Night"
    case topo = "Topo"
    case swissTopo = "SwissTopo"
    case slope = "Slope"        // Swiss slope angle map (skitour avalanche reference)

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .standard:  return "map"
        case .satellite: return "globe.americas.fill"
        case .night:     return "moon.stars.fill"
        case .topo:      return "mountain.2.fill"
        case .swissTopo: return "flag.fill"
        case .slope:     return "triangle.fill"
        }
    }

    var subtitle: String {
        switch self {
        case .standard:  return "Default map"
        case .satellite: return "Hybrid with labels"
        case .night:     return "Dark map style"
        case .topo:      return "Contour lines (worldwide)"
        case .swissTopo: return "Swiss alpine topo (CH only)"
        case .slope:     return "Slope angle 30°/35°/40°+ (CH)"
        }
    }

    // Tile URL template for raster overlay layers (nil = native Mapbox style)
    var tileURLTemplate: String? {
        switch self {
        case .topo:      return "https://tile.opentopomap.org/{z}/{x}/{y}.png"
        case .swissTopo: return "https://wmts.geo.admin.ch/1.0.0/ch.swisstopo.pixelkarte-farbe/default/current/3857/{z}/{x}/{y}.jpeg"
        case .slope:     return "https://wmts.geo.admin.ch/1.0.0/ch.swisstopo-karto.hangneigung/default/current/3857/{z}/{x}/{y}.png"
        default:         return nil
        }
    }

    /// Whether this layer is overlaid on top of another base layer (true) or
    /// replaces the entire base map (false). Slope is semi-transparent overlay.
    var isOverlay: Bool {
        switch self {
        case .slope: return true
        default:     return false
        }
    }

    // Attribution required by tile providers
    var attribution: String? {
        switch self {
        case .topo:      return "© OpenTopoMap (CC-BY-SA), © OSM"
        case .swissTopo: return "© swisstopo"
        case .slope:     return "© swisstopo (Hangneigung)"
        default:         return nil
        }
    }
}

// MARK: - Mountain Champion
struct MountainChampion {
    let userId: UUID
    let avatarUrl: String?
    let username: String
}

// MARK: - ExploreView
struct ExploreView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var mountainManager = MountainManager()
    @StateObject private var locationManager = ExploreLocationManager()

    @AppStorage("userFitnessLevel") private var userFitnessLevel = 0

    @State private var viewport: Viewport = .styleDefault
    @State private var selectedMarkerTag: UUID? = nil
    @State private var selectedMountain: Mountain? = nil

    @FocusState private var isSearchFocused: Bool
    @State private var isSearchActive = false
    @State private var searchExpanded = false
    @State private var searchText = ""
    @State private var searchTask: Task<Void, Never>? = nil

    @State private var selectedDifficulty: Difficulty? = nil
    @State private var showRoutesFilter = false

    @State private var showNearby = false
    @State private var nearbyRadiusKm: Double = 25

    @AppStorage("mapLayerType") private var mapLayerRaw: String = MapLayerType.satellite.rawValue
    private var currentMapLayer: MapLayerType {
        get { MapLayerType(rawValue: mapLayerRaw) ?? .satellite }
    }
    @State private var isLayersExpanded = false
    @State private var is3DMode: Bool = false
    @State private var cameraCenter: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 47.0, longitude: 11.0)
    @State private var cameraZoom: Double = 8.0

    @State private var showLocationDeniedAlert = false
    @State private var isRouteCreationMode = false
    @State private var routeMountains: [Mountain] = []
    @State private var routeName = ""
    @State private var routeDescription = ""
    @State private var routeSportType: SportType = .hiking
    @State private var routeVisibility: RouteVisibility = .privateRoute

    @State private var discoverySheetExpanded = false

    @State private var currentZoomLevel: ZoomLevel = .medium
    @State private var mapFetchTask: Task<Void, Never>? = nil
    enum ZoomLevel { case far, medium, close }

    @State private var showTracker = false
    @State private var mountainToTrack: Mountain? = nil
    @State private var selectedRouteToShow: SavedRoute? = nil
    @State private var routeForDetailSheet: SavedRoute? = nil

    @State private var hasCenteredOnUser = false
    @State private var showMyRoutesLibrary = false
    @State private var mountainChampions: [UUID: MountainChampion] = [:]

    private let gold = DesignSystem.Colors.accent

    var mapMountains: [Mountain] {
        var source = showNearby ? mountainManager.nearbyMountains : mountainManager.mountains
        if let diff = selectedDifficulty {
            source = source.filter { $0.difficulty == diff }
        }
        return source.filter { $0.latitude != nil && $0.longitude != nil }
    }

    var visibleMountains: [Mountain] {
        // In 3D mode reduce pin count to avoid mass-spawn on camera rotation
        let limit: Int
        switch currentZoomLevel {
        case .far:    limit = is3DMode ? 15 : 30
        case .medium: limit = is3DMode ? 40 : 80
        case .close:  limit = is3DMode ? 80 : 200
        }
        return Array(mapMountains.prefix(limit))
    }

    var fitnessMatchedMountains: [Mountain] {
        guard userFitnessLevel > 0 else { return [] }
        let level = fitnessLevels[min(userFitnessLevel - 1, fitnessLevels.count - 1)]
        let matched = mountainManager.mountains
            .filter { level.difficulties.contains($0.difficulty) && $0.elevation <= level.elevationCap && $0.latitude != nil && $0.longitude != nil }
        if matched.count >= 6 { return Array(matched.prefix(15)) }
        let matchedIds = Set(matched.map { $0.id })
        let extra = mountainManager.mountains
            .filter { $0.latitude != nil && $0.longitude != nil && !matchedIds.contains($0.id) }
            .prefix(max(0, 15 - matched.count))
        return matched + Array(extra)
    }

    var body: some View {
        ZStack(alignment: .top) {
            mapLayer

            VStack(alignment: .leading, spacing: 8) {
                floatingSearchArea
                if searchExpanded {
                    toolbarRow
                        .transition(.move(edge: .top).combined(with: .opacity))
                    filterChips
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                if isSearchActive {
                    searchSuggestionsView
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 56)
            .animation(.spring(response: 0.42, dampingFraction: 0.82), value: searchExpanded)
            .animation(.spring(response: 0.42, dampingFraction: 0.82), value: isSearchActive)

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        if isLayersExpanded {
                            ForEach(MapLayerType.allCases.filter { $0 != currentMapLayer }) { layer in
                                FloatingMapButton(icon: layer.icon) {
                                    mapLayerRaw = layer.rawValue
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { isLayersExpanded = false }
                                }
                                .transition(.scale(scale: 0.5).combined(with: .opacity))
                            }
                        }
                        FloatingMapButton(icon: "square.3.layers.3d", active: isLayersExpanded) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isLayersExpanded.toggle()
                            }
                        }
                        FloatingMapButton3D(is3D: is3DMode) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                is3DMode.toggle()
                            }
                        }
                        FloatingMapButton(icon: "location.fill") { flyToMyLocation() }
                    }
                    .padding(.trailing, 12)
                }
                Spacer()
            }

            VStack {
                Spacer()
                if isRouteCreationMode {
                    routeCreationPanel
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else if !searchExpanded {
                    discoverySheet
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isRouteCreationMode)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedMountain?.id)
        }
        .ignoresSafeArea()
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .sheet(item: $selectedMountain, onDismiss: {
            selectedMarkerTag = nil
            selectedRouteToShow = nil
        }) { mountain in
            ExploreMountainDetailSheet(
                mountain: mountain,
                locationManager: locationManager,
                isPrestigePeak: mountain.isPrestigePeak,
                onDismiss: {
                    selectedMountain = nil
                    selectedMarkerTag = nil
                    selectedRouteToShow = nil
                },
                onStartTracking: {
                    selectedMountain = nil
                    selectedMarkerTag = nil
                    selectedRouteToShow = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        mountainToTrack = mountain
                        showTracker = true
                    }
                }
            )
            .presentationDetents([.fraction(0.4), .large])
            .presentationDragIndicator(.visible)
            .adaptiveSheetBackground()
            .preferredColorScheme(.light)
        }
        .task {
            await mountainManager.fetchSavedRoutes()
            if let _ = locationManager.userLocation, !hasCenteredOnUser {
                flyToMyLocation()
                hasCenteredOnUser = true
            }
        }
        .onChange(of: locationManager.userLocation) { _, newLoc in
            if let _ = newLoc, !hasCenteredOnUser {
                flyToMyLocation()
                hasCenteredOnUser = true
            }
        }
        .onChange(of: isSearchFocused) { _, focused in
            withAnimation(.spring()) {
                isSearchActive = focused
                if focused { searchExpanded = true }
            }
            if focused { Task { await mountainManager.fetchTopMountains() } }
        }
        .onChange(of: searchText) { _, _ in performDebouncedSearch() }
        .onChange(of: mountainManager.mountains) { _, _ in Task { await fetchChampions() } }
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
        .onChange(of: mountainToTrack) { _, mt in
            if let target = mt {
                appState.activeMountain = target
                withAnimation { appState.isTrackerActive = true }
                mountainToTrack = nil // reset
            }
        }
        .alert("Location Access Denied", isPresented: $showLocationDeniedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please enable location services for Ascend in your iPhone Settings to use this feature.")
        }
        .preferredColorScheme(.light)
        .sheet(item: $routeForDetailSheet) { route in
            RouteDetailSheet(route: route, routeManager: RouteSavingManager.shared)
                .presentationDetents([.large])
                .preferredColorScheme(.light)
        }
        .sheet(isPresented: $showMyRoutesLibrary) {
            NavigationView {
                MyRoutesView()
                    .environmentObject(appState)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Close") { showMyRoutesLibrary = false }
                                .font(.app(.body).weight(.bold))
                        }
                    }
            }
            .presentationDetents([.large])
            .preferredColorScheme(.light)
        }
        .onChange(of: appState.exploreSelectedMountain) { _, mt in
            if let target = mt {
                selectedMountain = target
                selectedMarkerTag = target.id
                appState.exploreSelectedMountain = nil // Reset state after consumption
            }
        }
        .onChange(of: appState.exploreSearchQuery) { _, query in
            if let q = query {
                searchText = q
                isSearchFocused = true
                appState.exploreSearchQuery = nil
            }
        }
    }

    var mapLayer: some View {
        MapReader { proxy in
        Map(viewport: $viewport) {
            Puck2D(bearing: .heading)

            ForEvery(visibleMountains, id: \.id) { mountain in
                let coord = CLLocationCoordinate2D(latitude: mountain.latitude ?? 0, longitude: mountain.longitude ?? 0)
                
                if isRouteCreationMode {
                    if let idx = routeMountains.firstIndex(where: { $0.id == mountain.id }) {
                        MapViewAnnotation(coordinate:coord) {
                            ZStack {
                                Circle().fill(gold).frame(width: 32, height: 32)
                                Text("\(idx + 1)").font(.app(size: 14, weight: .black)).foregroundColor(.black)
                            }
                            .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                            .onTapGesture { selectedMarkerTag = mountain.id }
                        }
                        .allowOverlap(true)
                    } else {
                        MapViewAnnotation(coordinate:coord) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title)
                                .foregroundColor(.primary.opacity(0.7))
                                .background(Circle().fill(Color.white.opacity(0.8)).frame(width: 20, height: 20))
                                .onTapGesture { selectedMarkerTag = mountain.id }
                        }
                        .allowOverlap(true)
                    }
                }
                else if selectedMountain?.id == mountain.id {
                    MapViewAnnotation(coordinate:coord) {
                        VStack(spacing: 0) {
                            Text(mountain.name)
                                .font(.app(size: 13, weight: .bold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(gold)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                                .shadow(color: .black.opacity(0.4), radius: 5, y: 3)
                            
                            Image(systemName: "triangle.fill")
                                .font(.app(size: 12))
                                .foregroundColor(gold)
                                .rotationEffect(.degrees(180))
                                .offset(y: -2)
                        }
                    }
                    .allowOverlap(true)
                }
                else {
                    MapViewAnnotation(coordinate: coord) {
                        MountainMapPin(
                            mountain: mountain,
                            champion: mountainChampions[mountain.id],
                            color: mountain.isPrestigePeak ? gold : difficultyColor(mountain.difficulty)
                        ) { selectMountain(mountain) }
                    }
                    .allowOverlap(true)
                }
            }

            if showNearby {
                ForEvery(mountainManager.nearbyPOIs) { poi in
                    MapViewAnnotation(coordinate:CLLocationCoordinate2D(latitude: poi.latitude, longitude: poi.longitude)) {
                        Image(systemName: poiIcon(for: poi.type))
                            .font(.app(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 26, height: 26)
                            .background(poiColor(for: poi.type))
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
                    }
                    .allowOverlap(true)
                }
            }

            if isRouteCreationMode && routeMountains.count >= 2 {
                let coords = routeMountains.compactMap { m -> CLLocationCoordinate2D? in
                    guard let lat = m.latitude, let lon = m.longitude else { return nil }
                    return CLLocationCoordinate2D(latitude: lat, longitude: lon)
                }
                PolylineAnnotation(lineCoordinates: coords)
                    .lineColor(StyleColor(UIColor(gold)))
                    .lineWidth(3.0)
            }
            
            if let route = selectedRouteToShow {
                let routeMountainsList = route.mountainIds.compactMap { id in mountainManager.mountains.first { $0.id == id } }
                let coords = routeMountainsList.compactMap { m -> CLLocationCoordinate2D? in
                    guard let lat = m.latitude, let lon = m.longitude else { return nil }
                    return CLLocationCoordinate2D(latitude: lat, longitude: lon)
                }
                PolylineAnnotation(lineCoordinates: coords)
                    .lineColor(StyleColor(UIColor(gold)))
                    .lineWidth(4.0)
            }
        }
        .mapStyle(mapStyleForCurrentLayer)
        .onStyleLoaded { _ in
            guard let map = proxy.map else { return }
            var demSource = RasterDemSource(id: "mapbox-dem")
            demSource.url = "mapbox://mapbox.mapbox-terrain-dem-v1"
            try? map.addSource(demSource)

            var terrain = Terrain(sourceId: "mapbox-dem")
            terrain.exaggeration = .constant(1.5)
            try? map.setTerrain(terrain)

            MapTileOverlayHelper.apply(layer: currentMapLayer, to: map)
        }
        .onCameraChanged { cameraChanged in
            cameraCenter = cameraChanged.cameraState.center
            cameraZoom   = cameraChanged.cameraState.zoom
            let center = cameraCenter
            let zoom = cameraZoom

            let newZoom: ZoomLevel
            if zoom < 9 { newZoom = .far }
            else if zoom < 11.5 { newZoom = .medium }
            else { newZoom = .close }

            if currentZoomLevel != newZoom {
                withAnimation(.easeInOut(duration: 0.2)) { currentZoomLevel = newZoom }
            }

            let span = 360.0 / pow(2.0, zoom)
            let latDelta = span * 0.8
            let lonDelta = span

            let minLat = center.latitude - latDelta
            let maxLat = center.latitude + latDelta
            let minLon = center.longitude - lonDelta
            let maxLon = center.longitude + lonDelta

            mapFetchTask?.cancel()
            // Longer debounce in 3D mode — camera rotates constantly, avoid rapid refetches
            let debounce: UInt64 = is3DMode ? 900_000_000 : 500_000_000
            mapFetchTask = Task {
                try? await Task.sleep(nanoseconds: debounce)
                guard !Task.isCancelled else { return }
                await mountainManager.fetchMountainsInBounds(minLat: minLat, maxLat: maxLat, minLon: minLon, maxLon: maxLon, zoomLevel: newZoom)
            }
        }
        .onChange(of: is3DMode) { _, enabled in
            guard let map = proxy.map else { return }
            var terrain = Terrain(sourceId: "mapbox-dem")
            terrain.exaggeration = .constant(enabled ? 1.5 : 0)
            try? map.setTerrain(terrain)
            withAnimation(.easeInOut(duration: 0.5)) {
                viewport = .camera(center: cameraCenter, zoom: cameraZoom, bearing: 0, pitch: enabled ? 50 : 0)
            }
        }
        .onChange(of: currentMapLayer) { _, _ in
            guard let map = proxy.map else { return }
            MapTileOverlayHelper.apply(layer: currentMapLayer, to: map)
        }
        .ignoresSafeArea()
        } // end MapReader
        .ignoresSafeArea()
    }

    var mapStyleForCurrentLayer: MapboxMaps.MapStyle {
        switch currentMapLayer {
        case .standard:  return .outdoors
        case .satellite: return .satelliteStreets
        case .night:     return .dark
        case .topo, .swissTopo: return .light
        case .slope:     return .satelliteStreets // slope overlay on satellite for terrain context
        }
    }

    @ViewBuilder
    var floatingSearchArea: some View {
        HStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                    searchExpanded.toggle()
                    if !searchExpanded {
                        searchText = ""
                        isSearchFocused = false
                        isSearchActive = false
                        selectedDifficulty = nil
                    }
                }
            } label: {
                ZStack {
                    if !searchExpanded {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 44, height: 44)
                            .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
                    }
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                        .rotationEffect(.degrees(searchExpanded ? 90 : 0))
                }
            }
            .padding(.leading, 4)

            if searchExpanded {
                HStack(spacing: 10) {
                    TextField("Search peaks, regions…", text: $searchText)
                        .focused($isSearchFocused)
                        .font(.app(size: 15))
                        .foregroundColor(.primary)
                    
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                        }
                    } else {
                        Button {
                            withAnimation { searchExpanded = false }
                        } label: {
                            Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.1), radius: 6, y: 2)
                .padding(.leading, 8)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .leading)).combined(with: .scale(scale: 0.9)),
                    removal: .opacity.combined(with: .move(edge: .leading))
                ))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }


    @ViewBuilder
    var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundColor(.gray).font(.app(size: 16, weight: .medium))
            TextField("Search peaks, regions or countries…", text: $searchText)
                .focused($isSearchFocused).foregroundColor(.primary).autocorrectionDisabled().textInputAutocapitalization(.never)

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
        .clipShape(RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.08), lineWidth: 0.5))
    }

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
                            Text("\(Int(radius))km").font(.app(size: 10, weight: .bold))
                                .foregroundColor(nearbyRadiusKm == radius ? .white : .primary.opacity(0.7))
                                .padding(.horizontal, 8).padding(.vertical, 6)
                                .background(nearbyRadiusKm == radius ? gold : Color.black.opacity(0.05)).clipShape(Capsule())
                        }
                    }
                }

                ToolbarButton(icon: isRouteCreationMode ? "xmark" : "pencil.line", label: isRouteCreationMode ? "Cancel" : "Route", isActive: isRouteCreationMode) {
                    withAnimation(.spring()) {
                        if isRouteCreationMode {
                            isRouteCreationMode = false
                            routeMountains = []
                            routeName = ""
                            routeDescription = ""
                            routeSportType = .hiking
                            routeVisibility = .privateRoute
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

    @ViewBuilder
    var searchSuggestionsView: some View {
        let suggestions = Array(visibleMountains.prefix(10))
        VStack(spacing: 0) {
            if !searchText.isEmpty {
                HStack { Text("\(visibleMountains.count) results").font(.app(size: 11, weight: .semibold)).foregroundColor(.gray); Spacer() }
                    .padding(.horizontal, 14).padding(.vertical, 8).background(Color.gray.opacity(0.05))
            }

            if suggestions.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "mountain.2").font(.app(.title2)).foregroundColor(.gray.opacity(0.4))
                    Text("No peaks found").font(.app(.caption)).foregroundColor(.gray)
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
                                        Text(mountain.name).font(.app(size: 14, weight: .semibold)).foregroundColor(.primary)
                                        Text("\(mountain.region) · \(mountain.elevation)m").font(.app(size: 11)).foregroundColor(.gray)
                                    }
                                    Spacer()
                                    Text(mountain.difficulty.rawValue).font(.app(size: 10, weight: .bold)).foregroundColor(difficultyColor(mountain.difficulty))
                                }.padding(.horizontal, 14).padding(.vertical, 10)
                            }
                            if index < suggestions.count - 1 { Divider().background(Color.black.opacity(0.06)) }
                        }
                    }
                }.frame(maxHeight: 320)
            }
        }
        .background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.08), lineWidth: 0.5))
    }



    func layerPreviewColor(_ layer: MapLayerType) -> LinearGradient {
        switch layer {
        case .standard: return LinearGradient(colors: [.gray.opacity(0.3), .gray.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .satellite: return LinearGradient(colors: [.green.opacity(0.3), .blue.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .night: return LinearGradient(colors: [.indigo.opacity(0.4), .black.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .topo: return LinearGradient(colors: [.brown.opacity(0.35), .green.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .swissTopo: return LinearGradient(colors: [.red.opacity(0.3), .yellow.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .slope: return LinearGradient(colors: [.orange.opacity(0.45), .red.opacity(0.30)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    // Computed route stats for live preview in route creator
    private var routeDistanceKm: Double {
        guard routeMountains.count >= 2 else { return 0 }
        var total = 0.0
        for i in 1..<routeMountains.count {
            guard let lat1 = routeMountains[i-1].latitude, let lon1 = routeMountains[i-1].longitude,
                  let lat2 = routeMountains[i].latitude, let lon2 = routeMountains[i].longitude else { continue }
            total += CLLocation(latitude: lat1, longitude: lon1).distance(from: CLLocation(latitude: lat2, longitude: lon2)) / 1000.0
        }
        return total
    }

    private var routeElevationGain: Int {
        guard !routeMountains.isEmpty else { return 0 }
        var gain = routeMountains[0].elevation / 2
        for i in 1..<routeMountains.count {
            let delta = routeMountains[i].elevation - routeMountains[i-1].elevation
            if delta > 0 { gain += delta }
        }
        return gain
    }

    private var routeEstimatedDuration: String {
        let elevH = Double(routeElevationGain) / 400.0
        let horizH = routeDistanceKm / 4.0
        let totalH = max(elevH, horizH) + min(elevH, horizH) * 0.5
        if totalH < 1 { return "\(max(1, Int(totalH * 60)))min" }
        return String(format: "%.0f-%.0fh", totalH, totalH * 1.3)
    }

    @ViewBuilder
    var routeCreationPanel: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "pencil.line").foregroundColor(gold)
                Text("Route Creator").font(.app(size: 16, weight: .bold)).foregroundColor(.primary)
                Spacer()
                Text("\(routeMountains.count) peaks").font(.app(size: 12, weight: .semibold)).foregroundColor(gold)
            }

            TextField("Route name…", text: $routeName).textFieldStyle(.plain).padding(10)
                .background(Color.gray.opacity(0.1)).cornerRadius(10).foregroundColor(.primary)

            TextField("Description (optional)…", text: $routeDescription).textFieldStyle(.plain).padding(10)
                .background(Color.gray.opacity(0.1)).cornerRadius(10).foregroundColor(.primary)
                .font(.app(size: 14))

            // Sport type + visibility row
            HStack(spacing: 8) {
                Menu {
                    ForEach(SportType.allCases, id: \.self) { sport in
                        Button { routeSportType = sport } label: {
                            Label(sport.label, systemImage: sport.icon)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: routeSportType.icon).font(.app(size: 11))
                        Text(routeSportType.label).font(.app(size: 11, weight: .semibold))
                        Image(systemName: "chevron.down").font(.app(size: 8))
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .background(Color.gray.opacity(0.1)).clipShape(Capsule())
                }

                Menu {
                    ForEach(RouteVisibility.allCases, id: \.self) { vis in
                        Button { routeVisibility = vis } label: {
                            Label(vis.label, systemImage: vis.icon)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: routeVisibility.icon).font(.app(size: 11))
                        Text(routeVisibility.label).font(.app(size: 11, weight: .semibold))
                        Image(systemName: "chevron.down").font(.app(size: 8))
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .background(Color.gray.opacity(0.1)).clipShape(Capsule())
                }

                Spacer()
            }

            if !routeMountains.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(routeMountains.enumerated()), id: \.element.id) { index, mountain in
                            HStack(spacing: 4) {
                                Text("\(index + 1)").font(.app(size: 10, weight: .black)).foregroundColor(.black).frame(width: 18, height: 18).background(gold).clipShape(Circle())
                                Text(mountain.name).font(.app(size: 11, weight: .semibold)).foregroundColor(.white).lineLimit(1)
                                Button { routeMountains.removeAll { $0.id == mountain.id } } label: { Image(systemName: "xmark.circle.fill").font(.app(size: 12)).foregroundColor(.gray) }
                            }.padding(.horizontal, 8).padding(.vertical, 6).background(Color.white.opacity(0.1)).cornerRadius(8)
                        }
                    }
                }

                // Live route stats
                HStack(spacing: 0) {
                    DetailStat(icon: "point.topleft.down.to.point.bottomright.curvepath", value: String(format: "%.1fkm", routeDistanceKm), label: "Distance")
                    DetailStat(icon: "arrow.up.right", value: "+\(routeElevationGain)m", label: "Elevation")
                    DetailStat(icon: "clock", value: routeEstimatedDuration, label: "Est. Time")
                    DetailStat(icon: "figure.hiking", value: routeMountains.map { $0.difficulty.rawValue }.max() ?? "–", label: "Difficulty")
                }
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.03))
                .cornerRadius(10)

                // Mini elevation profile
                if routeMountains.count >= 2 {
                    RouteElevationProfile(mountains: routeMountains, accentColor: gold)
                        .frame(height: 60)
                        .padding(.horizontal, 4)
                }
            }

            HStack(spacing: 12) {
                Button { withAnimation(.spring()) { isRouteCreationMode = false; routeMountains = []; routeName = ""; routeDescription = ""; routeSportType = .hiking; routeVisibility = .privateRoute } } label: {
                    Text("Cancel").font(.app(size: 14, weight: .bold)).foregroundColor(.primary).frame(maxWidth: .infinity).padding(.vertical, 12).background(Color.gray.opacity(0.1)).cornerRadius(12)
                }
                Button { saveCreatedRoute() } label: {
                    HStack(spacing: 4) { Image(systemName: "checkmark"); Text("Save Route") }.font(.app(size: 14, weight: .bold)).foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 12).background(routeMountains.count >= 2 ? gold : gold.opacity(0.3)).cornerRadius(12)
                }.disabled(routeMountains.count < 2)
            }
        }
        .padding(16).background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.black.opacity(0.05), lineWidth: 0.5))
        .padding(.horizontal, 16)
        .padding(.bottom, 120)
    }

    @ViewBuilder
    var discoverySheet: some View {
        let nearbyCards: [Mountain] = {
            var result: [Mountain]
            if let loc = locationManager.userLocation {
                result = visibleMountains.sorted { m1, m2 in
                    let loc1 = CLLocation(latitude: m1.latitude ?? 0, longitude: m1.longitude ?? 0)
                    let loc2 = CLLocation(latitude: m2.latitude ?? 0, longitude: m2.longitude ?? 0)
                    return loc.distance(from: loc1) < loc.distance(from: loc2)
                }
            } else {
                result = Array(visibleMountains)
            }
            if result.count < 6 {
                let ids = Set(result.map { $0.id })
                let extra = mountainManager.mountains
                    .filter { $0.latitude != nil && $0.longitude != nil && !ids.contains($0.id) }
                    .prefix(15 - result.count)
                result += Array(extra)
            }
            return Array(result.prefix(15))
        }()

        let forYouCards = fitnessMatchedMountains
        let savedRoutes = mountainManager.savedRoutes

        VStack(alignment: .leading, spacing: 0) {
            // Drag handle with pulse hint
            HStack { Spacer(); SheetDragHandle(); Spacer() }
                .padding(.top, 12).padding(.bottom, 8).contentShape(Rectangle())
                .onTapGesture { withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { discoverySheetExpanded.toggle() } }

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {

                    // "For Your Level" section — shown when fitness profile is set
                    if !forYouCards.isEmpty && !showRoutesFilter {
                        let levelName = userFitnessLevel > 0 ? fitnessLevels[min(userFitnessLevel - 1, fitnessLevels.count - 1)].title : "You"
                        discoverySectionHeader(title: "For Your Level · \(levelName)", icon: "figure.hiking")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                Spacer().frame(width: 4)
                                ForEach(Array(forYouCards.enumerated()), id: \.element.id) { index, mountain in
                                    ExploreDiscoveryCard(
                                        mountain: mountain,
                                        userLocation: locationManager.userLocation,
                                        compact: true,
                                        entranceDelay: Double(index) * 0.06
                                    ) { selectMountain(mountain) }
                                }
                                Spacer().frame(width: 4)
                            }
                        }
                    }

                    // Nearby Missions — always show when no fitness filter active or as fallback
                    if !nearbyCards.isEmpty && !showRoutesFilter && (forYouCards.isEmpty || discoverySheetExpanded) {
                        discoverySectionHeader(title: "Nearby Missions", icon: "mountain.2.fill")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                Spacer().frame(width: 4)
                                ForEach(Array(nearbyCards.enumerated()), id: \.element.id) { index, mountain in
                                    ExploreDiscoveryCard(
                                        mountain: mountain,
                                        userLocation: locationManager.userLocation,
                                        compact: true,
                                        entranceDelay: Double(index) * 0.05
                                    ) { selectMountain(mountain) }
                                }
                                Spacer().frame(width: 4)
                            }
                        }
                    }

                    if discoverySheetExpanded || showRoutesFilter || (nearbyCards.isEmpty && forYouCards.isEmpty) {
                        HStack {
                            discoverySectionHeader(title: "My Routes", icon: "bookmark.fill")
                            Button { showMyRoutesLibrary = true } label: {
                                Text("Library")
                                    .font(.app(size: 11, weight: .bold))
                                    .foregroundColor(gold)
                                    .padding(.horizontal, 10).padding(.vertical, 5)
                                    .background(gold.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                            .padding(.trailing, 16)
                        }
                        if savedRoutes.isEmpty {
                            HStack { Spacer(); VStack(spacing: 6) { Image(systemName: "map").font(.app(.title2)).foregroundColor(.gray.opacity(0.3)); Text("No saved routes yet.").font(.app(.caption)).foregroundColor(.gray) }; Spacer() }.padding(.vertical, 16)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    Spacer().frame(width: 4)
                                    ForEach(savedRoutes) { route in
                                        SavedRouteCard(route: route, onTap: {
                                            routeForDetailSheet = route
                                            selectedRouteToShow = route
                                            if let firstId = route.mountainIds.first, let firstM = mountainManager.mountains.first(where: { $0.id == firstId }), let lat = firstM.latitude, let lon = firstM.longitude {
                                                flyTo(lat: lat, lon: lon, distance: 12000)
                                            }
                                        }, onDelete: { Task { await mountainManager.deleteRoute(id: route.id) } })
                                    }
                                    Spacer().frame(width: 4)
                                }
                            }
                        }
                    }
                }.padding(.bottom, 16)
            }
            .frame(maxHeight: discoverySheetExpanded ? 440 : 220)
        }
        .background(.ultraThinMaterial.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.3), radius: 15, y: 5)
        .padding(.horizontal, 16)
        .padding(.bottom, 120)
    }

    @ViewBuilder
    func discoverySectionHeader(title: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon).font(.app(size: 13, weight: .bold)).foregroundColor(gold)
            Text(title).font(.app(size: 15, weight: .bold)).foregroundColor(.primary)
            Spacer()
            if !discoverySheetExpanded {
                Button { withAnimation(.spring()) { discoverySheetExpanded = true } } label: { Text("See All").font(.app(size: 12, weight: .semibold)).foregroundColor(gold) }
            }
        }.padding(.horizontal, 16)
    }

    // 🟢 NEU: Die Detail-Karte ist schlanker und hat keinen leeren Block mehr!


    func flyToMyLocation() {
        if let loc = locationManager.userLocation {
            withAnimation(.easeInOut(duration: 1.5)) {
                viewport = .camera(center: loc.coordinate, zoom: 12, bearing: 0, pitch: 0)
            }
        } else {
            if locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted {
                showLocationDeniedAlert = true
            } else {
                locationManager.requestLocationSafely()
            }
        }
    }

    func poiIcon(for type: String) -> String {
        switch type.lowercased() {
        case "parking": return "p.circle.fill"
        case "viewpoint", "scenic": return "eye.fill"
        case "hut", "shelter", "cabin": return "house.fill"
        case "restaurant", "food": return "fork.knife"
        case "water", "spring": return "drop.fill"
        case "campsite", "camping": return "tent.fill"
        case "info", "information": return "info.circle.fill"
        default: return "mappin"
        }
    }

    func poiColor(for type: String) -> Color {
        switch type.lowercased() {
        case "parking": return .blue
        case "viewpoint", "scenic": return .orange
        case "hut", "shelter", "cabin": return .brown
        case "restaurant", "food": return .red
        case "water", "spring": return .cyan
        case "campsite", "camping": return .green
        default: return .gray
        }
    }

    func difficultyColor(_ diff: Difficulty) -> Color {
        switch diff {
        case .easy: return .green
        case .medium: return .yellow
        case .hard: return .orange
        case .extreme: return .red
        case .expert: return .purple
        }
    }

    func estimatedDuration(for mountain: Mountain) -> String {
        let hours = Double(mountain.elevation) / 800.0
        if hours < 1 { return "\(Int(hours * 60))min" }
        return String(format: "%.0f-%.0fh", hours, hours * 1.3)
    }

    func selectMountain(_ mountain: Mountain) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            selectedMountain = mountain; selectedMarkerTag = mountain.id; isSearchFocused = false; isSearchActive = false; searchExpanded = false; searchText = ""; selectedRouteToShow = nil
        }
        if let lat = mountain.latitude, let lon = mountain.longitude { flyToMountain(lat: lat, lon: lon) }
    }

    func flyToMountain(lat: Double, lon: Double) {
        withAnimation(.easeInOut(duration: 1.5)) {
            viewport = .camera(center: CLLocationCoordinate2D(latitude: lat, longitude: lon), zoom: 11.5, bearing: 0, pitch: 45)
        }
    }

    func flyTo(lat: Double, lon: Double, distance: Double) {
        let zoom = max(5.0, 15.0 - log2(max(1000, distance) / 1000.0))
        withAnimation(.easeInOut(duration: 1.5)) {
            viewport = .camera(center: CLLocationCoordinate2D(latitude: lat, longitude: lon), zoom: zoom, bearing: 0, pitch: 45)
        }
    }

    func refreshResults() async {
        await mountainManager.fetchTopMountains()
        performDebouncedSearch()
    }

    func performDebouncedSearch() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            Task {
                await mountainManager.searchMountains(query: searchText, difficulty: selectedDifficulty)
            }
        }
    }

    func fetchChampions() async {
        let names = Array(Set(visibleMountains.map { $0.name }))
        guard !names.isEmpty else { return }

        struct ChampRow: Codable {
            let name: String
            let user_id: UUID
            let duration_seconds: Int?
        }
        guard let rows: [ChampRow] = try? await supabase
            .from("tours")
            .select("name, user_id, duration_seconds")
            .in("name", values: names)
            .execute()
            .value else { return }

        // Find fastest per mountain name
        var fastest: [String: ChampRow] = [:]
        for row in rows {
            guard let dur = row.duration_seconds, dur > 0 else { continue }
            if let ex = fastest[row.name], let exDur = ex.duration_seconds, exDur <= dur { continue }
            fastest[row.name] = row
        }
        guard !fastest.isEmpty else { return }

        let userIds = Array(Set(fastest.values.map { $0.user_id }))
        let profiles: [ShareableUser] = (try? await supabase
            .from("profiles")
            .select("id, username, avatar_url, handle")
            .in("id", values: userIds)
            .execute()
            .value) ?? []
        
        var profileMap: [UUID: ShareableUser] = [:]
        for profile in profiles {
            profileMap[profile.id] = profile
        }

        var result: [UUID: MountainChampion] = [:]
        for mountain in visibleMountains {
            if let champ = fastest[mountain.name] {
                let p = profileMap[champ.user_id]
                result[mountain.id] = MountainChampion(
                    userId: champ.user_id,
                    avatarUrl: p?.avatar_url,
                    username: p?.username ?? "?"
                )
            }
        }
        mountainChampions = result
    }

    func saveCreatedRoute() {
        guard !routeMountains.isEmpty, !routeName.isEmpty else { return }

        // Build route polyline from mountain coordinates
        let coords = routeMountains.compactMap { m -> CLLocation? in
            guard let lat = m.latitude, let lon = m.longitude else { return nil }
            return CLLocation(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                              altitude: Double(m.elevation), horizontalAccuracy: 0, verticalAccuracy: 0, timestamp: Date())
        }
        let polyline = RouteEncoder.encode(coords)

        // Determine difficulty from hardest peak
        let maxDiff = routeMountains.map { $0.difficulty.rawValue }.max() ?? "Medium"

        let newRoute = SavedRoute(
            name: routeName,
            description: routeDescription,
            mountainIds: routeMountains.map { $0.id },
            routePolyline: polyline,
            totalDistanceKm: routeDistanceKm,
            totalElevationGain: routeElevationGain,
            estimatedDurationMinutes: Int(routeDistanceKm * 15 + Double(routeElevationGain) / 10),
            difficulty: maxDiff,
            visibility: routeVisibility,
            sportType: routeSportType
        )
        Task {
            await mountainManager.saveRoute(newRoute)
            withAnimation(.spring()) {
                isRouteCreationMode = false
                routeMountains = []
                routeName = ""
                routeDescription = ""
                routeSportType = .hiking
                routeVisibility = .privateRoute
            }
        }
    }
}

// =========================================
// === SINGLE MOUNTAIN ELEVATION PREVIEW ===
// =========================================
struct MountainElevationPreview: View {
    let elevation: Int
    let accentColor: Color
    let route: MountainRoute?

    // Simulate a simple ascent profile: start → approach → steep → summit
    private var profilePoints: [(x: Double, y: Double)] {
        let rawPoints: [(x: Double, y: Double)]
        if let route = route, let elevs = route.elevation_profile, !elevs.isEmpty {
            let maxPoints = min(elevs.count, 100)
            let step = Double(elevs.count) / Double(maxPoints)
            rawPoints = (0..<maxPoints).map { i in
                let index = min(Int(Double(i) * step), elevs.count - 1)
                return (Double(i) / Double(max(1, maxPoints - 1)), Double(elevs[index]))
            }
        } else {
            let summit = Double(elevation)
            let start = max(0, summit * 0.15)
            rawPoints = [
                (0.0, start),
                (0.15, start + summit * 0.05),
                (0.3, start + summit * 0.2),
                (0.5, start + summit * 0.45),
                (0.7, start + summit * 0.75),
                (0.85, start + summit * 0.92),
                (1.0, summit)
            ]
        }
        
        let maxY = rawPoints.map(\.y).max() ?? 1.0
        let minY = rawPoints.map(\.y).min() ?? 0.0
        let range = max(maxY - minY, 1.0)
        
        return rawPoints.map { (x: $0.x, y: ($0.y - minY) / range) }
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let padY: CGFloat = 6
            let usableHeight = max(h - padY * 2, 10)
            
            let mappedPoints = profilePoints.map { 
                CGPoint(x: $0.x * w, y: padY + usableHeight - $0.y * usableHeight)
            }
            
            let path = Path { p in
                guard !mappedPoints.isEmpty else { return }
                var previousPoint = mappedPoints[0]
                p.move(to: previousPoint)
                
                for i in 1..<mappedPoints.count {
                    let currentPoint = mappedPoints[i]
                    let controlPoint1 = CGPoint(x: (previousPoint.x + currentPoint.x) / 2, y: previousPoint.y)
                    let controlPoint2 = CGPoint(x: (previousPoint.x + currentPoint.x) / 2, y: currentPoint.y)
                    p.addCurve(to: currentPoint, control1: controlPoint1, control2: controlPoint2)
                    previousPoint = currentPoint
                }
            }

            let fillPath = Path { p in
                guard !mappedPoints.isEmpty else { return }
                p.move(to: CGPoint(x: w, y: h))
                p.addLine(to: CGPoint(x: 0, y: h))
                
                var previousPoint = mappedPoints[0]
                p.addLine(to: previousPoint)
                
                for i in 1..<mappedPoints.count {
                    let currentPoint = mappedPoints[i]
                    let controlPoint1 = CGPoint(x: (previousPoint.x + currentPoint.x) / 2, y: previousPoint.y)
                    let controlPoint2 = CGPoint(x: (previousPoint.x + currentPoint.x) / 2, y: currentPoint.y)
                    p.addCurve(to: currentPoint, control1: controlPoint1, control2: controlPoint2)
                    previousPoint = currentPoint
                }
            }
            
            ZStack(alignment: .leading) {
                // Background gradient
                LinearGradient(colors: [accentColor.opacity(0.15), accentColor.opacity(0.05)], startPoint: .top, endPoint: .bottom)

                // Fill underneath curve
                fillPath
                    .fill(LinearGradient(colors: [accentColor.opacity(0.4), accentColor.opacity(0.0)], startPoint: .top, endPoint: .bottom))

                // Smooth elevation line
                path.stroke(accentColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .frame(height: 50)
    }
}

// MARK: - Reusable UI Components
struct FloatingMapButton: View {
    let icon: String
    var active: Bool = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.app(size: 20, weight: .semibold))
                .foregroundColor(active ? .white : .black)
                .frame(width: 44, height: 44)
                .background(active ? AnyShapeStyle(DesignSystem.Colors.accent) : AnyShapeStyle(.ultraThinMaterial))
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        }
    }
}

struct FloatingMapButton3D: View {
    let is3D: Bool
    let action: () -> Void
    private let gold = DesignSystem.Colors.accent
    var body: some View {
        Button(action: action) {
            Text(is3D ? "3D" : "2D")
                .font(.system(size: 14, weight: .black))
                .foregroundColor(is3D ? .white : .black)
                .frame(width: 44, height: 44)
                .background(is3D ? AnyShapeStyle(gold) : AnyShapeStyle(.ultraThinMaterial))
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        }
    }
}

// MARK: - Pin Pointer Shape
private struct PinPointer: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.closeSubpath()
        }
    }
}

// MARK: - Mountain Map Pin
struct MountainMapPin: View {
    let mountain: Mountain
    let champion: MountainChampion?
    let color: Color
    let onTap: () -> Void

    @State private var appeared = false
    @State private var tapped = false

    private var elevationLabel: String {
        let e = mountain.elevation
        return e >= 1000 ? String(format: "%gk", Double(e) / 1000) : "\(e)"
    }

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.6)) { tapped = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) { tapped = false }
            }
            onTap()
        } label: {
            pinContent
        }
        .buttonStyle(.plain)
        .scaleEffect(appeared ? (tapped ? 1.18 : 1.0) : 0.6)
        .opacity(appeared ? 1 : 0)
        .animation(.easeOut(duration: 0.18), value: appeared)
        .animation(.spring(response: 0.22, dampingFraction: 0.6), value: tapped)
        .onAppear {
            withAnimation(.easeOut(duration: 0.2)) { appeared = true }
        }
    }

    @ViewBuilder
    var pinContent: some View {
        if let champ = champion, let avatarUrlStr = champ.avatarUrl, let avatarUrl = URL(string: avatarUrlStr) {
            // Champion avatar pin
            VStack(spacing: 0) {
                CachedAsyncImage(url: avatarUrl) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(color.opacity(0.3))
                }
                .frame(width: 34, height: 34)
                .clipShape(Circle())
                .overlay(Circle().stroke(color, lineWidth: 2))
                .overlay(
                    Image(systemName: "crown.fill")
                        .font(.system(size: 7, weight: .black))
                        .foregroundColor(.white)
                        .padding(2)
                        .background(color)
                        .clipShape(Circle())
                        .offset(x: 11, y: -11),
                    alignment: .topTrailing
                )
                .shadow(color: color.opacity(0.45), radius: 5, y: 2)

                PinPointer()
                    .fill(color)
                    .frame(width: 8, height: 5)
                    .offset(y: -1)
            }
        } else if mountain.isPrestigePeak {
            // Prestige peak — gold badge with crown
            VStack(spacing: 0) {
                HStack(spacing: 3) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 7, weight: .black))
                    Text(elevationLabel)
                        .font(.system(size: 10, weight: .black, design: .rounded))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .shadow(color: color.opacity(0.55), radius: 5, y: 2)

                PinPointer()
                    .fill(color)
                    .frame(width: 7, height: 4)
                    .offset(y: -1)
            }
        } else {
            // Standard elevation badge
            VStack(spacing: 0) {
                Text(elevationLabel)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(color)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .shadow(color: color.opacity(0.5), radius: 4, y: 2)

                PinPointer()
                    .fill(color)
                    .frame(width: 7, height: 4)
                    .offset(y: -1)
            }
        }
    }
}

// MARK: - Animated Drag Handle
struct SheetDragHandle: View {
    @State private var pulse = false

    var body: some View {
        Capsule()
            .fill(Color.white.opacity(pulse ? 0.6 : 0.3))
            .frame(width: 40, height: 4)
            .scaleEffect(x: pulse ? 1.15 : 1.0, y: 1.0)
            .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: pulse)
            .onAppear { pulse = true }
    }
}

struct ToolbarButton: View {
    let icon: String
    let label: String
    let isActive: Bool
    let action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) { pressed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { pressed = false }
            }
            action()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(label).fontWeight(.semibold)
            }
            .font(.app(size: 13))
            .foregroundColor(isActive ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isActive ? DesignSystem.Colors.accent : Color(.systemGray6))
            .clipShape(Capsule())
            .scaleEffect(pressed ? 0.93 : 1.0)
        }
    }
}

struct DifficultyChip: View {
    let label: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.6)) { pressed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { pressed = false }
            }
            action()
        } label: {
            Text(label)
                .font(.app(size: 13, weight: .bold))
                .foregroundColor(isSelected ? .white : color)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? color : color.opacity(0.1))
                .clipShape(Capsule())
                .scaleEffect(isSelected ? 1.05 : (pressed ? 0.93 : 1.0))
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
    }
}

struct DetailStat: View {
    let icon: String
    let value: String
    let label: String
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.app(size: 14, weight: .medium))
                .foregroundColor(.gray)
            Text(value)
                .font(.app(size: 14, weight: .bold))
            Text(label)
                .font(.app(size: 10))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
}

struct RouteElevationProfile: View {
    let mountains: [Mountain]
    let accentColor: Color
    var body: some View {
        MountainElevationPreview(elevation: mountains.max(by: { $0.elevation < $1.elevation })?.elevation ?? 0, accentColor: accentColor, route: nil)
    }
}

struct ExploreDiscoveryCard: View {
    let mountain: Mountain
    let userLocation: CLLocation?
    let compact: Bool
    var entranceDelay: Double = 0
    let action: () -> Void

    private let cardSize: CGFloat = 140
    @State private var appeared = false
    @State private var pressed = false

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.6)) { pressed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { pressed = false }
            }
            action()
        } label: {
            ZStack(alignment: .bottomLeading) {
                if let imgUrl = mountain.effectiveImageUrl, let url = URL(string: imgUrl) {
                    CachedAsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Rectangle().fill(
                            LinearGradient(
                                colors: [difficultyColor.opacity(0.5), difficultyColor.opacity(0.25)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                    }
                } else {
                    Rectangle().fill(
                        LinearGradient(
                            colors: [difficultyColor.opacity(0.5), difficultyColor.opacity(0.25)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Image(systemName: "mountain.2")
                            .font(.system(size: 36, weight: .light))
                            .foregroundColor(.white.opacity(0.4))
                    )
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(mountain.name)
                        .font(.app(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                    Text("\(mountain.elevation)m")
                        .font(.app(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.7)],
                        startPoint: .center, endPoint: .bottom
                    )
                )

                // Difficulty dot top-right
                difficultyColor
                    .frame(width: 8, height: 8)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.8), lineWidth: 1))
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
            .frame(width: cardSize, height: cardSize)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
            .scaleEffect(pressed ? 0.94 : 1.0)
        }
        .buttonStyle(.plain)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .scaleEffect(appeared ? 1 : 0.88)
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.72).delay(entranceDelay)) {
                appeared = true
            }
        }
    }

    private var difficultyColor: Color {
        switch mountain.difficulty {
        case .easy:    return .green
        case .medium:  return .yellow
        case .hard:    return .orange
        case .extreme: return .red
        case .expert:  return .purple
        }
    }
}

struct SavedRouteCard: View {
    let route: SavedRoute
    let onTap: () -> Void
    let onDelete: () -> Void
    private let accent = DesignSystem.Colors.accent

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Sport type icon + name
                HStack(spacing: 6) {
                    Image(systemName: route.sportIcon)
                        .font(.app(size: 10))
                        .foregroundColor(accent)
                    Text(route.name)
                        .font(.app(size: 15, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }

                // Stats row
                HStack(spacing: 10) {
                    HStack(spacing: 2) {
                        Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                            .font(.app(size: 9))
                        Text(String(format: "%.1fkm", route.totalDistanceKm))
                    }
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.up.right")
                            .font(.app(size: 9))
                        Text("+\(route.totalElevationGain)m")
                    }
                    HStack(spacing: 2) {
                        Image(systemName: "mountain.2.fill")
                            .font(.app(size: 9))
                        Text("\(route.mountainIds.count)")
                    }
                }
                .font(.app(size: 11, weight: .medium))
                .foregroundColor(.secondary)

                // Bottom row: difficulty + completed badge
                HStack(spacing: 6) {
                    Text(route.difficulty)
                        .font(.app(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(difficultyColor)
                        .clipShape(Capsule())

                    if route.isCompleted {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.app(size: 11))
                            .foregroundColor(.green)
                    }

                    Spacer()

                    Image(systemName: route.visibility.icon)
                        .font(.app(size: 9))
                        .foregroundColor(.gray)
                }
            }
            .padding(12)
            .frame(width: 200, alignment: .leading)
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button { onTap() } label: { Label("View Details", systemImage: "eye") }
            Button(role: .destructive, action: onDelete) { Label("Delete", systemImage: "trash") }
        }
    }

    private var difficultyColor: Color {
        switch route.difficulty.lowercased() {
        case "easy": return .green
        case "medium": return .blue
        case "hard": return .orange
        case "extreme": return .red
        case "expert": return .purple
        default: return .gray
        }
    }
}

// =========================================
// MARK: - Explore Mountain Detail Sheet
// =========================================
struct ExploreMountainDetailSheet: View {
    let mountain: Mountain
    @ObservedObject var locationManager: ExploreLocationManager
    let isPrestigePeak: Bool
    let onDismiss: () -> Void
    let onStartTracking: () -> Void
    @State private var showCollectionSheet = false
    
    private let gold = Color(red: 0.85, green: 0.65, blue: 0.13)
    private let accent = DesignSystem.Colors.accent

    var body: some View {
        ZStack {
            Color.clear.ignoresSafeArea()
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header Image
                    ZStack(alignment: .topTrailing) {
                        if let urlStr = mountain.effectiveImageUrl, !urlStr.isEmpty, let url = URL(string: urlStr) {
                            CachedAsyncImage(url: url) { img in
                                img.resizable().scaledToFill()
                            } placeholder: {
                                Color(white: 0.9)
                            }.frame(height: 250).clipped()
                        } else {
                            Color(white: 0.9).frame(height: 250)
                            Image(systemName: "mountain.2.fill").font(.app(size: 50)).foregroundColor(Color.black.opacity(0.1))
                        }
                        
                        LinearGradient(colors: [.clear, .white], startPoint: .center, endPoint: .bottom)
                            .frame(height: 250)
                            
                        if let credit = mountain.image_credit, !credit.isEmpty {
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    Text("Foto: \(credit)")
                                        .font(.app(size: 9, weight: .medium))
                                        .foregroundColor(.white.opacity(0.8))
                                        .shadow(color: .black.opacity(0.8), radius: 3, x: 0, y: 1)
                                        .padding(.trailing, 16)
                                        .padding(.bottom, 16)
                                }
                            }
                        }
                        
                        Button { onDismiss() } label: {
                            Image(systemName: "xmark.circle.fill").font(.app(size: 28)).foregroundColor(.primary.opacity(0.6))
                                .background(Circle().fill(Color.white.opacity(0.8)))
                        }.padding(16)
                    }.frame(height: 250)

                    // Info Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(mountain.name).font(.app(size: 28, weight: .bold)).foregroundColor(.primary)
                                Text("\(mountain.region), \(mountain.country)").font(.app(size: 15)).foregroundColor(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(mountain.difficulty.rawValue.uppercased())
                                    .font(.app(size: 10, weight: .black))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10).padding(.vertical, 5)
                                    .background(mountain.difficulty.color)
                                    .clipShape(Capsule())
                                if isPrestigePeak {
                                    HStack(spacing: 3) {
                                        Image(systemName: "crown.fill").font(.app(size: 9))
                                        Text("PRESTIGE").font(.app(size: 9, weight: .black))
                                    }.foregroundColor(gold)
                                }
                            }
                        }
                        
                        HStack(spacing: 0) {
                            statItem(icon: "arrow.up.right", value: "\(mountain.elevation)m", label: "Elevation")
                            statItem(icon: "chart.line.uptrend.xyaxis", value: "~\(mountain.elevation / 2)m", label: "Est. Gain")
                            statItem(icon: "clock", value: estimatedDuration, label: "Est. Time")
                            if let userLoc = locationManager.userLocation, let lat = mountain.latitude, let lon = mountain.longitude {
                                let dist = userLoc.distance(from: CLLocation(latitude: lat, longitude: lon)) / 1000
                                statItem(icon: "location", value: String(format: "%.0fkm", dist), label: "Distance")
                            }
                        }
                        .padding(.vertical, 16)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        
                        // Action buttons row
                        HStack(spacing: 12) {
                            OfflineDownloadButton(mountain: mountain, route: mountain.routes?.first)
                            Spacer()
                            Button(action: { showCollectionSheet = true }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "rectangle.stack.badge.plus")
                                    Text("Collection").font(.app(.subheadline)).fontWeight(.semibold)
                                }
                                .foregroundColor(gold)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(gold.opacity(0.1))
                                .clipShape(Capsule())
                            }
                        }
                        .padding(.bottom, 6)
                        
                        if !mountain.description.isEmpty {
                            Text(mountain.description)
                                .font(.app(size: 14))
                                .foregroundColor(.secondary)
                                .lineSpacing(4)
                        }
                        
                        // Detailed Elevation Profile
                        if let route = mountain.routes?.first, !route.locations.isEmpty {
                            Text("Elevation Profile").font(.app(.headline)).padding(.top, 10)
                            ElevationProfileView(routePoints: route.locations, compact: false)
                        }
                        
                        Spacer(minLength: 20)
                        
                        Button {
                            onStartTracking()
                        } label: {
                            HStack {
                                Image(systemName: "play.fill")
                                Text("Commence Mission")
                            }
                            .font(.app(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(gold)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: gold.opacity(0.3), radius: 10, y: 5)
                        }
                        .padding(.bottom, 30)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .sheet(isPresented: $showCollectionSheet) {
            SaveToCollectionSheet(mountain: mountain)
        }
    }
    
    private var estimatedDuration: String {
        let hours = Double(mountain.elevation) / 800.0
        if hours < 1 { return "\(Int(hours * 60))min" }
        return String(format: "%.0f-%.0fh", hours, hours * 1.3)
    }
    
    private func statItem(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.app(size: 18)).foregroundColor(.secondary)
            Text(value).font(.app(size: 18, weight: .bold)).foregroundColor(.primary)
            Text(label).font(.app(size: 12)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
