import Foundation
@_spi(Experimental) import MapboxMaps

// Adds raster tile overlays (OpenTopoMap, SwissTopo) on top of the base Mapbox style.
// These tile providers serve fully-rendered map tiles, so the overlay effectively replaces
// the visible map content. We keep a Mapbox base style so terrain/3D continues to work.
enum MapTileOverlayHelper {
    static let overlaySourceId = "ascent-topo-overlay-src"
    static let overlayLayerId  = "ascent-topo-overlay-layer"

    /// Apply or remove a raster overlay matching the given MapLayerType.
    /// Safe to call on every map style change — it cleans up the previous overlay first.
    static func apply(layer: MapLayerType, to map: MapboxMap) {
        // Always remove any previous overlay first
        removeOverlay(from: map)

        guard let template = layer.tileURLTemplate else { return }

        var source = RasterSource(id: overlaySourceId)
        source.tiles = [template]
        source.tileSize = 256
        // Reasonable global zoom range; SwissTopo tops out around 18, OpenTopoMap around 17
        source.minzoom = 1
        source.maxzoom = 18

        do {
            try map.addSource(source)
            var rasterLayer = RasterLayer(id: overlayLayerId, source: overlaySourceId)
            // Overlay layers (e.g. slope angle) sit on top of the base map at reduced opacity
            // so users still see the underlying terrain. Replacement layers are full opacity.
            rasterLayer.rasterOpacity = .constant(layer.isOverlay ? 0.65 : 1.0)
            try map.addLayer(rasterLayer)
        } catch {
            print("⚠️ Failed to add tile overlay for \(layer.rawValue): \(error)")
        }
    }

    static func removeOverlay(from map: MapboxMap) {
        if map.layerExists(withId: overlayLayerId) {
            try? map.removeLayer(withId: overlayLayerId)
        }
        if map.sourceExists(withId: overlaySourceId) {
            try? map.removeSource(withId: overlaySourceId)
        }
    }
}
