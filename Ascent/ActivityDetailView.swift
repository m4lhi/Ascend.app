import SwiftUI
import MapKit

struct ActivityDetailView: View {
    @Environment(\.dismiss) var dismiss
    let tour: Tour
    
    @State private var selectedTab = 0
    @State private var showPhotoPopover = false
    @State private var scrubDistance: Double? = nil
    
    private let accent = DesignSystem.Colors.accent
    
    // We mock the photo location to be halfway through the route
    private var photoCoordinate: CLLocationCoordinate2D? {
        guard tour.photoURL != nil, !tour.routeCoordinates.isEmpty else { return nil }
        return tour.routeCoordinates[tour.routeCoordinates.count / 2] // Roughly halfway
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            TabView(selection: $selectedTab) {
                // TAB 1: Map & Stats
                mapAndStatsPage
                    .tag(0)
                
                // TAB 2: Photo Full Screen
                if let photoURL = tour.photoURL, let url = URL(string: photoURL) {
                    photoPage(url: url)
                        .tag(1)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .ignoresSafeArea()
            
            // Close Button
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.app(size: 30))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.trailing, 20)
                    .padding(.top, 50)
            }
            .shadow(radius: 4)
        }
        .preferredColorScheme(.dark) // Make the detail view dark mode for that premium feel
    }
    
    // MARK: - Map & Stats Page
    private var mapAndStatsPage: some View {
        ZStack(alignment: .bottom) {
            // Full screen map
            Map {
                MapPolyline(coordinates: tour.routeCoordinates)
                    .stroke(accent, lineWidth: 4)

                if let dist = scrubDistance, tour.routeLocations.count > 1 {
                    let totalDist = tour.distanceKilometers
                    let fraction = max(0, min(1, dist / totalDist))
                    let index = Int(fraction * Double(tour.routeLocations.count - 1))
                    let safeIndex = max(0, min(tour.routeLocations.count - 1, index))
                    let point = tour.routeLocations[safeIndex]
                    
                    Annotation("", coordinate: point.coordinate) {
                        Circle()
                            .fill(accent)
                            .frame(width: 16, height: 16)
                            .overlay(Circle().stroke(Color.white, lineWidth: 3))
                            .shadow(radius: 4)
                            .animation(.none, value: dist)
                    }
                }
                
                if let first = tour.routeCoordinates.first {
                    Annotation("Start", coordinate: first) {
                        Circle().fill(.green).frame(width: 12, height: 12)
                            .overlay(Circle().stroke(.white, lineWidth: 2))
                    }
                }
                
                if let last = tour.routeCoordinates.last, tour.routeCoordinates.count > 1 {
                    Annotation("Summit", coordinate: last) {
                        Image(systemName: "flag.fill")
                            .font(.app(size: 16))
                            .foregroundColor(.red)
                    }
                }
                
                if let photoCoord = photoCoordinate, let urlText = tour.photoURL, let url = URL(string: urlText) {
                    Annotation("Photo", coordinate: photoCoord) {
                        Button(action: {
                            showPhotoPopover = true
                        }) {
                            ZStack {
                                Circle().fill(Color.white).frame(width: 44, height: 44)
                                    .shadow(radius: 4)
                                CachedAsyncImage(url: url) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    Color.gray
                                }
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                            }
                        }
                        .popover(isPresented: $showPhotoPopover) {
                            VStack(spacing: 8) {
                                Text("\(tour.playerName) took a photo here.")
                                    .font(.app(size: 14, weight: .semibold))
                                    .padding()
                                Button("View Full Photo") {
                                    showPhotoPopover = false
                                    selectedTab = 1
                                }
                                .font(.app(size: 14, weight: .bold))
                                .foregroundColor(accent)
                                .padding(.bottom, 10)
                            }
                            .presentationCompactAdaptation(.popover)
                        }
                    }
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .ignoresSafeArea()
            
            // Bottom Stats Overlay
            VStack(spacing: 12) {
                if !tour.routeLocations.isEmpty {
                    ElevationProfileView(routePoints: tour.routeLocations, compact: true, scrubDistanceOut: $scrubDistance)
                        .padding(.top, 10)
                } else {
                    // Simulated Elevation Profile Fallback
                    HStack(alignment: .bottom, spacing: 2) {
                        ForEach(0..<40, id: \.self) { i in
                            let height = abs(sin(Double(i) * 0.2)) * 40 + Double.random(in: 10...20)
                            Rectangle()
                                .fill(accent.opacity(0.8))
                                .frame(width: 6, height: CGFloat(height))
                                .cornerRadius(3)
                        }
                    }
                    .frame(height: 60)
                    .padding(.top, 10)
                }
                
                HStack {
                    Spacer()
                    statItem(icon: "figure.walk", label: "Distance", value: String(format: "%.1f km", tour.distanceKilometers))
                    Spacer()
                    statItem(icon: "arrow.up.forward", label: "Elevation", value: "+\(tour.elevationGainMeters) m")
                    Spacer()
                    let formatter = DateComponentsFormatter()
                    let _ = { formatter.allowedUnits = [.hour, .minute] }()
                    let _ = { formatter.unitsStyle = .abbreviated }()
                    let durStr = formatter.string(from: tour.durationSeconds) ?? "0m"
                    statItem(icon: "clock", label: "Duration", value: durStr)
                    Spacer()
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
            .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
        }
    }
    
    // MARK: - Photo Full Screen Page
    private func photoPage(url: URL) -> some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            CachedAsyncImage(url: url) { image in
                image.resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } placeholder: {
                ProgressView().tint(.white)
            }
            
            // Attribution
            VStack {
                Spacer()
                HStack(spacing: 12) {
                    if let avatar = tour.playerAvatarURL, let avatarURL = URL(string: avatar) {
                        CachedAsyncImage(url: avatarURL) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Circle().fill(Color.gray)
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                    } else {
                        Circle().fill(Color.gray)
                            .frame(width: 40, height: 40)
                    }
                    
                    VStack(alignment: .leading) {
                        Text(tour.playerName)
                            .font(.app(.subheadline).bold())
                            .foregroundColor(.white)
                        Text("Captured along the route")
                            .font(.app(.caption))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    Spacer()
                }
                .padding()
                .background(Color.black.opacity(0.6))
                .cornerRadius(16)
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
    }
    
    private func statItem(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.app(size: 16))
                .foregroundColor(.white.opacity(0.7))
            Text(value)
                .font(.app(size: 18, weight: .bold))
                .foregroundColor(.white)
            Text(label)
                .font(.app(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
    }
}
