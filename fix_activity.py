path = "Ascent/ActivityDetailView.swift"
with open(path, "r") as f:
    text = f.read()

# Add state variable
if "@State private var scrubDistance: Double? = nil" not in text:
    state_str = "    @State private var showPhotoPopover = false\n    @State private var scrubDistance: Double? = nil"
    text = text.replace("    @State private var showPhotoPopover = false", state_str)

# Pass it into ElevationProfileView
old_ele = "ElevationProfileView(routePoints: tour.routeLocations, compact: true)"
new_ele = "ElevationProfileView(routePoints: tour.routeLocations, compact: true, scrubDistanceOut: $scrubDistance)"
if old_ele in text:
    text = text.replace(old_ele, new_ele)

# Use it in Map to show a point
# We need to find the Map.
old_map = """            Map {
                MapPolyline(coordinates: tour.routeCoordinates)"""

new_map = """            Map {
                MapPolyline(coordinates: tour.routeCoordinates)
                    .stroke(accent, lineWidth: 4)
                    
                if let dist = scrubDistance, let point = tour.routeLocations.first(where: { abs($0.distance(from: tour.routeLocations.first!) / 1000 - dist) < 0.1 }) ?? tour.routeLocations.first {
                    Annotation("", coordinate: point.coordinate) {
                        Circle()
                            .fill(accent)
                            .frame(width: 16, height: 16)
                            .overlay(Circle().stroke(Color.white, lineWidth: 3))
                            .shadow(radius: 4)
                            // DO NOT use map animation when scrubbing!
                            .animation(nil, value: dist)
                    }
                }"""

# But wait, tour.routeCoordinates) doesn't have the stroke on exactly the same line in old_map.
text = text.replace("                    ElevationProfileView(routePoints: tour.routeLocations, compact: true)", "                    ElevationProfileView(routePoints: tour.routeLocations, compact: true, scrubDistanceOut: $scrubDistance)")

map_str = """            Map {
                MapPolyline(coordinates: tour.routeCoordinates)
                    .stroke(accent, lineWidth: 4)"""
map_new = """            Map {
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
                }"""

if map_str in text:
    text = text.replace(map_str, map_new)

with open(path, "w") as f:
    f.write(text)
