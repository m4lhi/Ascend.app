import Foundation
import CoreLocation
import UniformTypeIdentifiers
import SwiftUI

// Imports a .gpx file into either a SavedRoute or a MountainRoute (per user choice).
// Parses the standard GPX 1.1 schema: <trk>/<trkseg>/<trkpt lat lon><ele>...
struct ImportedGPXRoute: Identifiable {
    let id = UUID()
    let name: String
    let coordinates: [CLLocationCoordinate2D]
    let elevations: [Int]              // meters, parallel to coordinates
    let totalDistanceKm: Double
    let totalElevationGainM: Int
    let totalDescentM: Int
}

enum GPXImporterError: Error, LocalizedError {
    case fileUnreadable
    case invalidXML
    case noTrackPoints

    var errorDescription: String? {
        switch self {
        case .fileUnreadable: return "Could not open the selected file."
        case .invalidXML:     return "The file is not valid GPX XML."
        case .noTrackPoints:  return "GPX contains no track points."
        }
    }
}

enum GPXImporter {
    /// Parse a GPX file from disk URL into a structured route.
    static func parse(url: URL) throws -> ImportedGPXRoute {
        // Security-scoped resource for files picked via UIDocumentPicker
        let needsScope = url.startAccessingSecurityScopedResource()
        defer { if needsScope { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url) else {
            throw GPXImporterError.fileUnreadable
        }

        let parser = GPXParser()
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = parser
        guard xmlParser.parse() else {
            throw GPXImporterError.invalidXML
        }

        let coords = parser.coords
        let elevs = parser.elevations
        guard !coords.isEmpty else { throw GPXImporterError.noTrackPoints }

        var distanceM: Double = 0
        for i in 1..<coords.count {
            let a = CLLocation(latitude: coords[i - 1].latitude, longitude: coords[i - 1].longitude)
            let b = CLLocation(latitude: coords[i].latitude, longitude: coords[i].longitude)
            distanceM += b.distance(from: a)
        }

        var ascent = 0
        var descent = 0
        for i in 1..<elevs.count {
            let dz = elevs[i] - elevs[i - 1]
            if dz > 0 { ascent += dz } else { descent += -dz }
        }

        let name = parser.trackName
            ?? url.deletingPathExtension().lastPathComponent
            ?? "Imported Route"

        return ImportedGPXRoute(
            name: name,
            coordinates: coords,
            elevations: elevs,
            totalDistanceKm: distanceM / 1000.0,
            totalElevationGainM: ascent,
            totalDescentM: descent
        )
    }
}

// MARK: - XML Parser

private final class GPXParser: NSObject, XMLParserDelegate {
    var coords: [CLLocationCoordinate2D] = []
    var elevations: [Int] = []
    var trackName: String?

    private var currentLat: Double?
    private var currentLon: Double?
    private var currentEle: Double?
    private var currentText = ""
    private var inTrackName = false

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        currentText = ""
        if elementName == "trkpt" {
            currentLat = Double(attributeDict["lat"] ?? "")
            currentLon = Double(attributeDict["lon"] ?? "")
            currentEle = nil
        } else if elementName == "name" {
            // Take only the first <name> we see (track name)
            if trackName == nil { inTrackName = true }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        switch elementName {
        case "ele":
            currentEle = Double(currentText.trimmingCharacters(in: .whitespacesAndNewlines))
        case "name":
            if inTrackName {
                trackName = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
                inTrackName = false
            }
        case "trkpt":
            if let lat = currentLat, let lon = currentLon {
                coords.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
                elevations.append(Int((currentEle ?? 0).rounded()))
            }
            currentLat = nil; currentLon = nil; currentEle = nil
        default:
            break
        }
    }
}

// MARK: - SwiftUI Document Picker

struct GPXDocumentPicker: UIViewControllerRepresentable {
    let onPicked: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // .xml is the closest UTType for GPX; many GPX files are also detected as .item
        let types: [UTType] = [
            UTType(filenameExtension: "gpx") ?? .xml,
            .xml,
            .item
        ]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPicked: onPicked) }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPicked: (URL) -> Void
        init(onPicked: @escaping (URL) -> Void) { self.onPicked = onPicked }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first { onPicked(url) }
        }
    }
}
