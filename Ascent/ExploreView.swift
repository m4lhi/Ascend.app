import SwiftUI
import MapKit
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

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .standard:  return "map"
        case .satellite: return "globe.americas.fill"
        case .night:     return "moon.stars.fill"
        }
    }

    var subtitle: String {
        switch self {
        case .standard:  return "Default map"
        case .satellite: return "Hybrid with labels"
        case .night:     return "Dark map style"
        }
    }
}

// MARK: - ExploreView
struct ExploreView: View {
    @StateObject private var mountainManager = MountainManager()
    @StateObject private var locationManager = ExploreLocationManager()

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var selectedMarkerTag: UUID? = nil
    @State private var selectedMountain: Mountain? = nil

    @FocusState private var isSearchFocused: Bool
    @State private var isSearchActive = false
    @State private var searchText = ""
    @State private var searchTask: Task<Void, Never>? = nil

    @State private var selectedDifficulty: Difficulty? = nil
    @State private var showRoutesFilter = false

    @State private var showNearby = false
    @State private var nearbyRadiusKm: Double = 25

    @State private var currentMapLayer: MapLayerType = .satellite
    @State private var showLayersSheet = false

    @State private var showLocationDeniedAlert = false
    @State private var isRouteCreationMode = false
    @State private var routeMountains: [Mountain] = []
    @State private var routeName = ""

    @State private var discoverySheetExpanded = false

    @State private var currentZoomLevel: ZoomLevel = .medium
    @State private var mapFetchTask: Task<Void, Never>? = nil
    enum ZoomLevel { case far, medium, close }

    @State private var showTracker = false
    @State private var mountainToTrack: Mountain? = nil
    @State private var selectedRouteToShow: SavedRoute? = nil

    @State private var hasCenteredOnUser = false

    private let gold = Color(red: 0.1, green: 0.5, blue: 0.95)

    var mapMountains: [Mountain] {
        var source = showNearby ? mountainManager.nearbyMountains : mountainManager.mountains
        if let diff = selectedDifficulty {
            source = source.filter { $0.difficulty == diff }
        }
        return source.filter { $0.latitude != nil && $0.longitude != nil }
    }

    var visibleMountains: [Mountain] {
        switch currentZoomLevel {
        case .far:    return Array(mapMountains.prefix(50))
        case .medium: return Array(mapMountains.prefix(150))
        case .close:  return Array(mapMountains.prefix(400))
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            mapLayer

            LinearGradient(
                colors: [.white.opacity(0.95), .white.opacity(0.6), .clear],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 180)
            .ignoresSafeArea()
            .allowsHitTesting(false)

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

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        FloatingMapButton(icon: "square.3.layers.3d") { showLayersSheet = true }
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
                } else if !isSearchActive {
                    discoverySheet
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isRouteCreationMode)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedMountain?.id)
        }
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
            .preferredColorScheme(.light)
        }
        .task {
            await mountainManager.fetchSavedRoutes()
            if let loc = locationManager.userLocation, !hasCenteredOnUser {
                flyToMyLocation()
                hasCenteredOnUser = true
            }
        }
        .onChange(of: locationManager.userLocation) { _, newLoc in
            if let loc = newLoc, !hasCenteredOnUser {
                flyToMyLocation()
                hasCenteredOnUser = true
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
        // 🟢 FIX: Wir nutzen 'item:', damit der Tracker erst öffnet, wenn der Berg zu 100% geladen ist!
        .fullScreenCover(item: $mountainToTrack) { mountain in
            LiveRecordView(targetMountain: mountain)
        }
        .sheet(isPresented: $showLayersSheet) {
            layersSheet.presentationDetents([.medium]).presentationDragIndicator(.visible)
        }
        .alert("Location Access Denied", isPresented: $showLocationDeniedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please enable location services for Ascend in your iPhone Settings to use this feature.")
        }
        .preferredColorScheme(.light)
    }

    @ViewBuilder
    var mapLayer: some View {
        Map(position: $cameraPosition, bounds: MapCameraBounds(maximumDistance: 6_000_000), selection: $selectedMarkerTag) {
            UserAnnotation()

            ForEach(visibleMountains, id: \.id) { mountain in
                // Safe coordinate — visibleMountains already filters nil, but guard defensively
                let coord = CLLocationCoordinate2D(latitude: mountain.latitude ?? 0, longitude: mountain.longitude ?? 0)
                
                if isRouteCreationMode {
                    if let idx = routeMountains.firstIndex(where: { $0.id == mountain.id }) {
                        Annotation("\(idx + 1)", coordinate: coord) {
                            ZStack {
                                Circle().fill(gold).frame(width: 32, height: 32)
                                Text("\(idx + 1)").font(.system(size: 14, weight: .black, design: .rounded)).foregroundColor(.black)
                            }
                            .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                        }
                        .tag(mountain.id)
                    } else {
                        Marker(mountain.name, systemImage: "plus.circle.fill", coordinate: coord)
                            .tint(.primary.opacity(0.7))
                            .tag(mountain.id)
                    }
                }
                // 🟢 NEU: Highlight-Annotation, wenn dieser Berg angeklickt wurde!
                else if selectedMountain?.id == mountain.id {
                    Annotation(mountain.name, coordinate: coord) {
                        VStack(spacing: 0) {
                            Text(mountain.name)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(gold)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                                .shadow(color: .black.opacity(0.4), radius: 5, y: 3)
                            
                            Image(systemName: "triangle.fill")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundColor(gold)
                                .rotationEffect(.degrees(180))
                                .offset(y: -2)
                        }
                    }
                    .tag(mountain.id)
                }
                else if mountain.isPrestigePeak {
                    Marker(mountain.name, systemImage: "crown.fill", coordinate: coord)
                        .tint(gold)
                        .tag(mountain.id)
                } else {
                    Marker(mountain.name, systemImage: "mountain.2.fill", coordinate: coord)
                        .tint(difficultyColor(mountain.difficulty))
                        .tag(mountain.id)
                }
            }

            // POI markers (parking, viewpoints, huts, etc.)
            if showNearby {
                ForEach(mountainManager.nearbyPOIs) { poi in
                    Annotation(poi.name, coordinate: CLLocationCoordinate2D(latitude: poi.latitude, longitude: poi.longitude)) {
                        Image(systemName: poiIcon(for: poi.type))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(width: 26, height: 26)
                            .background(poiColor(for: poi.type))
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
                    }
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
                let routeMountainsList = route.mountainIds.compactMap { id in mountainManager.mountains.first { $0.id == id } }
                let coords = routeMountainsList.compactMap { m -> CLLocationCoordinate2D? in
                    guard let lat = m.latitude, let lon = m.longitude else { return nil }
                    return CLLocationCoordinate2D(latitude: lat, longitude: lon)
                }
                MapPolyline(coordinates: coords).stroke(gold, lineWidth: 4)
            }
        }
        .mapStyle(mapStyleForCurrentLayer)
        .safeAreaPadding(.top, 160)
        .onMapCameraChange(frequency: .onEnd) { context in
            let region = context.region
            let spanKm = region.span.latitudeDelta * 111
            
            let newZoom: ZoomLevel
            if spanKm > 100 { newZoom = .far }
            else if spanKm > 20 { newZoom = .medium }
            else { newZoom = .close }
            
            withAnimation(.easeInOut(duration: 0.2)) { currentZoomLevel = newZoom }
            
            let latDelta = region.span.latitudeDelta * 2.0
            let lonDelta = region.span.longitudeDelta * 2.0
            let minLat = region.center.latitude - (latDelta / 2)
            let maxLat = region.center.latitude + (latDelta / 2)
            let minLon = region.center.longitude - (lonDelta / 2)
            let maxLon = region.center.longitude + (lonDelta / 2)

            // Debounce: cancel pending fetch, wait 300ms before firing
            mapFetchTask?.cancel()
            mapFetchTask = Task {
                try? await Task.sleep(nanoseconds: 300_000_000)
                guard !Task.isCancelled else { return }
                await mountainManager.fetchMountainsInBounds(minLat: minLat, maxLat: maxLat, minLon: minLon, maxLon: maxLon, zoomLevel: newZoom)
            }
        }
        .ignoresSafeArea()
    }

    var mapStyleForCurrentLayer: MapStyle {
        switch currentMapLayer {
        case .standard:  return .standard(elevation: .flat)
        case .satellite: return .hybrid(elevation: .flat)
        case .night:     return .standard(elevation: .flat)
        }
    }

    @ViewBuilder
    var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundColor(.gray).font(.system(size: 16, weight: .medium, design: .rounded))
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
                            Text("\(Int(radius))km").font(.system(size: 10, weight: .bold, design: .rounded))
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
                HStack { Text("\(visibleMountains.count) results").font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundColor(.gray); Spacer() }
                    .padding(.horizontal, 14).padding(.vertical, 8).background(Color.gray.opacity(0.05))
            }

            if suggestions.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "mountain.2").font(.system(.title2, design: .rounded)).foregroundColor(.gray.opacity(0.4))
                    Text("No peaks found").font(.system(.caption, design: .rounded)).foregroundColor(.gray)
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
                                        Text(mountain.name).font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundColor(.primary)
                                        Text("\(mountain.region) · \(mountain.elevation)m").font(.system(size: 11, design: .rounded)).foregroundColor(.gray)
                                    }
                                    Spacer()
                                    Text(mountain.difficulty.rawValue).font(.system(size: 10, weight: .bold, design: .rounded)).foregroundColor(difficultyColor(mountain.difficulty))
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
                                    Image(systemName: layer.icon).font(.system(size: 28, design: .rounded)).foregroundColor(.white)
                                }.overlay(RoundedRectangle(cornerRadius: 12).stroke(currentMapLayer == layer ? gold : Color.clear, lineWidth: 2))
                                Text(layer.rawValue).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundColor(currentMapLayer == layer ? gold : .primary)
                                Text(layer.subtitle).font(.system(size: 10, design: .rounded)).foregroundColor(.gray)
                            }
                        }
                    }
                }.padding(16)
            }
            .background(Color(white: 0.98)).navigationTitle("Map Layers").navigationBarTitleDisplayMode(.inline)
        }.preferredColorScheme(.light)
    }

    func layerPreviewColor(_ layer: MapLayerType) -> LinearGradient {
        switch layer {
        case .standard: return LinearGradient(colors: [.gray.opacity(0.3), .gray.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .satellite: return LinearGradient(colors: [.green.opacity(0.3), .blue.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .night: return LinearGradient(colors: [.indigo.opacity(0.4), .black.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
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
                Text("Route Creator").font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(.primary)
                Spacer()
                Text("\(routeMountains.count) peaks").font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundColor(gold)
            }

            TextField("Route name…", text: $routeName).textFieldStyle(.plain).padding(10)
                .background(Color.gray.opacity(0.1)).cornerRadius(10).foregroundColor(.primary)

            if !routeMountains.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(routeMountains.enumerated()), id: \.element.id) { index, mountain in
                            HStack(spacing: 4) {
                                Text("\(index + 1)").font(.system(size: 10, weight: .black, design: .rounded)).foregroundColor(.black).frame(width: 18, height: 18).background(gold).clipShape(Circle())
                                Text(mountain.name).font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundColor(.white).lineLimit(1)
                                Button { routeMountains.removeAll { $0.id == mountain.id } } label: { Image(systemName: "xmark.circle.fill").font(.system(size: 12, design: .rounded)).foregroundColor(.gray) }
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
                Button { withAnimation(.spring()) { isRouteCreationMode = false; routeMountains = []; routeName = "" } } label: {
                    Text("Cancel").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundColor(.primary).frame(maxWidth: .infinity).padding(.vertical, 12).background(Color.gray.opacity(0.1)).cornerRadius(12)
                }
                Button { saveCreatedRoute() } label: {
                    HStack(spacing: 4) { Image(systemName: "checkmark"); Text("Save Route") }.font(.system(size: 14, weight: .bold, design: .rounded)).foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 12).background(routeMountains.count >= 2 ? gold : gold.opacity(0.3)).cornerRadius(12)
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
            guard let loc = locationManager.userLocation else { return Array(visibleMountains.prefix(10)) }
            return visibleMountains.sorted { m1, m2 in
                let loc1 = CLLocation(latitude: m1.latitude ?? 0, longitude: m1.longitude ?? 0)
                let loc2 = CLLocation(latitude: m2.latitude ?? 0, longitude: m2.longitude ?? 0)
                return loc.distance(from: loc1) < loc.distance(from: loc2)
            }.prefix(10).map { $0 }
        }()

        let savedRoutes = mountainManager.savedRoutes

        VStack(alignment: .leading, spacing: 0) {
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

                    if (discoverySheetExpanded || showRoutesFilter || nearbyCards.isEmpty) {
                        discoverySectionHeader(title: "My Routes", icon: "bookmark.fill")
                        if savedRoutes.isEmpty {
                            HStack { Spacer(); VStack(spacing: 6) { Image(systemName: "map").font(.system(.title2, design: .rounded)).foregroundColor(.gray.opacity(0.3)); Text("No saved routes yet.").font(.system(.caption, design: .rounded)).foregroundColor(.gray) }; Spacer() }.padding(.vertical, 16)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    Spacer().frame(width: 4)
                                    ForEach(savedRoutes) { route in
                                        SavedRouteCard(route: route, onTap: {
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
            .frame(maxHeight: discoverySheetExpanded ? 350 : 130)
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
            Image(systemName: icon).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundColor(gold)
            Text(title).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundColor(.primary)
            Spacer()
            if !discoverySheetExpanded {
                Button { withAnimation(.spring()) { discoverySheetExpanded = true } } label: { Text("See All").font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundColor(gold) }
            }
        }.padding(.horizontal, 16)
    }

    // 🟢 NEU: Die Detail-Karte ist schlanker und hat keinen leeren Block mehr!


    func flyToMyLocation() {
        if let loc = locationManager.userLocation {
            withAnimation(.easeInOut(duration: 1.5)) {
                cameraPosition = .camera(MapCamera(centerCoordinate: loc.coordinate, distance: 5000, heading: 0, pitch: 0))
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
            selectedMountain = mountain; selectedMarkerTag = mountain.id; isSearchFocused = false; isSearchActive = false; searchText = ""; selectedRouteToShow = nil
        }
        if let lat = mountain.latitude, let lon = mountain.longitude { flyToMountain(lat: lat, lon: lon) }
    }

    func flyToMountain(lat: Double, lon: Double) {
        withAnimation(.easeInOut(duration: 1.5)) {
            cameraPosition = .camera(MapCamera(centerCoordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon), distance: 8000, heading: 0, pitch: 0))
        }
    }

    func flyTo(lat: Double, lon: Double, distance: Double) {
        withAnimation(.easeInOut(duration: 1.5)) {
            cameraPosition = .camera(MapCamera(centerCoordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon), distance: distance, heading: 0, pitch: 0))
        }
    }

    func refreshResults() async {
        await mountainManager.fetchTopMountains()
        performDebouncedSearch()
    }

    func performDebouncedSearch() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut) {
                Task {
                    await mountainManager.searchMountains(query: searchText, difficulty: selectedDifficulty)
                }
            }
        }
    }

    func saveCreatedRoute() {
        guard !routeMountains.isEmpty, !routeName.isEmpty else { return }
        let newRoute = SavedRoute(
            id: UUID(),
            name: routeName,
            mountainIds: routeMountains.map { $0.id },
            createdAt: Date(),
            totalDistanceKm: routeDistanceKm,
            totalElevationGain: routeElevationGain,
            estimatedDurationMinutes: Int(routeDistanceKm * 15 + Double(routeElevationGain) / 10),
            difficulty: "Medium"
        )
        Task {
            await mountainManager.saveRoute(newRoute)
            withAnimation(.spring()) {
                isRouteCreationMode = false
                routeMountains = []
                routeName = ""
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
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundColor(.black)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        }
    }
}

struct ToolbarButton: View {
    let icon: String
    let label: String
    let isActive: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(label)
                    .fontWeight(.semibold)
            }
            .font(.system(size: 13, design: .rounded))
            .foregroundColor(isActive ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isActive ? Color(red: 0.1, green: 0.5, blue: 0.95) : Color(.systemGray6))
            .clipShape(Capsule())
        }
    }
}

struct DifficultyChip: View {
    let label: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(isSelected ? .white : color)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? color : color.opacity(0.1))
                .clipShape(Capsule())
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
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
            Text(label)
                .font(.system(size: 10, design: .rounded))
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
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Text(mountain.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                Text("\(mountain.elevation)m • \(mountain.difficulty.rawValue)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(width: compact ? 160 : 200, alignment: .leading)
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
        }
        .buttonStyle(.plain)
    }
}

struct SavedRouteCard: View {
    let route: SavedRoute
    let onTap: () -> Void
    let onDelete: () -> Void
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                Text(route.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                Text("\(route.totalDistanceKm, specifier: "%.1f")km • \(route.totalElevationGain)m")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(width: 200, alignment: .leading)
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Delete", role: .destructive, action: onDelete)
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
    private let accent = Color(red: 0.1, green: 0.5, blue: 0.95)

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
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
                            Image(systemName: "mountain.2.fill").font(.system(size: 50)).foregroundColor(Color.black.opacity(0.1))
                        }
                        
                        LinearGradient(colors: [.clear, .white], startPoint: .center, endPoint: .bottom)
                            .frame(height: 250)
                            
                        if let credit = mountain.image_credit, !credit.isEmpty {
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    Text("Foto: \(credit)")
                                        .font(.system(size: 9, weight: .medium, design: .rounded))
                                        .foregroundColor(.white.opacity(0.8))
                                        .shadow(color: .black.opacity(0.8), radius: 3, x: 0, y: 1)
                                        .padding(.trailing, 16)
                                        .padding(.bottom, 16)
                                }
                            }
                        }
                        
                        Button { onDismiss() } label: {
                            Image(systemName: "xmark.circle.fill").font(.system(size: 28)).foregroundColor(.primary.opacity(0.6))
                                .background(Circle().fill(Color.white.opacity(0.8)))
                        }.padding(16)
                    }.frame(height: 250)

                    // Info Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(mountain.name).font(.system(size: 28, weight: .bold, design: .rounded)).foregroundColor(.primary)
                                Text("\(mountain.region), \(mountain.country)").font(.system(size: 15, design: .rounded)).foregroundColor(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(mountain.difficulty.rawValue.uppercased())
                                    .font(.system(size: 10, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10).padding(.vertical, 5)
                                    .background(mountain.difficulty.color)
                                    .clipShape(Capsule())
                                if isPrestigePeak {
                                    HStack(spacing: 3) {
                                        Image(systemName: "crown.fill").font(.system(size: 9, design: .rounded))
                                        Text("PRESTIGE").font(.system(size: 9, weight: .black, design: .rounded))
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
                        .background(Color(white: 0.95))
                        .cornerRadius(12)
                        
                        // Action buttons row
                        HStack(spacing: 12) {
                            OfflineDownloadButton(mountain: mountain, route: mountain.routes?.first)
                            Spacer()
                            Button(action: { showCollectionSheet = true }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "rectangle.stack.badge.plus")
                                    Text("Collection").font(.system(.subheadline, design: .rounded)).fontWeight(.semibold)
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
                                .font(.system(size: 14, design: .rounded))
                                .foregroundColor(.secondary)
                                .lineSpacing(4)
                        }
                        
                        // Detailed Elevation Profile
                        if let route = mountain.routes?.first, route.elevation_profile != nil {
                            Text("Elevation Profile").font(.headline).padding(.top, 10)
                            MountainElevationPreview(elevation: mountain.elevation, accentColor: gold, route: route)
                                .frame(height: 70)
                        }
                        
                        Spacer(minLength: 20)
                        
                        Button {
                            onStartTracking()
                        } label: {
                            HStack {
                                Image(systemName: "play.fill")
                                Text("Commence Mission")
                            }
                            .font(.system(size: 18, weight: .bold, design: .rounded))
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
            Image(systemName: icon).font(.system(size: 18)).foregroundColor(.secondary)
            Text(value).font(.system(size: 18, weight: .bold, design: .rounded)).foregroundColor(.primary)
            Text(label).font(.system(size: 12, design: .rounded)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
