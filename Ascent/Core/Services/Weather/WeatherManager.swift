import Foundation
import Combine
import CoreLocation
import WeatherKit
import SwiftUI

// =========================================
// === DATEI: WeatherManager.swift ===
// === Wetter-Integration für Touren ===
// =========================================

struct MountainWeather: Identifiable {
    let id = UUID()
    let temperature: Double
    let feelsLike: Double
    let conditionSymbol: String
    let conditionDescription: String
    let windSpeed: Double
    let windDirection: String
    let humidity: Double
    let precipitationChance: Double
    let uvIndex: Int
    let visibility: Double
    let hourlyForecast: [HourlyWeather]
    let alerts: [WeatherAlert]

    var temperatureFormatted: String {
        "\(Int(round(temperature)))°C"
    }
    var feelsLikeFormatted: String {
        "\(Int(round(feelsLike)))°C"
    }
    var windSpeedFormatted: String {
        "\(Int(round(windSpeed))) km/h"
    }

    var safetyLevel: SafetyLevel {
        if !alerts.isEmpty { return .danger }
        if windSpeed > 60 || temperature < -15 || precipitationChance > 0.8 { return .warning }
        if windSpeed > 40 || temperature < -5 || precipitationChance > 0.5 { return .caution }
        return .good
    }

    enum SafetyLevel {
        case good, caution, warning, danger

        var color: Color {
            switch self {
            case .good:    return .green
            case .caution: return .yellow
            case .warning: return .orange
            case .danger:  return .red
            }
        }
        var icon: String {
            switch self {
            case .good:    return "checkmark.shield.fill"
            case .caution: return "exclamationmark.triangle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .danger:  return "xmark.shield.fill"
            }
        }
        var label: String {
            switch self {
            case .good:    return "Good Conditions"
            case .caution: return "Be Cautious"
            case .warning: return "Poor Conditions"
            case .danger:  return "Dangerous"
            }
        }

        // MARK: - Pastel helpers (iteration 19)

        /// Pastel accent for sentence-case badges + dot indicators.
        /// Replaces the legacy traffic-light .color in any new view.
        var pastelColor: Color {
            switch self {
            case .good:    return DesignSystem.Colors.meadow
            case .caution: return DesignSystem.Colors.alpenglow
            case .warning: return DesignSystem.Colors.alpenglow
            case .danger:  return DesignSystem.Colors.ember
            }
        }

        /// Translucent companion for pastelColor — capsule fills,
        /// soft tints, container backgrounds.
        var pastelSoftColor: Color {
            switch self {
            case .good:    return DesignSystem.Colors.meadowSoft
            case .caution: return DesignSystem.Colors.alpenglowSoft
            case .warning: return DesignSystem.Colors.alpenglowSoft
            case .danger:  return DesignSystem.Colors.ember.opacity(0.15)
            }
        }

        /// Sentence-case label for the new vocabulary
        /// (the legacy .label is kept for backward compatibility
        /// with LiveRecordView and any other consumer).
        var sentenceLabel: String {
            switch self {
            case .good:    return "Good conditions"
            case .caution: return "Caution"
            case .warning: return "Warning"
            case .danger:  return "Danger"
            }
        }
    }
}

struct HourlyWeather: Identifiable {
    let id = UUID()
    let hour: Date
    let temperature: Double
    let conditionSymbol: String
    let precipitationChance: Double
    let windSpeed: Double
}

struct WeatherAlert: Identifiable {
    let id = UUID()
    let title: String
    let summary: String
    let severity: AlertSeverity

    enum AlertSeverity: String {
        case minor, moderate, severe, extreme

        var color: Color {
            switch self {
            case .minor:    return .yellow
            case .moderate: return .orange
            case .severe:   return .red
            case .extreme:  return .purple
            }
        }
    }
}

@MainActor
class WeatherManager: ObservableObject {
    static let shared = WeatherManager()

    @Published var currentWeather: MountainWeather?
    @Published var isLoading = false
    @Published var error: String?

    private let weatherService = WeatherService.shared
    private var cache: [String: (weather: MountainWeather, timestamp: Date)] = [:]
    private let cacheTimeout: TimeInterval = 900 // 15 min

    func fetchWeather(latitude: Double, longitude: Double) async {
        let cacheKey = "\(Int(latitude * 100))_\(Int(longitude * 100))"

        if let cached = cache[cacheKey],
           Date().timeIntervalSince(cached.timestamp) < cacheTimeout {
            self.currentWeather = cached.weather
            return
        }

        isLoading = true
        error = nil

        do {
            let location = CLLocation(latitude: latitude, longitude: longitude)
            let weather = try await weatherService.weather(for: location)

            let current = weather.currentWeather
            let hourly = Array(weather.hourlyForecast.prefix(24))

            let hourlyItems = hourly.map { hour in
                HourlyWeather(
                    hour: hour.date,
                    temperature: hour.temperature.value,
                    conditionSymbol: hour.symbolName,
                    precipitationChance: hour.precipitationChance,
                    windSpeed: hour.wind.speed.converted(to: .kilometersPerHour).value
                )
            }

            var alerts: [WeatherAlert] = []
            if let weatherAlerts = weather.weatherAlerts {
                alerts = weatherAlerts.map { alert in
                    let severity: WeatherAlert.AlertSeverity
                    switch alert.severity {
                    case .minor:    severity = .minor
                    case .moderate: severity = .moderate
                    case .severe:   severity = .severe
                    case .extreme:  severity = .extreme
                    default:        severity = .minor
                    }
                    return WeatherAlert(
                        title: alert.summary,
                        summary: alert.detailsURL.absoluteString,
                        severity: severity
                    )
                }
            }

            let windDirection = compassDirection(from: current.wind.direction.value)

            let mountainWeather = MountainWeather(
                temperature: current.temperature.value,
                feelsLike: current.apparentTemperature.value,
                conditionSymbol: current.symbolName,
                conditionDescription: current.condition.description,
                windSpeed: current.wind.speed.converted(to: .kilometersPerHour).value,
                windDirection: windDirection,
                humidity: current.humidity * 100,
                precipitationChance: hourly.first?.precipitationChance ?? 0,
                uvIndex: current.uvIndex.value,
                visibility: current.visibility.converted(to: .kilometers).value,
                hourlyForecast: hourlyItems,
                alerts: alerts
            )

            self.currentWeather = mountainWeather
            self.cache[cacheKey] = (mountainWeather, Date())
            self.isLoading = false
        } catch {
            self.error = "Weather data unavailable"
            self.isLoading = false
        }
    }

    private func compassDirection(from degrees: Double) -> String {
        let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = Int((degrees + 22.5) / 45.0) % 8
        return directions[index]
    }
}

// MARK: - Weather Card View (reusable component)
struct WeatherCardView: View {
    let weather: MountainWeather
    var compact: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 12) {
            // Safety Banner
            if weather.safetyLevel != .good || !weather.alerts.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: weather.safetyLevel.icon)
                        .foregroundColor(weather.safetyLevel.color)
                    Text(weather.safetyLevel.label)
                        .font(.app(.caption))
                        .fontWeight(.bold)
                        .foregroundColor(weather.safetyLevel.color)
                    Spacer()
                }
                .padding(8)
                .background(weather.safetyLevel.color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Current conditions
            HStack(spacing: 12) {
                Image(systemName: weather.conditionSymbol)
                    .font(.app(size: compact ? 28 : 36))
                    .symbolRenderingMode(.multicolor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(weather.temperatureFormatted)
                        .font(.app(size: compact ? 22 : 28, weight: .bold))
                    Text("Feels like \(weather.feelsLikeFormatted)")
                        .font(.app(.caption))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }

                Spacer()

                if !compact {
                    VStack(alignment: .trailing, spacing: 4) {
                        Label(weather.windSpeedFormatted, systemImage: "wind")
                        Label("\(Int(weather.humidity))%", systemImage: "humidity.fill")
                        Label("UV \(weather.uvIndex)", systemImage: "sun.max.fill")
                    }
                    .font(.app(.caption))
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                }
            }

            // Hourly forecast
            if !compact && !weather.hourlyForecast.isEmpty {
                Divider()
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(weather.hourlyForecast) { hour in
                            VStack(spacing: 4) {
                                Text(hourLabel(hour.hour))
                                    .font(.app(.caption2))
                                    .foregroundColor(DesignSystem.Colors.secondaryText)
                                Image(systemName: hour.conditionSymbol)
                                    .symbolRenderingMode(.multicolor)
                                    .font(.app(size: 18))
                                Text("\(Int(round(hour.temperature)))°")
                                    .font(.app(.caption))
                                    .fontWeight(.semibold)
                                if hour.precipitationChance > 0.1 {
                                    Text("\(Int(hour.precipitationChance * 100))%")
                                        .font(.app(size: 9))
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
            }

            // Alerts
            ForEach(weather.alerts) { alert in
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(alert.severity.color)
                    Text(alert.title)
                        .font(.app(.caption))
                        .fontWeight(.medium)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(alert.severity.color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(compact ? 12 : 16)
        .background(DesignSystem.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func hourLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH"
        return formatter.string(from: date)
    }
}
