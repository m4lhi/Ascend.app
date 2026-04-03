import MapKit
import CoreLocation

// =========================================
// === POLYLINE UTILITY ===
// =========================================
public struct PolylineUtility {
    
    /// Decodes a Google Polyline string into an array of CLLocationCoordinate2D.
    /// This uses the standard algorithm for variable-length integer decoding for ASCII characters.
    public static func decode(polyline: String) -> [CLLocationCoordinate2D] {
        var coordinates: [CLLocationCoordinate2D] = []
        var index = polyline.startIndex
        var lat = 0.0
        var lng = 0.0
        
        while index < polyline.endIndex {
            do {
                let latOffset = try decodeOffset(from: polyline, index: &index)
                lat += latOffset
                
                let lngOffset = try decodeOffset(from: polyline, index: &index)
                lng += lngOffset
                
        // The correct order for Google Polylines is latitude then longitude, BUT
        // OSRM V1 encodes `lng, lat` arrays. Wait, standard OSRM v5 encodes normally.
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        coordinates.append(coordinate)
            } catch {
                break
            }
        }
        
        return coordinates
    }
    
    private static func decodeOffset(from encoded: String, index: inout String.Index) throws -> Double {
        var shift = 0
        var result = 0
        
        while index < encoded.endIndex {
            let byte = Int(encoded[index].asciiValue ?? 0) - 63
            index = encoded.index(after: index)
            
            result |= (byte & 0x1f) << shift
            shift += 5
            
            if byte < 0x20 {
                let value = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1))
                return Double(value) / 1e5
            }
        }
        
        throw NSError(domain: "PolylineUtility", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid polyline encoding"])
    }
}
