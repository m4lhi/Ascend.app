import Foundation
import CoreLocation
import UIKit
import SwiftUI

// =========================================
// === DATEI: GPXExporter.swift ===
// === GPX/KML Export für Touren ===
// =========================================

class GPXExporter {

    /// Generates GPX XML from route points and tour metadata
    static func generateGPX(
        name: String,
        date: Date,
        routePoints: [CLLocation],
        waypoints: [(name: String, coordinate: CLLocationCoordinate2D)]? = nil
    ) -> String {
        let dateFormatter = ISO8601DateFormatter()
        let dateStr = dateFormatter.string(from: date)

        var gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="Ascent App"
             xmlns="http://www.topografix.com/GPX/1/1"
             xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
             xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">
          <metadata>
            <name>\(escapeXML(name))</name>
            <time>\(dateStr)</time>
          </metadata>
        """

        // Waypoints
        if let wps = waypoints {
            for wp in wps {
                gpx += """

                  <wpt lat="\(wp.coordinate.latitude)" lon="\(wp.coordinate.longitude)">
                    <name>\(escapeXML(wp.name))</name>
                  </wpt>
                """
            }
        }

        // Track
        gpx += """

          <trk>
            <name>\(escapeXML(name))</name>
            <trkseg>
        """

        for point in routePoints {
            let timeStr = dateFormatter.string(from: point.timestamp)
            gpx += """

                  <trkpt lat="\(point.coordinate.latitude)" lon="\(point.coordinate.longitude)">
                    <ele>\(String(format: "%.1f", point.altitude))</ele>
                    <time>\(timeStr)</time>
                  </trkpt>
            """
        }

        gpx += """

            </trkseg>
          </trk>
        </gpx>
        """

        return gpx
    }

    /// Generates KML from route points
    static func generateKML(
        name: String,
        routePoints: [CLLocation]
    ) -> String {
        var kml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <kml xmlns="http://www.opengis.net/kml/2.2">
          <Document>
            <name>\(escapeXML(name))</name>
            <Style id="route">
              <LineStyle>
                <color>ff0066ff</color>
                <width>4</width>
              </LineStyle>
            </Style>
            <Placemark>
              <name>\(escapeXML(name))</name>
              <styleUrl>#route</styleUrl>
              <LineString>
                <altitudeMode>absolute</altitudeMode>
                <coordinates>
        """

        for point in routePoints {
            kml += "\(point.coordinate.longitude),\(point.coordinate.latitude),\(String(format: "%.1f", point.altitude)) "
        }

        kml += """

                </coordinates>
              </LineString>
            </Placemark>
          </Document>
        </kml>
        """

        return kml
    }

    /// Creates a temporary file and returns the URL for sharing
    static func exportToFile(content: String, filename: String) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)

        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("❌ Export error: \(error)")
            return nil
        }
    }

    private static func escapeXML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "'", with: "&apos;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

// MARK: - Export Sheet View
struct ExportSheetView: View {
    let tourName: String
    let tourDate: Date
    let routePoints: [CLLocation]
    @Environment(\.dismiss) var dismiss
    @State private var selectedFormat: ExportFormat = .gpx
    @State private var shareURL: URL?
    @State private var showShareSheet = false

    enum ExportFormat: String, CaseIterable {
        case gpx = "GPX"
        case kml = "KML"

        var icon: String {
            switch self {
            case .gpx: return "doc.text"
            case .kml: return "globe"
            }
        }

        var description: String {
            switch self {
            case .gpx: return "Universal format for GPS devices and apps"
            case .kml: return "Google Earth and Maps format"
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Format selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("EXPORT FORMAT")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundColor(.gray)
                        .tracking(2)

                    ForEach(ExportFormat.allCases, id: \.self) { format in
                        Button(action: { selectedFormat = format }) {
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(selectedFormat == format ? DesignSystem.Colors.accent.opacity(0.2) : Color.gray.opacity(0.1))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: format.icon)
                                        .foregroundColor(selectedFormat == format ? DesignSystem.Colors.accent : .gray)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(format.rawValue)
                                        .font(.system(.subheadline, design: .rounded))
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                    Text(format.description)
                                        .font(.system(.caption, design: .rounded))
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                if selectedFormat == format {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(DesignSystem.Colors.accent)
                                }
                            }
                            .padding(14)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                }

                // Tour info
                VStack(alignment: .leading, spacing: 8) {
                    Text("TOUR DETAILS")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundColor(.gray)
                        .tracking(2)

                    HStack {
                        Label(tourName, systemImage: "mountain.2.fill")
                        Spacer()
                        Text("\(routePoints.count) points")
                            .foregroundColor(.secondary)
                    }
                    .font(.system(.subheadline, design: .rounded))
                    .padding(14)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Spacer()

                // Export button
                Button(action: exportAndShare) {
                    Label("Export \(selectedFormat.rawValue)", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(20)
            .navigationTitle("Export Tour")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = shareURL {
                ShareSheet(activityItems: [url])
            }
        }
    }

    private func exportAndShare() {
        let content: String
        let filename: String

        switch selectedFormat {
        case .gpx:
            content = GPXExporter.generateGPX(name: tourName, date: tourDate, routePoints: routePoints)
            filename = "\(tourName.replacingOccurrences(of: " ", with: "_")).gpx"
        case .kml:
            content = GPXExporter.generateKML(name: tourName, routePoints: routePoints)
            filename = "\(tourName.replacingOccurrences(of: " ", with: "_")).kml"
        }

        if let url = GPXExporter.exportToFile(content: content, filename: filename) {
            shareURL = url
            showShareSheet = true
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
