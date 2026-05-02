import SwiftUI
import CoreLocation

// One-stop pro analysis sheet for a mountain: forecast, avalanche danger, pitch breakdown.
// Pulls Open-Meteo (mountain weather), EAWS/SLF (avalanche bulletin), and analyzes the
// route's polyline + elevation profile for pitch zones.
struct MountainProAnalysisSheet: View {
    let mountain: Mountain
    @Environment(\.dismiss) var dismiss

    @State private var forecast: MountainForecast?
    @State private var bulletin: AvalancheBulletin?
    @State private var pitch: PitchAnalysis?
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let accent = DesignSystem.Colors.accent

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Header
                        VStack(alignment: .leading, spacing: 4) {
                            Text(mountain.name)
                                .font(.app(size: 24, weight: .bold))
                            Text("\(mountain.elevation)m · \(mountain.region)")
                                .font(.app(size: 13))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                        if isLoading {
                            HStack { Spacer(); ProgressView(); Spacer() }
                                .padding(.vertical, 60)
                        }

                        if let forecast {
                            forecastCard(forecast)
                        }

                        if let bulletin {
                            avalancheCard(bulletin)
                        } else if !isLoading {
                            unavailableCard(
                                title: "Avalanche Bulletin",
                                message: "No bulletin available for this region.",
                                icon: "exclamationmark.triangle"
                            )
                        }

                        if let pitch {
                            pitchCard(pitch)
                        } else if !isLoading {
                            unavailableCard(
                                title: "Pitch Analysis",
                                message: "No route polyline or elevation profile available for this peak.",
                                icon: "chart.line.uptrend.xyaxis"
                            )
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.app(size: 12))
                                .foregroundColor(.red)
                                .padding(.horizontal, 20)
                        }

                        Spacer(minLength: 30)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                        .font(.app(.body).weight(.bold))
                }
            }
            .task { await loadAll() }
        }
    }

    // MARK: - Cards

    @ViewBuilder
    private func forecastCard(_ f: MountainForecast) -> some View {
        let info = WeatherCodeInfo.from(f.weatherCode)
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Mountain Weather", systemImage: "cloud.sun.fill")
                    .font(.app(size: 14, weight: .heavy))
                    .foregroundColor(accent)
                Spacer()
                Text("Open-Meteo")
                    .font(.app(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
            }

            HStack(alignment: .top, spacing: 16) {
                Image(systemName: info.symbol)
                    .symbolRenderingMode(.multicolor)
                    .font(.app(size: 44))

                VStack(alignment: .leading, spacing: 2) {
                    if let temp = f.temperatureCelsius {
                        Text("\(Int(temp.rounded()))°C")
                            .font(.app(size: 28, weight: .heavy))
                    }
                    Text(info.label)
                        .font(.app(size: 13, weight: .semibold))
                    if let feels = f.feelsLikeCelsius {
                        Text("Feels \(Int(feels.rounded()))°C")
                            .font(.app(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }

            // Wind / freezing-level grid
            HStack(spacing: 12) {
                metric(label: "Summit Wind",
                       value: f.summitWindKmh.map { "\(Int($0.rounded())) km/h" } ?? "—",
                       icon: "wind",
                       highlight: (f.summitWindKmh ?? 0) > 50 ? .red : nil)
                metric(label: "Valley Wind",
                       value: f.valleyWindKmh.map { "\(Int($0.rounded())) km/h" } ?? "—",
                       icon: "wind")
                metric(label: "Freezing Level",
                       value: f.freezingLevelM.map { "\(Int($0.rounded())) m" } ?? "—",
                       icon: "thermometer.snowflake")
            }

            // 24h hourly mini-strip
            if !f.hourly.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(0..<min(f.hourly.count, 24), id: \.self) { i in
                            let h = f.hourly[i]
                            VStack(spacing: 4) {
                                Text(hourLabel(h.timeISO))
                                    .font(.app(size: 9, weight: .bold))
                                    .foregroundColor(.secondary)
                                Image(systemName: WeatherCodeInfo.from(h.weatherCode).symbol)
                                    .symbolRenderingMode(.multicolor)
                                    .font(.app(size: 16))
                                Text(h.temperature.map { "\(Int($0.rounded()))°" } ?? "—")
                                    .font(.app(size: 11, weight: .heavy))
                            }
                            .frame(width: 36)
                        }
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                .stroke(Color.black.opacity(0.04), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        .padding(.horizontal, DesignSystem.Spacing.md)
    }

    @ViewBuilder
    private func avalancheCard(_ b: AvalancheBulletin) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Avalanche Danger", systemImage: "exclamationmark.triangle.fill")
                    .font(.app(size: 14, weight: .heavy))
                    .foregroundColor(.orange)
                Spacer()
                Text(b.regionName)
                    .font(.app(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            HStack(spacing: 14) {
                // Big level disc
                ZStack {
                    Circle()
                        .fill(Color(hex: b.dangerColorHex) ?? .gray)
                        .frame(width: 64, height: 64)
                    Text("\(b.dangerLevel)")
                        .font(.app(size: 28, weight: .black))
                        .foregroundColor(b.dangerLevel >= 4 ? .white : .black)
                }
                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(b.dangerLabel.uppercased())
                        .font(.app(size: 16, weight: .heavy))
                        .tracking(0.8)
                    if !b.problems.isEmpty {
                        Text(b.problems.prefix(3).joined(separator: ", ").replacingOccurrences(of: "_", with: " "))
                            .font(.app(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    if !b.validUntil.isEmpty {
                        Text("Valid until \(prettyDate(b.validUntil))")
                            .font(.app(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }

            let summary = b.summaryDE ?? b.summaryEN
            if !summary.isEmpty {
                Text(summary)
                    .font(.app(size: 12))
                    .foregroundColor(.primary)
                    .lineLimit(8)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                .stroke(Color.black.opacity(0.04), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        .padding(.horizontal, DesignSystem.Spacing.md)
    }

    @ViewBuilder
    private func pitchCard(_ p: PitchAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Slope Analysis", systemImage: "triangle.fill")
                    .font(.app(size: 14, weight: .heavy))
                    .foregroundColor(.purple)
                Spacer()
            }

            HStack(spacing: 14) {
                pitchStat(label: "Max", value: String(format: "%.0f°", p.maxAngleDeg))
                pitchStat(label: "Avg",  value: String(format: "%.0f°", p.avgAngleDeg))
                pitchStat(label: "Max %", value: String(format: "%.0f%%", p.maxGradientPct))
            }

            // Distance-in-band stacked bar — visualizes time spent in steep zones
            let total = max(p.totalDistanceM, 1)
            VStack(alignment: .leading, spacing: 6) {
                Text("Distance per slope band")
                    .font(.app(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                GeometryReader { geo in
                    HStack(spacing: 1) {
                        ForEach(SlopeBand.allCases, id: \.rawValue) { band in
                            let d = p.distanceInBandsM[band] ?? 0
                            if d > 0 {
                                Rectangle()
                                    .fill(Color(hex: band.colorHex) ?? .gray)
                                    .frame(width: max(2, geo.size.width * d / total))
                            }
                        }
                    }
                    .clipShape(Capsule())
                }
                .frame(height: 14)
            }

            // Legend (only show bands with data, in steep order)
            VStack(alignment: .leading, spacing: 4) {
                ForEach(SlopeBand.allCases, id: \.rawValue) { band in
                    if let d = p.distanceInBandsM[band], d > 5 {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color(hex: band.colorHex) ?? .gray)
                                .frame(width: 9, height: 9)
                            Text(band.rawValue)
                                .font(.app(size: 11, weight: .semibold))
                            Spacer()
                            Text(String(format: "%.2f km", d / 1000))
                                .font(.app(size: 11))
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                .stroke(Color.black.opacity(0.04), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        .padding(.horizontal, DesignSystem.Spacing.md)
    }

    @ViewBuilder
    private func unavailableCard(title: String, message: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.app(size: 22))
                .foregroundColor(.gray)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.app(size: 13, weight: .heavy))
                Text(message).font(.app(size: 11)).foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Color.white.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 20)
    }

    private func metric(label: String, value: String, icon: String, highlight: Color? = nil) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.app(size: 12))
                .foregroundColor(highlight ?? .secondary)
            Text(value)
                .font(.app(size: 13, weight: .heavy))
                .foregroundColor(highlight ?? .primary)
            Text(label)
                .font(.app(size: 9, weight: .bold))
                .tracking(0.6)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.gray.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func pitchStat(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.app(size: 18, weight: .heavy))
            Text(label)
                .font(.app(size: 9, weight: .bold))
                .tracking(0.6)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.gray.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Loading

    private func loadAll() async {
        guard let lat = mountain.latitude, let lon = mountain.longitude else {
            isLoading = false
            return
        }
        let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)

        async let weatherTask: MountainForecast? = try? OpenMeteoService.shared.fetchMountainForecast(
            coord: coord,
            elevationMeters: mountain.elevation
        )
        async let avalancheTask: AvalancheBulletin? = try? AvalancheService.shared.fetchBulletin(for: coord)

        // Pitch analysis runs locally (no network)
        let pitchResult: PitchAnalysis? = {
            guard let route = mountain.routes?.first, !route.route_polyline.isEmpty else { return nil }
            let coords = PolylineUtility.decode(polyline: route.route_polyline)
            let elevs = route.elevation_profile ?? []
            return PitchAnalyzer.analyze(coords: coords, elevations: elevs)
        }()

        let f = await weatherTask
        let b = await avalancheTask

        await MainActor.run {
            self.forecast = f
            self.bulletin = b
            self.pitch = pitchResult
            self.isLoading = false
        }
    }

    private func hourLabel(_ iso: String) -> String {
        // ISO: "2025-12-01T14:00"
        guard iso.count >= 13 else { return "—" }
        let hourPart = iso.dropFirst(11).prefix(2)
        return "\(hourPart)h"
    }

    private func prettyDate(_ iso: String) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: iso) ?? ISO8601DateFormatter().date(from: iso) {
            let out = DateFormatter()
            out.dateStyle = .medium
            out.timeStyle = .short
            return out.string(from: d)
        }
        return iso
    }
}

// Color(hex:) is provided by MountainDatabase.swift
