import Foundation
import Combine
import MapKit
import SwiftUI

// =========================================
// === DATEI: OfflineManager.swift ===
// === Offline Maps & Route Downloads ===
// =========================================

struct OfflineRegion: Identifiable, Codable {
    let id: UUID
    let name: String
    let centerLatitude: Double
    let centerLongitude: Double
    let spanLatitude: Double
    let spanLongitude: Double
    let downloadDate: Date
    let sizeBytes: Int64

    var sizeFormatted: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: sizeBytes)
    }
}

struct OfflineRoute: Identifiable, Codable {
    let id: UUID
    let mountainId: UUID
    let mountainName: String
    let routeName: String
    let polyline: String
    let downloadDate: Date
    let elevation: Int
    let difficulty: String
}

@MainActor
class OfflineManager: ObservableObject {
    static let shared = OfflineManager()

    @Published var downloadedRegions: [OfflineRegion] = []
    @Published var downloadedRoutes: [OfflineRoute] = []
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0
    @Published var totalStorageUsed: Int64 = 0

    private let regionsKey = "offline_regions"
    private let routesKey = "offline_routes"
    private let maxStorageMB: Int64 = 500

    init() {
        loadFromDisk()
    }

    var storageUsedFormatted: String {
        ByteCountFormatter.string(fromByteCount: totalStorageUsed, countStyle: .file)
    }

    var storagePercentage: Double {
        Double(totalStorageUsed) / Double(maxStorageMB * 1024 * 1024)
    }

    // MARK: - Download Route for Offline

    func downloadRoute(mountain: Mountain, route: MountainRoute?) async {
        let routeId = route?.id ?? mountain.id
        guard !downloadedRoutes.contains(where: { $0.id == routeId }) else { return }

        let offlineRoute = OfflineRoute(
            id: routeId,
            mountainId: mountain.id,
            mountainName: mountain.name,
            routeName: route?.route_name ?? "Standard Access",
            polyline: route?.route_polyline ?? "",
            downloadDate: Date(),
            elevation: mountain.elevation,
            difficulty: mountain.difficulty.rawValue
        )

        downloadedRoutes.append(offlineRoute)
        saveToDisk()
    }

    func downloadRegion(name: String, center: CLLocationCoordinate2D, span: MKCoordinateSpan) async {
        isDownloading = true
        downloadProgress = 0

        // Simulate tile download progress
        for i in 1...10 {
            try? await Task.sleep(nanoseconds: 200_000_000)
            downloadProgress = Double(i) / 10.0
        }

        let estimatedSize: Int64 = Int64(span.latitudeDelta * span.longitudeDelta * 50_000_000) // rough estimate

        let region = OfflineRegion(
            id: UUID(),
            name: name,
            centerLatitude: center.latitude,
            centerLongitude: center.longitude,
            spanLatitude: span.latitudeDelta,
            spanLongitude: span.longitudeDelta,
            downloadDate: Date(),
            sizeBytes: estimatedSize
        )

        downloadedRegions.append(region)
        totalStorageUsed += estimatedSize
        saveToDisk()

        isDownloading = false
        downloadProgress = 0
    }

    func deleteRegion(id: UUID) {
        if let region = downloadedRegions.first(where: { $0.id == id }) {
            totalStorageUsed = max(0, totalStorageUsed - region.sizeBytes)
        }
        downloadedRegions.removeAll { $0.id == id }
        saveToDisk()
    }

    func deleteRoute(id: UUID) {
        downloadedRoutes.removeAll { $0.id == id }
        saveToDisk()
    }

    func isRouteDownloaded(_ routeId: UUID) -> Bool {
        downloadedRoutes.contains { $0.id == routeId }
    }

    func getOfflineRoute(_ mountainId: UUID) -> OfflineRoute? {
        downloadedRoutes.first { $0.mountainId == mountainId }
    }

    // MARK: - Persistence

    private func saveToDisk() {
        if let data = try? JSONEncoder().encode(downloadedRegions) {
            UserDefaults.standard.set(data, forKey: regionsKey)
        }
        if let data = try? JSONEncoder().encode(downloadedRoutes) {
            UserDefaults.standard.set(data, forKey: routesKey)
        }
        UserDefaults.standard.set(totalStorageUsed, forKey: "offline_storage_used")
    }

    private func loadFromDisk() {
        if let data = UserDefaults.standard.data(forKey: regionsKey),
           let regions = try? JSONDecoder().decode([OfflineRegion].self, from: data) {
            downloadedRegions = regions
        }
        if let data = UserDefaults.standard.data(forKey: routesKey),
           let routes = try? JSONDecoder().decode([OfflineRoute].self, from: data) {
            downloadedRoutes = routes
        }
        totalStorageUsed = Int64(UserDefaults.standard.integer(forKey: "offline_storage_used"))
    }
}

// MARK: - Offline Downloads View (for Settings)
struct OfflineDownloadsView: View {
    @ObservedObject var offlineManager = OfflineManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Storage usage
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Storage Used")
                        .font(DesignSystem.Typography.appFont(style: .subheadline))
                        .fontWeight(.semibold)
                    Spacer()
                    Text(offlineManager.storageUsedFormatted)
                        .font(DesignSystem.Typography.appFont(style: .caption))
                        .foregroundColor(.secondary)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(offlineManager.storagePercentage > 0.8 ? Color.orange : DesignSystem.Colors.accent)
                            .frame(width: geo.size.width * min(offlineManager.storagePercentage, 1.0))
                    }
                }
                .frame(height: 8)
            }

            // Downloaded regions
            if !offlineManager.downloadedRegions.isEmpty {
                Text("OFFLINE MAPS")
                    .font(DesignSystem.Typography.appFont(size: 11, weight: .black))
                    .foregroundColor(.gray)
                    .tracking(2)

                ForEach(offlineManager.downloadedRegions) { region in
                    HStack(spacing: 12) {
                        Image(systemName: "map.fill")
                            .foregroundColor(DesignSystem.Colors.accent)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(region.name)
                                .font(DesignSystem.Typography.appFont(style: .subheadline))
                                .fontWeight(.semibold)
                            Text("\(region.sizeFormatted) · Downloaded \(region.downloadDate.formatted(.relative(presentation: .named)))")
                                .font(DesignSystem.Typography.appFont(style: .caption))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button(action: { offlineManager.deleteRegion(id: region.id) }) {
                            Image(systemName: "trash")
                                .font(DesignSystem.Typography.appFont(size: 14))
                                .foregroundColor(.red)
                        }
                    }
                }
            }

            // Downloaded routes
            if !offlineManager.downloadedRoutes.isEmpty {
                Text("OFFLINE ROUTES")
                    .font(DesignSystem.Typography.appFont(size: 11, weight: .black))
                    .foregroundColor(.gray)
                    .tracking(2)

                ForEach(offlineManager.downloadedRoutes) { route in
                    HStack(spacing: 12) {
                        Image(systemName: "point.topright.arrow.triangle.backward.to.point.bottomleft.scurvepath.fill")
                            .foregroundColor(.orange)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(route.mountainName)
                                .font(DesignSystem.Typography.appFont(style: .subheadline))
                                .fontWeight(.semibold)
                            Text(route.routeName)
                                .font(DesignSystem.Typography.appFont(style: .caption))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button(action: { offlineManager.deleteRoute(id: route.id) }) {
                            Image(systemName: "trash")
                                .font(DesignSystem.Typography.appFont(size: 14))
                                .foregroundColor(.red)
                        }
                    }
                }
            }

            // Empty state
            if offlineManager.downloadedRegions.isEmpty && offlineManager.downloadedRoutes.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "icloud.and.arrow.down")
                        .font(DesignSystem.Typography.appFont(size: 24))
                        .foregroundColor(.gray.opacity(0.4))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("No Offline Content")
                            .font(DesignSystem.Typography.appFont(style: .subheadline))
                            .fontWeight(.semibold)
                        Text("Download maps and routes from the Explore tab to use them without internet.")
                            .font(DesignSystem.Typography.appFont(style: .caption))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(14)
            }
        }
    }
}

// MARK: - Download Button (for Mountain Detail Sheet)
struct OfflineDownloadButton: View {
    let mountain: Mountain
    let route: MountainRoute?
    @ObservedObject var offlineManager = OfflineManager.shared
    @State private var isDownloaded = false

    var body: some View {
        Button(action: download) {
            HStack(spacing: 8) {
                Image(systemName: isDownloaded ? "checkmark.icloud.fill" : "icloud.and.arrow.down")
                Text(isDownloaded ? "Downloaded" : "Save Offline")
                    .font(DesignSystem.Typography.appFont(style: .caption))
                    .fontWeight(.semibold)
            }
            .foregroundColor(isDownloaded ? .green : DesignSystem.Colors.accent)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isDownloaded ? Color.green.opacity(0.1) : DesignSystem.Colors.accent.opacity(0.1))
            .clipShape(Capsule())
        }
        .disabled(isDownloaded)
        .onAppear {
            let routeId = route?.id ?? mountain.id
            isDownloaded = offlineManager.isRouteDownloaded(routeId)
        }
    }

    private func download() {
        Task {
            await offlineManager.downloadRoute(mountain: mountain, route: route)
            isDownloaded = true
            HapticManager.shared.success()
        }
    }
}
