import SwiftUI
import WebKit
import CoreLocation

// =========================================
// === DATEI: RouteReplayView.swift ===
// === 3D Route Replay — MapLibre GL JS ===
// === Strava-style cinematic flyover ===
// =========================================

// MARK: - Route Replay View

struct RouteReplayView: View {
    let routeCoordinates: [CLLocation]
    let tourName: String
    let totalElevation: Int
    let totalDistance: Double
    let difficulty: String
    var onClose: () -> Void

    @State private var isPlaying = false
    @State private var progress: Double = 0.0
    @State private var currentElevation: Double = 0
    @State private var currentDistance: Double = 0
    @State private var currentElevGain: Double = 0
    @State private var currentGrade: Double = 0
    @State private var elapsedSeconds: Int = 0
    @State private var mapReady = false
    @State private var showControls = true
    @State private var speedMultiplier: Int = 1
    @State private var isDraggingScrubber = false

    private let neonOrange = Color(red: 1.0, green: 0.35, blue: 0.0)

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            MapLibreWebView(
                routeCoordinates: routeCoordinates,
                isPlaying: $isPlaying,
                progress: $progress,
                currentElevation: $currentElevation,
                currentDistance: $currentDistance,
                currentElevGain: $currentElevGain,
                currentGrade: $currentGrade,
                elapsedSeconds: $elapsedSeconds,
                mapReady: $mapReady,
                speedMultiplier: $speedMultiplier,
                isDraggingScrubber: $isDraggingScrubber
            )
            .ignoresSafeArea()
            .opacity(mapReady ? 1 : 0)
            .animation(.easeIn(duration: 0.6), value: mapReady)

            // Loading state
            if !mapReady {
                loadingOverlay
            }

            // Tap zone to toggle controls
            if mapReady {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showControls.toggle()
                        }
                    }
                    .allowsHitTesting(!showControls)
            }

            // UI overlays
            if mapReady {
                VStack(spacing: 0) {
                    if showControls { topBar.transition(.move(edge: .top).combined(with: .opacity)) }
                    Spacer()
                    if showControls { bottomPanel.transition(.move(edge: .bottom).combined(with: .opacity)) }
                }
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
    }

    // MARK: - Loading

    private var loadingOverlay: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: neonOrange))
                .scaleEffect(1.3)
            Text("Preparing 3D Terrain...")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(alignment: .top) {
            // Close
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 34, height: 34)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Circle())
            }

            Spacer()

            // Title block
            VStack(spacing: 3) {
                Text(tourName)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
                HStack(spacing: 6) {
                    Image(systemName: "mountain.2.fill")
                        .font(.system(size: 9))
                    Text("3D FLYOVER")
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .tracking(2)
                }
                .foregroundColor(.white.opacity(0.5))
            }

            Spacer()

            // Speed toggle
            Button(action: cycleSpeed) {
                Text("\(speedMultiplier)x")
                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    .foregroundColor(speedMultiplier > 1 ? neonOrange : .white)
                    .frame(width: 34, height: 34)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 58)
        .padding(.bottom, 16)
        .background(
            LinearGradient(colors: [.black.opacity(0.7), .black.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
    }

    // MARK: - Bottom Panel

    private var bottomPanel: some View {
        VStack(spacing: 0) {
            // Scrubber
            scrubberBar
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

            // Stats row — Strava style: 4 columns
            HStack(spacing: 0) {
                statColumn(value: String(format: "%.2f", currentDistance), unit: "km", label: "Distance")
                statDivider
                statColumn(value: "\(Int(currentElevation))", unit: "m", label: "Elevation")
                statDivider
                statColumn(value: "\(Int(currentElevGain))", unit: "m", label: "Elev. Gain")
                statDivider
                statColumn(value: formatGrade(currentGrade), unit: "%", label: "Grade")
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 16)

            // Play controls
            HStack(spacing: 32) {
                Button(action: restart) {
                    Image(systemName: "backward.end.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 44, height: 44)
                }

                Button(action: togglePlay) {
                    ZStack {
                        Circle()
                            .fill(neonOrange)
                            .frame(width: 60, height: 60)
                            .shadow(color: neonOrange.opacity(0.6), radius: 16, y: 4)
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .offset(x: isPlaying ? 0 : 2)
                    }
                }

                Button(action: skipToEnd) {
                    Image(systemName: "forward.end.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 44, height: 44)
                }
            }
            .padding(.bottom, 40)
        }
        .background(
            LinearGradient(colors: [.clear, .black.opacity(0.5), .black.opacity(0.85)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
    }

    // MARK: - Scrubber

    private var scrubberBar: some View {
        GeometryReader { geo in
            let width = geo.size.width
            ZStack(alignment: .leading) {
                // Track
                Capsule()
                    .fill(.white.opacity(0.2))
                    .frame(height: 4)

                // Filled
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [neonOrange, neonOrange.opacity(0.8)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(width: max(4, width * progress), height: 4)

                // Thumb
                Circle()
                    .fill(.white)
                    .frame(width: isDraggingScrubber ? 18 : 12, height: isDraggingScrubber ? 18 : 12)
                    .shadow(color: neonOrange.opacity(0.5), radius: 6)
                    .offset(x: max(0, min(width - 12, width * progress - 6)))
                    .animation(.spring(response: 0.2), value: isDraggingScrubber)
            }
            .contentShape(Rectangle().inset(by: -20))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDraggingScrubber = true
                        let pct = max(0, min(1, value.location.x / width))
                        progress = pct
                    }
                    .onEnded { _ in
                        isDraggingScrubber = false
                    }
            )
        }
        .frame(height: 18)
    }

    // MARK: - Stat Helpers

    private func statColumn(value: String, unit: String, label: String) -> some View {
        VStack(spacing: 3) {
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(unit)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
            }
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.35))
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.1))
            .frame(width: 1, height: 36)
    }

    private func formatGrade(_ grade: Double) -> String {
        if grade > 0 { return "+\(Int(grade))" }
        return "\(Int(grade))"
    }

    private var difficultyColor: Color {
        DesignSystem.Colors.difficultyColor(difficulty)
    }

    // MARK: - Actions

    private func togglePlay() {
        isPlaying.toggle()
    }

    private func cycleSpeed() {
        switch speedMultiplier {
        case 1: speedMultiplier = 2
        case 2: speedMultiplier = 4
        case 4: speedMultiplier = 8
        default: speedMultiplier = 1
        }
    }

    private func restart() {
        isPlaying = false
        progress = 0
        currentElevation = routeCoordinates.first?.altitude ?? 0
        currentDistance = 0
        currentElevGain = 0
        currentGrade = 0
        elapsedSeconds = 0
    }

    private func skipToEnd() {
        isPlaying = false
        progress = 1.0
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - MapLibre WebView

struct MapLibreWebView: UIViewRepresentable {
    let routeCoordinates: [CLLocation]
    @Binding var isPlaying: Bool
    @Binding var progress: Double
    @Binding var currentElevation: Double
    @Binding var currentDistance: Double
    @Binding var currentElevGain: Double
    @Binding var currentGrade: Double
    @Binding var elapsedSeconds: Int
    @Binding var mapReady: Bool
    @Binding var speedMultiplier: Int
    @Binding var isDraggingScrubber: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.userContentController.add(context.coordinator, name: "replayBridge")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.navigationDelegate = context.coordinator

        let html = generateMapHTML()
        webView.loadHTMLString(html, baseURL: nil)
        context.coordinator.webView = webView
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let c = context.coordinator

        // Play / pause
        if isPlaying && !c.wasPlaying {
            webView.evaluateJavaScript("startReplay()", completionHandler: nil)
        } else if !isPlaying && c.wasPlaying {
            webView.evaluateJavaScript("pauseReplay()", completionHandler: nil)
        }
        c.wasPlaying = isPlaying

        // Speed change
        if speedMultiplier != c.lastSpeed {
            webView.evaluateJavaScript("setSpeed(\(speedMultiplier))", completionHandler: nil)
            c.lastSpeed = speedMultiplier
        }

        // Scrubber drag
        if isDraggingScrubber {
            if !c.wasDragging {
                webView.evaluateJavaScript("pauseReplay()", completionHandler: nil)
            }
            webView.evaluateJavaScript("seekTo(\(progress))", completionHandler: nil)
        } else if c.wasDragging && !isDraggingScrubber {
            // Released scrubber
            if isPlaying {
                webView.evaluateJavaScript("startReplay()", completionHandler: nil)
            }
        }
        c.wasDragging = isDraggingScrubber

        // Reset
        if progress == 0 && c.lastProgress > 0.01 && !isDraggingScrubber {
            webView.evaluateJavaScript("resetReplay()", completionHandler: nil)
        }
        // Skip to end
        if progress >= 0.99 && c.lastProgress < 0.99 && !isDraggingScrubber {
            webView.evaluateJavaScript("skipToEnd()", completionHandler: nil)
        }
        c.lastProgress = progress
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: MapLibreWebView
        var webView: WKWebView?
        var wasPlaying = false
        var wasDragging = false
        var lastProgress: Double = 0
        var lastSpeed: Int = 1

        init(_ parent: MapLibreWebView) {
            self.parent = parent
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let dict = message.body as? [String: Any] else { return }
            let type = dict["type"] as? String ?? ""

            DispatchQueue.main.async { [self] in
                switch type {
                case "mapReady":
                    parent.mapReady = true
                case "stats":
                    if !parent.isDraggingScrubber {
                        parent.progress = dict["progress"] as? Double ?? 0
                    }
                    parent.currentElevation = dict["elevation"] as? Double ?? 0
                    parent.currentDistance = dict["distance"] as? Double ?? 0
                    parent.currentElevGain = dict["elevGain"] as? Double ?? 0
                    parent.currentGrade = dict["grade"] as? Double ?? 0
                    parent.elapsedSeconds = dict["elapsed"] as? Int ?? 0
                case "finished":
                    parent.isPlaying = false
                    parent.progress = 1.0
                default:
                    break
                }
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let coords = parent.routeCoordinates.map { loc in
                [loc.coordinate.longitude, loc.coordinate.latitude, loc.altitude]
            }
            if let jsonData = try? JSONSerialization.data(withJSONObject: coords),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                webView.evaluateJavaScript("setRouteData(\(jsonString))", completionHandler: nil)
            }
        }
    }

    // MARK: - HTML Generation

    private func generateMapHTML() -> String {
        let lats = routeCoordinates.map(\.coordinate.latitude)
        let lngs = routeCoordinates.map(\.coordinate.longitude)
        let centerLat = ((lats.min() ?? 47.0) + (lats.max() ?? 47.0)) / 2
        let centerLng = ((lngs.min() ?? 11.0) + (lngs.max() ?? 11.0)) / 2

        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
        <link rel="stylesheet" href="https://unpkg.com/maplibre-gl@4.7.1/dist/maplibre-gl.css">
        <script src="https://unpkg.com/maplibre-gl@4.7.1/dist/maplibre-gl.js"></script>
        <style>
            * { margin: 0; padding: 0; box-sizing: border-box; }
            body { background: #0a0a0a; overflow: hidden; -webkit-user-select: none; }
            #map { width: 100vw; height: 100vh; }
            .maplibregl-ctrl-attrib,
            .maplibregl-ctrl-logo,
            .maplibregl-ctrl { display: none !important; }
        </style>
        </head>
        <body>
        <div id="map"></div>
        <script>
        // ============================
        // STATE
        // ============================
        let routeData = [];           // [[lng, lat, alt], ...]
        let cumulDist = [];           // precomputed cumulative distances in km
        let cumulGain = [];           // precomputed cumulative elevation gain in m
        let totalRouteDist = 0;
        let totalRouteGain = 0;

        let map = null;
        let animationId = null;
        let isAnimating = false;
        let fractionalIndex = 0;
        let lastFrameTime = 0;

        let speedMultiplier = 1;
        let startTime = 0;
        let pausedTime = 0;
        let totalPausedDuration = 0;

        // Target: traverse the full route in ~30 seconds at 1x (adjusted by point count)
        let basePointsPerSecond = 6;

        // Smoothed bearing for cinematic feel
        let smoothBearing = 0;

        // ============================
        // MAP INIT — Satellite + Terrain
        // ============================
        map = new maplibregl.Map({
            container: 'map',
            style: {
                version: 8,
                name: 'Ascent Satellite 3D',
                glyphs: 'https://demotiles.maplibre.org/font/{fontstack}/{range}.pbf',
                sources: {
                    'satellite': {
                        type: 'raster',
                        tiles: [
                            'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                        ],
                        tileSize: 256,
                        maxzoom: 19,
                        attribution: 'Esri, Maxar, Earthstar Geographics'
                    },
                    'terrain-dem': {
                        type: 'raster-dem',
                        tiles: [
                            'https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png'
                        ],
                        tileSize: 256,
                        encoding: 'terrarium',
                        maxzoom: 15
                    }
                },
                layers: [
                    {
                        id: 'satellite-layer',
                        type: 'raster',
                        source: 'satellite',
                        minzoom: 0,
                        maxzoom: 19,
                        paint: {
                            'raster-saturation': 0.1,
                            'raster-contrast': 0.05,
                            'raster-brightness-min': 0.08
                        }
                    }
                ],
                terrain: {
                    source: 'terrain-dem',
                    exaggeration: 1.5
                },
                sky: {
                    'sky-color': '#0b1026',
                    'horizon-color': '#1a2744',
                    'fog-color': '#0d1b2e',
                    'sky-horizon-blend': 0.4,
                    'horizon-fog-blend': 0.6,
                    'fog-ground-blend': 0.9
                }
            },
            center: [\(centerLng), \(centerLat)],
            zoom: 12,
            pitch: 0,
            bearing: 0,
            maxPitch: 85,
            antialias: true
        });

        // Disable map interaction during replay — Strava locks it too
        map.dragPan.disable();
        map.scrollZoom.disable();
        map.doubleClickZoom.disable();
        map.touchZoomRotate.disable();
        map.dragRotate.disable();
        map.keyboard.disable();
        map.touchPitch.disable();

        // ============================
        // ROUTE DATA + PRECOMPUTE
        // ============================
        function setRouteData(coords) {
            routeData = coords;
            if (routeData.length < 2) return;

            // Precompute cumulative distances and elevation gain
            cumulDist = [0];
            cumulGain = [0];
            for (let i = 1; i < routeData.length; i++) {
                const d = haversine(routeData[i-1][1], routeData[i-1][0], routeData[i][1], routeData[i][0]);
                cumulDist.push(cumulDist[i-1] + d);

                const dElev = routeData[i][2] - routeData[i-1][2];
                cumulGain.push(cumulGain[i-1] + (dElev > 0 ? dElev : 0));
            }
            totalRouteDist = cumulDist[cumulDist.length - 1];
            totalRouteGain = cumulGain[cumulGain.length - 1];

            // Auto-tune speed so full route takes ~35s at 1x
            basePointsPerSecond = Math.max(3, routeData.length / 35);

            if (map.loaded()) {
                setupRoute();
            } else {
                map.on('load', setupRoute);
            }
        }

        // ============================
        // ROUTE LAYERS
        // ============================
        function setupRoute() {
            const lineCoords = routeData.map(c => [c[0], c[1]]);

            // === Outer glow (wide, blurred) ===
            map.addSource('route-glow', {
                type: 'geojson',
                data: { type: 'Feature', geometry: { type: 'LineString', coordinates: lineCoords } }
            });
            map.addLayer({
                id: 'route-glow-outer',
                type: 'line',
                source: 'route-glow',
                layout: { 'line-join': 'round', 'line-cap': 'round' },
                paint: { 'line-color': '#FF5500', 'line-width': 16, 'line-opacity': 0.15, 'line-blur': 10 }
            });
            map.addLayer({
                id: 'route-glow-inner',
                type: 'line',
                source: 'route-glow',
                layout: { 'line-join': 'round', 'line-cap': 'round' },
                paint: { 'line-color': '#FF6600', 'line-width': 8, 'line-opacity': 0.3, 'line-blur': 4 }
            });

            // === Untraveled route (dimmed) ===
            map.addSource('route-base', {
                type: 'geojson',
                data: { type: 'Feature', geometry: { type: 'LineString', coordinates: lineCoords } }
            });
            map.addLayer({
                id: 'route-base-line',
                type: 'line',
                source: 'route-base',
                layout: { 'line-join': 'round', 'line-cap': 'round' },
                paint: { 'line-color': '#FF6600', 'line-width': 3.5, 'line-opacity': 0.4 }
            });

            // === Traveled portion (bright neon) ===
            map.addSource('route-traveled', {
                type: 'geojson',
                data: { type: 'Feature', geometry: { type: 'LineString', coordinates: [lineCoords[0], lineCoords[0]] } }
            });
            map.addLayer({
                id: 'route-traveled-glow',
                type: 'line',
                source: 'route-traveled',
                layout: { 'line-join': 'round', 'line-cap': 'round' },
                paint: { 'line-color': '#FF8800', 'line-width': 8, 'line-opacity': 0.4, 'line-blur': 4 }
            });
            map.addLayer({
                id: 'route-traveled-line',
                type: 'line',
                source: 'route-traveled',
                layout: { 'line-join': 'round', 'line-cap': 'round' },
                paint: { 'line-color': '#FF8C00', 'line-width': 4.5, 'line-opacity': 1 }
            });

            // === Start marker (green) ===
            map.addSource('start-pt', {
                type: 'geojson',
                data: { type: 'Feature', geometry: { type: 'Point', coordinates: lineCoords[0] } }
            });
            map.addLayer({
                id: 'start-ring',
                type: 'circle',
                source: 'start-pt',
                paint: { 'circle-radius': 8, 'circle-color': '#00E676', 'circle-opacity': 0.25 }
            });
            map.addLayer({
                id: 'start-dot',
                type: 'circle',
                source: 'start-pt',
                paint: { 'circle-radius': 5, 'circle-color': '#00E676', 'circle-stroke-width': 2, 'circle-stroke-color': '#fff' }
            });

            // === End marker (red) ===
            map.addSource('end-pt', {
                type: 'geojson',
                data: { type: 'Feature', geometry: { type: 'Point', coordinates: lineCoords[lineCoords.length - 1] } }
            });
            map.addLayer({
                id: 'end-ring',
                type: 'circle',
                source: 'end-pt',
                paint: { 'circle-radius': 8, 'circle-color': '#FF1744', 'circle-opacity': 0.25 }
            });
            map.addLayer({
                id: 'end-dot',
                type: 'circle',
                source: 'end-pt',
                paint: { 'circle-radius': 5, 'circle-color': '#FF1744', 'circle-stroke-width': 2, 'circle-stroke-color': '#fff' }
            });

            // === Moving marker ===
            map.addSource('marker', {
                type: 'geojson',
                data: { type: 'Feature', geometry: { type: 'Point', coordinates: lineCoords[0] } }
            });
            map.addLayer({
                id: 'marker-pulse',
                type: 'circle',
                source: 'marker',
                paint: { 'circle-radius': 18, 'circle-color': '#FF6600', 'circle-opacity': 0.15, 'circle-blur': 0.6 }
            });
            map.addLayer({
                id: 'marker-outer',
                type: 'circle',
                source: 'marker',
                paint: { 'circle-radius': 9, 'circle-color': '#FF8C00', 'circle-opacity': 0.5 }
            });
            map.addLayer({
                id: 'marker-core',
                type: 'circle',
                source: 'marker',
                paint: { 'circle-radius': 6, 'circle-color': '#FFFFFF', 'circle-stroke-width': 2.5, 'circle-stroke-color': '#FF6600' }
            });

            // === Cinematic intro: bird's eye -> tilted ===
            const startBearing = getBearing(lineCoords[0], lineCoords[Math.min(10, lineCoords.length - 1)]);
            smoothBearing = startBearing;

            // Step 1: overview
            map.jumpTo({ center: [\(centerLng), \(centerLat)], zoom: 12, pitch: 0, bearing: startBearing - 30 });

            // Step 2: fly to start with tilt
            setTimeout(() => {
                map.easeTo({
                    center: lineCoords[0],
                    zoom: 14.5,
                    pitch: 65,
                    bearing: startBearing,
                    duration: 3000,
                    easing: t => t < 0.5 ? 2*t*t : -1+(4-2*t)*t  // ease in-out quad
                });
            }, 800);

            // Signal ready after intro completes
            setTimeout(() => {
                window.webkit.messageHandlers.replayBridge.postMessage({ type: 'mapReady' });
            }, 1200);
        }

        // ============================
        // ANIMATION CONTROLS
        // ============================
        function setSpeed(s) {
            speedMultiplier = s;
        }

        function startReplay() {
            if (routeData.length < 2) return;
            isAnimating = true;

            if (fractionalIndex <= 0) {
                startTime = performance.now();
                totalPausedDuration = 0;
            } else {
                totalPausedDuration += performance.now() - pausedTime;
            }
            lastFrameTime = performance.now();
            animationId = requestAnimationFrame(animate);
        }

        function pauseReplay() {
            isAnimating = false;
            pausedTime = performance.now();
            if (animationId) { cancelAnimationFrame(animationId); animationId = null; }
        }

        function resetReplay() {
            pauseReplay();
            fractionalIndex = 0;
            startTime = 0;
            totalPausedDuration = 0;

            if (routeData.length > 0) {
                const start = [routeData[0][0], routeData[0][1]];
                updateMarker(start);
                updateTraveled(0);

                const bearing = getBearing(start, [routeData[Math.min(10, routeData.length-1)][0], routeData[Math.min(10, routeData.length-1)][1]]);
                smoothBearing = bearing;
                map.easeTo({ center: start, zoom: 14.5, pitch: 65, bearing: bearing, duration: 1200 });
                sendStats(0);
            }
        }

        function skipToEnd() {
            pauseReplay();
            if (routeData.length < 2) return;

            const lastIdx = routeData.length - 1;
            fractionalIndex = lastIdx;
            const coord = [routeData[lastIdx][0], routeData[lastIdx][1]];
            updateMarker(coord);
            updateTraveled(lastIdx);
            map.easeTo({ center: coord, zoom: 14.5, pitch: 65, duration: 1500 });
            sendStats(lastIdx);
        }

        function seekTo(pct) {
            if (routeData.length < 2) return;
            const targetIdx = pct * (routeData.length - 1);
            fractionalIndex = targetIdx;
            const idx = Math.floor(targetIdx);
            const frac = targetIdx - idx;
            const curr = routeData[idx];
            const next = routeData[Math.min(idx + 1, routeData.length - 1)];
            const lng = curr[0] + (next[0] - curr[0]) * frac;
            const lat = curr[1] + (next[1] - curr[1]) * frac;
            const coord = [lng, lat];

            updateMarker(coord);
            updateTraveled(idx);

            const lookIdx = Math.min(idx + 15, routeData.length - 1);
            const bearing = getBearing(coord, [routeData[lookIdx][0], routeData[lookIdx][1]]);
            smoothBearing = bearing;

            map.jumpTo({ center: coord, bearing: bearing, pitch: 65, zoom: 14.5 });
            sendStats(idx);
        }

        // ============================
        // ANIMATION LOOP
        // ============================
        function animate(timestamp) {
            if (!isAnimating || routeData.length < 2) return;

            const delta = (timestamp - lastFrameTime) / 1000;
            lastFrameTime = timestamp;

            fractionalIndex += basePointsPerSecond * speedMultiplier * delta;
            const idx = Math.floor(fractionalIndex);

            if (idx >= routeData.length - 1) {
                fractionalIndex = routeData.length - 1;
                const last = routeData[routeData.length - 1];
                updateMarker([last[0], last[1]]);
                updateTraveled(routeData.length - 1);
                sendStats(routeData.length - 1);
                window.webkit.messageHandlers.replayBridge.postMessage({ type: 'finished' });
                isAnimating = false;
                return;
            }

            // Interpolate position
            const frac = fractionalIndex - idx;
            const curr = routeData[idx];
            const next = routeData[Math.min(idx + 1, routeData.length - 1)];
            const lng = curr[0] + (next[0] - curr[0]) * frac;
            const lat = curr[1] + (next[1] - curr[1]) * frac;
            const coord = [lng, lat];

            updateMarker(coord);

            // Update traveled line every few frames for perf
            if (idx % 2 === 0) updateTraveled(idx);

            // Smooth bearing — cinematic interpolation
            const lookAheadIdx = Math.min(idx + Math.max(10, Math.floor(routeData.length * 0.03)), routeData.length - 1);
            const targetBearing = getBearing(coord, [routeData[lookAheadIdx][0], routeData[lookAheadIdx][1]]);

            // Shortest-angle lerp
            let diff = targetBearing - smoothBearing;
            if (diff > 180) diff -= 360;
            if (diff < -180) diff += 360;
            smoothBearing += diff * 0.06; // Slow lerp = cinematic
            smoothBearing = ((smoothBearing % 360) + 360) % 360;

            map.easeTo({
                center: coord,
                bearing: smoothBearing,
                pitch: 65,
                zoom: 14.5,
                duration: 60,
                easing: function(t) { return t; }
            });

            // Stats every few indices
            if (idx % 3 === 0) sendStats(idx);

            animationId = requestAnimationFrame(animate);
        }

        // ============================
        // STATS
        // ============================
        function sendStats(idx) {
            idx = Math.max(0, Math.min(idx, routeData.length - 1));
            const progress = routeData.length > 1 ? idx / (routeData.length - 1) : 0;
            const elevation = routeData[idx][2] || 0;
            const dist = cumulDist[idx] || 0;
            const gain = cumulGain[idx] || 0;

            // Grade: elevation change over last few points
            let grade = 0;
            if (idx > 3) {
                const elevDelta = routeData[idx][2] - routeData[idx - 4][2];
                const distDelta = (cumulDist[idx] - cumulDist[idx - 4]) * 1000; // m
                if (distDelta > 0) grade = (elevDelta / distDelta) * 100;
            }

            const elapsed = startTime > 0 ? Math.floor((performance.now() - startTime - totalPausedDuration) / 1000) : 0;

            window.webkit.messageHandlers.replayBridge.postMessage({
                type: 'stats',
                progress: progress,
                elevation: elevation,
                distance: dist,
                elevGain: gain,
                grade: grade,
                elapsed: Math.max(0, elapsed)
            });
        }

        // ============================
        // SOURCE UPDATES
        // ============================
        function updateMarker(coord) {
            const src = map.getSource('marker');
            if (src) src.setData({ type: 'Feature', geometry: { type: 'Point', coordinates: coord } });
        }

        function updateTraveled(idx) {
            const src = map.getSource('route-traveled');
            if (!src || routeData.length === 0) return;
            const coords = routeData.slice(0, idx + 1).map(c => [c[0], c[1]]);
            if (coords.length < 2) coords.push(coords[0]);
            src.setData({ type: 'Feature', geometry: { type: 'LineString', coordinates: coords } });
        }

        // ============================
        // MATH
        // ============================
        function getBearing(start, end) {
            const toRad = Math.PI / 180;
            const sLat = start[1] * toRad, sLng = start[0] * toRad;
            const eLat = end[1] * toRad, eLng = end[0] * toRad;
            const dLng = eLng - sLng;
            const x = Math.sin(dLng) * Math.cos(eLat);
            const y = Math.cos(sLat) * Math.sin(eLat) - Math.sin(sLat) * Math.cos(eLat) * Math.cos(dLng);
            return ((Math.atan2(x, y) * 180 / Math.PI) + 360) % 360;
        }

        function haversine(lat1, lon1, lat2, lon2) {
            const R = 6371;
            const toRad = Math.PI / 180;
            const dLat = (lat2 - lat1) * toRad;
            const dLon = (lon2 - lon1) * toRad;
            const a = Math.sin(dLat/2)**2 + Math.cos(lat1*toRad) * Math.cos(lat2*toRad) * Math.sin(dLon/2)**2;
            return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
        }
        </script>
        </body>
        </html>
        """
    }
}

// MARK: - Route Replay Launcher (for Tour feed cards)

struct RouteReplayLauncher: View {
    let tour: Tour
    let polylineString: String?
    @State private var showReplay = false

    private var routeLocations: [CLLocation] {
        if let poly = polylineString, !poly.isEmpty {
            let decoded = RouteEncoder.decodeWithAltitude(poly)
            if !decoded.isEmpty { return decoded }
        }
        return tour.routeCoordinates.map { coord in
            CLLocation(
                coordinate: coord,
                altitude: 0,
                horizontalAccuracy: 10,
                verticalAccuracy: 10,
                timestamp: Date()
            )
        }
    }

    var body: some View {
        if !tour.routeCoordinates.isEmpty {
            Button(action: {
                HapticManager.shared.heavy()
                showReplay = true
            }) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 1.0, green: 0.4, blue: 0.0), Color(red: 1.0, green: 0.6, blue: 0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 40, height: 40)
                        Image(systemName: "play.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .offset(x: 1)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("3D Route Replay")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(DesignSystem.Colors.primaryText)
                        Text("Fly through your hike in 3D terrain")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }

                    Spacer()

                    Image(systemName: "mountain.2.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Color(red: 1.0, green: 0.4, blue: 0.0).opacity(0.6))
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                        .fill(DesignSystem.Colors.cardBackground)
                        .shadow(color: Color(red: 1.0, green: 0.4, blue: 0.0).opacity(0.08), radius: 8, y: 4)
                )
            }
            .buttonStyle(AscentButtonStyle())
            .fullScreenCover(isPresented: $showReplay) {
                RouteReplayView(
                    routeCoordinates: routeLocations,
                    tourName: tour.summitName,
                    totalElevation: tour.elevationGainMeters,
                    totalDistance: tour.distanceKilometers,
                    difficulty: "Mittel",
                    onClose: { showReplay = false }
                )
            }
        }
    }
}

// MARK: - CloudTour Replay Launcher

struct CloudTourReplayLauncher: View {
    let tour: CloudTour
    @State private var showReplay = false

    private var routeLocations: [CLLocation] {
        guard let poly = tour.route_polyline, !poly.isEmpty else { return [] }
        return RouteEncoder.decodeWithAltitude(poly)
    }

    var body: some View {
        if !routeLocations.isEmpty {
            Button(action: {
                HapticManager.shared.heavy()
                showReplay = true
            }) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 1.0, green: 0.4, blue: 0.0), Color(red: 1.0, green: 0.6, blue: 0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 40, height: 40)
                        Image(systemName: "play.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .offset(x: 1)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("3D Route Replay")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(DesignSystem.Colors.primaryText)
                        Text("Fly through your hike in 3D terrain")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }

                    Spacer()

                    Image(systemName: "mountain.2.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Color(red: 1.0, green: 0.4, blue: 0.0).opacity(0.6))
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                        .fill(DesignSystem.Colors.cardBackground)
                        .shadow(color: Color(red: 1.0, green: 0.4, blue: 0.0).opacity(0.08), radius: 8, y: 4)
                )
            }
            .buttonStyle(AscentButtonStyle())
            .fullScreenCover(isPresented: $showReplay) {
                RouteReplayView(
                    routeCoordinates: routeLocations,
                    tourName: tour.name,
                    totalElevation: tour.elevation,
                    totalDistance: tour.distance_km ?? 0,
                    difficulty: tour.difficulty,
                    onClose: { showReplay = false }
                )
            }
        }
    }
}
