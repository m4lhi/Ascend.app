import Foundation

// Central place for third-party API keys.
// In production, move these out of source and into Xcode build settings or a remote config service.
enum APIKeys {
    // OpenWeatherMap — used for raster tile overlays (clouds, precipitation, temperature)
    // Sign up: https://home.openweathermap.org/api_keys
    static let openWeatherMap = "b6ed29e3ad563c5b8cda24910bb8ed78"
}
