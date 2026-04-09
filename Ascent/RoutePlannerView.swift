import SwiftUI
import MapKit
import CoreLocation

// =========================================
// === OFFLINE ROUTE PLANNER (BRouter) ===
// =========================================

struct RoutePlannerView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    
    var onSave: ((Mountain) -> Void)?
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 47.4582, longitude: 10.9852), // Default
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    
    @State private var startCoordinate: CLLocationCoordinate2D?
    @State private var endCoordinate: CLLocationCoordinate2D?
    
    @State private var plannedRoute: [CLLocationCoordinate2D] = []
    @State private var isCalculating = false
    @State private var showSaveDialog = false
    
    @State private var routeName: String = "My Custom Route"
    @State private var routeDistance: Double = 0
    @State private var routeElevation: Double = 0
    
    var body: some View {
        ZStack {
            // Map directly handling taps
            MapReader { mapProxy in
                Map(coordinateRegion: $region, showsUserLocation: true, annotationItems: dropPins()) { pin in
                    MapAnnotation(coordinate: pin.coordinate) {
                        VStack {
                            Image(systemName: pin.isStart ? "mappin.and.ellipse" : "flag.fill")
                                .font(.title)
                                .foregroundColor(pin.isStart ? .orange : .cyan)
                            Text(pin.isStart ? "START" : "GOAL")
                                .font(.caption2).bold()
                                .foregroundColor(.white)
                                .padding(4)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(4)
                        }
                        .offset(y: -15)
                    }
                }
                .onTapGesture { location in
                    if let coord = mapProxy.convert(location, from: .local) {
                        handleMapTap(coord)
                    }
                }
            }
            .ignoresSafeArea()
            
            // Route lines overlay natively rendered
            RouteOverlayView(coordinates: plannedRoute)
                .allowsHitTesting(false)
            
            // Upper HUD
            VStack {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(.title3, design: .rounded))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    Spacer()
                    Text("Plan Route (BRouter)")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Capsule())
                    Spacer()
                    Button(action: { reset() }) {
                        Image(systemName: "trash")
                            .font(.system(.title3, design: .rounded))
                            .foregroundColor(.red)
                            .padding(12)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal)
                .padding(.top, 50)
                
                Spacer()
                
                // Bottom HUD panel
                VStack(spacing: 15) {
                    HStack {
                        if startCoordinate == nil {
                            Text("👉 Tap the map to set a START point.")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        } else if endCoordinate == nil {
                            Text("👉 Tap again to set your GOAL.")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        } else {
                            if !plannedRoute.isEmpty {
                                VStack(alignment: .leading) {
                                    Text("Trail found!")
                                        .font(.headline)
                                    Text("\(String(format: "%.1f", routeDistance / 1000)) km • \((Int(routeElevation)))m Elevation")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                            } else {
                                Text("Ready to calculate.")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                Spacer()
                            }
                        }
                    }
                    
                    if startCoordinate != nil && endCoordinate != nil && plannedRoute.isEmpty {
                        Button(action: {
                            Task {
                                await calculateRoute()
                            }
                        }) {
                            HStack {
                                if isCalculating {
                                    ProgressView().tint(.white)
                                } else {
                                    Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                                    Text("FIND TRAIL")
                                }
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.cyan)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .disabled(isCalculating)
                    }
                    
                    if !plannedRoute.isEmpty {
                        Button(action: {
                            showSaveDialog = true
                        }) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("SAVE & READY")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.green)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    }
                }
                .padding(20)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .padding(.horizontal)
                .padding(.bottom, 20)
                .shadow(color: .black.opacity(0.1), radius: 10, y: -5)
            }
        }
        .onAppear {
            let manager = CLLocationManager()
            if let userLoc = manager.location?.coordinate {
                region = MKCoordinateRegion(center: userLoc, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
            }
        }
        .sheet(isPresented: $showSaveDialog) {
            SaveCustomRouteView(
                routeName: $routeName,
                distance: routeDistance,
                routeCoords: plannedRoute,
                routeElevation: routeElevation,
                onSave: { customMtn in
                    dismiss()
                    onSave?(customMtn)
                }
            )
        }
    }
    
    private func handleMapTap(_ coord: CLLocationCoordinate2D) {
        if startCoordinate == nil {
            startCoordinate = coord
        } else if endCoordinate == nil {
            endCoordinate = coord
        }
    }
    
    private func reset() {
        startCoordinate = nil
        endCoordinate = nil
        plannedRoute = []
        routeDistance = 0
        routeElevation = 0
    }
    
    private func dropPins() -> [RoutePin] {
        var pins = [RoutePin]()
        if let s = startCoordinate { pins.append(RoutePin(coordinate: s, isStart: true)) }
        if let e = endCoordinate { pins.append(RoutePin(coordinate: e, isStart: false)) }
        return pins
    }
    
    private func calculateRoute() async {
        guard let start = startCoordinate, let end = endCoordinate else { return }
        isCalculating = true
        
        let urlStr = "https://brouter.de/brouter?lonlats=\(start.longitude),\(start.latitude)|\(end.longitude),\(end.latitude)&profile=trekking&alternativeidx=0&format=geojson"
        
        guard let url = URL(string: urlStr) else {
            isCalculating = false
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoder = JSONDecoder()
            let geo = try decoder.decode(BRouterGeoJSON.self, from: data)
            
            if let feature = geo.features?.first, let coords = feature.geometry?.coordinates {
                var routeCoords = [CLLocationCoordinate2D]()
                for c in coords {
                    if c.count >= 2 {
                        routeCoords.append(CLLocationCoordinate2D(latitude: c[1], longitude: c[0]))
                    }
                }
                
                DispatchQueue.main.async {
                    self.plannedRoute = routeCoords
                    
                    if let props = feature.properties {
                        if let distStr = props["track-length"], let d = Double(distStr) {
                            self.routeDistance = d
                        }
                        if let ascStr = props["filtered ascend"], let a = Double(ascStr) {
                            self.routeElevation = a
                        }
                    }
                    self.isCalculating = false
                    adjustMapToRoute()
                }
            } else {
                isCalculating = false
            }
        } catch {
            print("BRouter API Error: \(error)")
            isCalculating = false
        }
    }
    
    private func adjustMapToRoute() {
        guard !plannedRoute.isEmpty else { return }
        let lats = plannedRoute.map { $0.latitude }
        let lons = plannedRoute.map { $0.longitude }
        let center = CLLocationCoordinate2D(latitude: (lats.min()! + lats.max()!)/2, longitude: (lons.min()! + lons.max()!)/2)
        let span = MKCoordinateSpan(latitudeDelta: (lats.max()! - lats.min()!) * 1.5, longitudeDelta: (lons.max()! - lons.min()!) * 1.5)
        
        withAnimation {
            region = MKCoordinateRegion(center: center, span: span)
        }
    }
}

struct RoutePin: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let isStart: Bool
}

struct BRouterGeoJSON: Codable {
    let features: [BRouterFeature]?
}

struct BRouterFeature: Codable {
    let geometry: BRouterGeometry?
    let properties: [String: String]?
}

struct BRouterGeometry: Codable {
    let type: String?
    let coordinates: [[Double]]?
}

struct RouteOverlayView: UIViewRepresentable {
    var coordinates: [CLLocationCoordinate2D]
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.backgroundColor = .clear
        mapView.isOpaque = false
        mapView.showsUserLocation = false
        mapView.isUserInteractionEnabled = false
        return mapView
    }
    
    func updateUIView(_ uiView: MKMapView, context: Context) {
        uiView.removeOverlays(uiView.overlays)
        
        if !coordinates.isEmpty {
            let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            uiView.addOverlay(polyline)
            
            let rect = polyline.boundingMapRect
            uiView.setVisibleMapRect(rect, edgePadding: UIEdgeInsets(top: 50, left: 50, bottom: 50, right: 50), animated: false)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: RouteOverlayView
        init(_ parent: RouteOverlayView) { self.parent = parent }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor.cyan
                renderer.lineWidth = 5
                return renderer
            }
            return MKOverlayRenderer()
        }
    }
}

struct SaveCustomRouteView: View {
    @EnvironmentObject var appState: AppState
    @Binding var routeName: String
    var distance: Double
    var routeCoords: [CLLocationCoordinate2D]
    var routeElevation: Double
    var onSave: (Mountain) -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Route Details")) {
                    TextField("Route Name", text: $routeName)
                    HStack {
                        Text("Distance")
                        Spacer()
                        Text(String(format: "%.2f km", distance/1000)).foregroundColor(.gray)
                    }
                }
                
                Button(action: saveRoute) {
                    Text("Save & Start Mission")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(12)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            .navigationTitle("Save Route")
            .navigationBarItems(trailing: Button("Cancel") { dismiss() })
        }
    }
    
    private func saveRoute() {
        let customMountain = Mountain(
            id: UUID(),
            name: routeName,
            elevation: Int(routeElevation),
            difficulty: .medium,
            country: "Local",
            region: "Custom Route",
            description: "A custom route planned via BRouter.",
            isPrestigePeak: false,
            imageUrl: "https://images.unsplash.com/photo-1464822759023-fed622ff2c3b",
            image_url: nil,
            image_credit: nil,
            photographer_name: nil,
            photographer_link: nil,
            latitude: routeCoords.first?.latitude ?? 0,
            longitude: routeCoords.first?.longitude ?? 0
        )
        
        // Feed into tracker
        appState.activeCustomRoute = routeCoords
        
        onSave(customMountain)
    }
}
