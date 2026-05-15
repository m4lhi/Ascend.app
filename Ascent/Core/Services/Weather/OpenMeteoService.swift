import Foundation
import CoreLocation

// Mountain-aware weather forecasts via Open-Meteo (free, no API key required).
// Docs: https://open-meteo.com/en/docs
//
// We pull the standard forecast plus high-altitude wind levels (850 hPa ≈ 1500m, 700 hPa ≈ 3000m)
// which are the variables that actually matter on a summit.
struct MountainForecast: Codable {
    let summary: String
    let summitWindKmh: Double?       // 700 hPa wind speed (≈ 3000m)
    let valleyWindKmh: Double?       // 10m surface wind
    let temperatureCelsius: Double?
    let feelsLikeCelsius: Double?
    let precipitationMm: Double?
    let snowfallCm: Double?
    let cloudCoverPct: Double?
    let weatherCode: Int?
    let windGustsKmh: Double?
    let freezingLevelM: Double?      // 0°C isotherm altitude
    let hourly: [HourlySlice]
    let daily: [DailySlice]

    struct HourlySlice: Codable {
        let timeISO: String
        let temperature: Double?
        let precipitation: Double?
        let windKmh: Double?
        let windDirectionDeg: Double?
        let weatherCode: Int?
    }

    struct DailySlice: Codable {
        let dateISO: String
        let tempMin: Double?
        let tempMax: Double?
        let precipitation: Double?
        let snowfall: Double?
        let windMaxKmh: Double?
        let windGustsMaxKmh: Double?
        let weatherCode: Int?
        let sunriseISO: String?
        let sunsetISO: String?
    }
}

// WMO weather codes — converted to user-readable text + SF Symbol
struct WeatherCodeInfo {
    let label: String
    let symbol: String

    static func from(_ code: Int?) -> WeatherCodeInfo {
        guard let code else { return WeatherCodeInfo(label: "Unknown", symbol: "questionmark.circle") }
        switch code {
        case 0:           return WeatherCodeInfo(label: "Clear", symbol: "sun.max.fill")
        case 1, 2:        return WeatherCodeInfo(label: "Mostly Clear", symbol: "sun.min.fill")
        case 3:           return WeatherCodeInfo(label: "Overcast", symbol: "cloud.fill")
        case 45, 48:      return WeatherCodeInfo(label: "Fog", symbol: "cloud.fog.fill")
        case 51, 53, 55:  return WeatherCodeInfo(label: "Drizzle", symbol: "cloud.drizzle.fill")
        case 61, 63, 65:  return WeatherCodeInfo(label: "Rain", symbol: "cloud.rain.fill")
        case 66, 67:      return WeatherCodeInfo(label: "Freezing Rain", symbol: "cloud.sleet.fill")
        case 71, 73, 75:  return WeatherCodeInfo(label: "Snow", symbol: "cloud.snow.fill")
        case 77:          return WeatherCodeInfo(label: "Snow Grains", symbol: "snowflake")
        case 80, 81, 82:  return WeatherCodeInfo(label: "Showers", symbol: "cloud.heavyrain.fill")
        case 85, 86:      return WeatherCodeInfo(label: "Snow Showers", symbol: "cloud.snow.fill")
        case 95:          return WeatherCodeInfo(label: "Thunderstorm", symbol: "cloud.bolt.rain.fill")
        case 96, 99:      return WeatherCodeInfo(label: "Thunder + Hail", symbol: "cloud.bolt.fill")
        default:          return WeatherCodeInfo(label: "Unknown", symbol: "questionmark.circle")
        }
    }
}

@MainActor
final class OpenMeteoService {
    static let shared = OpenMeteoService()
    private init() {}

    func fetchMountainForecast(coord: CLLocationCoordinate2D,
                               elevationMeters: Int? = nil) async throws -> MountainForecast {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(coord.latitude)),
            URLQueryItem(name: "longitude", value: String(coord.longitude)),
            URLQueryItem(name: "current",
                         value: "temperature_2m,apparent_temperature,precipitation,weather_code,cloud_cover,wind_speed_10m,wind_gusts_10m,snowfall"),
            URLQueryItem(name: "hourly",
                         value: "temperature_2m,precipitation,weather_code,wind_speed_10m,wind_direction_10m,wind_speed_700hPa,freezing_level_height"),
            URLQueryItem(name: "daily",
                         value: "weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum,snowfall_sum,wind_speed_10m_max,wind_gusts_10m_max,sunrise,sunset"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "wind_speed_unit", value: "kmh"),
            URLQueryItem(name: "forecast_days", value: "7")
        ]
        if let elev = elevationMeters {
            components.queryItems?.append(URLQueryItem(name: "elevation", value: String(elev)))
        }

        let (data, response) = try await URLSession.shared.data(from: components.url!)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let raw = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
        return mapToForecast(raw, elevationMeters: elevationMeters)
    }

    private func mapToForecast(_ raw: OpenMeteoResponse, elevationMeters: Int?) -> MountainForecast {
        let info = WeatherCodeInfo.from(raw.current?.weatherCode)
        let summary = "\(info.label)" +
            (raw.current?.temperature != nil ? " · \(Int(raw.current!.temperature!.rounded()))°C" : "")

        // Find current hour's slice in the hourly arrays for high-altitude wind + freezing level
        var summitWind: Double? = nil
        var freezingLevel: Double? = nil
        if let times = raw.hourly?.time {
            let nowHourFormatter = DateFormatter()
            nowHourFormatter.dateFormat = "yyyy-MM-dd'T'HH:00"
            let target = nowHourFormatter.string(from: Date())
            if let idx = times.firstIndex(of: target) {
                summitWind = raw.hourly?.windSpeed700hPa?[safe: idx]
                freezingLevel = raw.hourly?.freezingLevel?[safe: idx]
            }
        }

        let hourlySlices: [MountainForecast.HourlySlice] = (0..<min(raw.hourly?.time?.count ?? 0, 24)).map { i in
            MountainForecast.HourlySlice(
                timeISO: raw.hourly?.time?[safe: i] ?? "",
                temperature: raw.hourly?.temperature?[safe: i],
                precipitation: raw.hourly?.precipitation?[safe: i],
                windKmh: raw.hourly?.windSpeed?[safe: i],
                windDirectionDeg: raw.hourly?.windDirection?[safe: i],
                weatherCode: raw.hourly?.weatherCode?[safe: i]
            )
        }

        let dailySlices: [MountainForecast.DailySlice] = (0..<min(raw.daily?.time?.count ?? 0, 7)).map { i in
            MountainForecast.DailySlice(
                dateISO: raw.daily?.time?[safe: i] ?? "",
                tempMin: raw.daily?.tempMin?[safe: i],
                tempMax: raw.daily?.tempMax?[safe: i],
                precipitation: raw.daily?.precipitationSum?[safe: i],
                snowfall: raw.daily?.snowfallSum?[safe: i],
                windMaxKmh: raw.daily?.windSpeedMax?[safe: i],
                windGustsMaxKmh: raw.daily?.windGustsMax?[safe: i],
                weatherCode: raw.daily?.weatherCode?[safe: i],
                sunriseISO: raw.daily?.sunrise?[safe: i],
                sunsetISO: raw.daily?.sunset?[safe: i]
            )
        }

        return MountainForecast(
            summary: summary,
            summitWindKmh: summitWind,
            valleyWindKmh: raw.current?.windSpeed10m,
            temperatureCelsius: raw.current?.temperature,
            feelsLikeCelsius: raw.current?.apparentTemp,
            precipitationMm: raw.current?.precipitation,
            snowfallCm: raw.current?.snowfall,
            cloudCoverPct: raw.current?.cloudCover,
            weatherCode: raw.current?.weatherCode,
            windGustsKmh: raw.current?.windGusts10m,
            freezingLevelM: freezingLevel,
            hourly: hourlySlices,
            daily: dailySlices
        )
    }
}

// MARK: - Open-Meteo wire format

private struct OpenMeteoResponse: Codable {
    let current: Current?
    let hourly: Hourly?
    let daily: Daily?

    struct Current: Codable {
        let temperature: Double?
        let apparentTemp: Double?
        let precipitation: Double?
        let weatherCode: Int?
        let cloudCover: Double?
        let windSpeed10m: Double?
        let windGusts10m: Double?
        let snowfall: Double?

        enum CodingKeys: String, CodingKey {
            case temperature   = "temperature_2m"
            case apparentTemp  = "apparent_temperature"
            case precipitation
            case weatherCode   = "weather_code"
            case cloudCover    = "cloud_cover"
            case windSpeed10m  = "wind_speed_10m"
            case windGusts10m  = "wind_gusts_10m"
            case snowfall
        }
    }

    struct Hourly: Codable {
        let time: [String]?
        let temperature: [Double]?
        let precipitation: [Double]?
        let weatherCode: [Int]?
        let windSpeed: [Double]?
        let windDirection: [Double]?
        let windSpeed700hPa: [Double]?
        let freezingLevel: [Double]?

        enum CodingKeys: String, CodingKey {
            case time
            case temperature      = "temperature_2m"
            case precipitation
            case weatherCode      = "weather_code"
            case windSpeed        = "wind_speed_10m"
            case windDirection    = "wind_direction_10m"
            case windSpeed700hPa  = "wind_speed_700hPa"
            case freezingLevel    = "freezing_level_height"
        }
    }

    struct Daily: Codable {
        let time: [String]?
        let weatherCode: [Int]?
        let tempMax: [Double]?
        let tempMin: [Double]?
        let precipitationSum: [Double]?
        let snowfallSum: [Double]?
        let windSpeedMax: [Double]?
        let windGustsMax: [Double]?
        let sunrise: [String]?
        let sunset: [String]?

        enum CodingKeys: String, CodingKey {
            case time
            case weatherCode      = "weather_code"
            case tempMax          = "temperature_2m_max"
            case tempMin          = "temperature_2m_min"
            case precipitationSum = "precipitation_sum"
            case snowfallSum      = "snowfall_sum"
            case windSpeedMax     = "wind_speed_10m_max"
            case windGustsMax     = "wind_gusts_10m_max"
            case sunrise
            case sunset
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
