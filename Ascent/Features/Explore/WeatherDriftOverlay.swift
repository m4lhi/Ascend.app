import SwiftUI

// Apple-Weather-style ambient drift overlay rendered on top of the map.
// Uses TimelineView + Canvas to paint:
//   • Soft cloud blobs that drift left → right at multiple parallax speeds
//   • Optional tilted rain/snow streaks for precipitation layers
// All driven by a single time signal — no SwiftUI re-layouts, runs at 60fps.

struct WeatherDriftOverlay: View {
    enum Style {
        case clouds
        case rain
        case snow
        case wind
        case none
    }

    let style: Style
    /// Wind direction in degrees (0 = north). Streaks tilt accordingly.
    var windDeg: Double = 270

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas(opaque: false) { context, size in
                switch style {
                case .clouds:    drawClouds(context: context, size: size, t: t)
                case .rain:      drawStreaks(context: context, size: size, t: t, color: .blue.opacity(0.55), length: 16)
                case .snow:      drawSnow(context: context, size: size, t: t)
                case .wind:      drawWindLines(context: context, size: size, t: t)
                case .none:      break
                }
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Cloud blobs with parallax (3 layers, slowest in back)

    private func drawClouds(context: GraphicsContext, size: CGSize, t: TimeInterval) {
        let layers: [(speed: Double, opacity: Double, blur: Double, count: Int, scale: Double)] = [
            (speed: 9,  opacity: 0.18, blur: 22, count: 3, scale: 1.0),  // far / slow
            (speed: 16, opacity: 0.22, blur: 14, count: 4, scale: 0.7),  // mid
            (speed: 28, opacity: 0.20, blur: 8,  count: 5, scale: 0.45)  // near / fast
        ]
        for (li, layer) in layers.enumerated() {
            let layerSeed = Double(li) * 17
            for i in 0..<layer.count {
                let ix = Double(i)
                let baseY = (Double((layerSeed + ix * 53).truncatingRemainder(dividingBy: 1.0)) * Double(size.height)) +
                            (sin(t * 0.2 + ix * 1.3) * 8)
                let y = ((ix * 71).truncatingRemainder(dividingBy: Double(size.height)) + sin(t * 0.18 + ix * 0.8) * 16)
                let cycleWidth = Double(size.width) + 240
                let progress = (t * layer.speed + ix * 87 + layerSeed).truncatingRemainder(dividingBy: cycleWidth)
                let x = progress - 120
                let radius = (60.0 + (ix * 11).truncatingRemainder(dividingBy: 35)) * layer.scale
                let rect = CGRect(
                    x: x - radius,
                    y: y - radius * 0.55,
                    width: radius * 2.4,
                    height: radius * 1.1
                )
                let path = Path(ellipseIn: rect)
                context.drawLayer { layerCtx in
                    layerCtx.addFilter(.blur(radius: layer.blur))
                    layerCtx.fill(path, with: .color(.white.opacity(layer.opacity)))
                }
                _ = baseY // baseY currently unused for placement variation only
            }
        }
    }

    // MARK: - Diagonal precipitation streaks

    private func drawStreaks(context: GraphicsContext, size: CGSize, t: TimeInterval, color: Color, length: Double) {
        // Translate wind direction into vector. 270° = wind from west → blowing east.
        let theta = (windDeg - 90) * .pi / 180  // map compass to math angle
        let dx = cos(theta)
        let dy = sin(theta)
        let speed = 220.0

        // Use a dense, deterministic grid of seeds
        let cols = 26
        let rows = 18
        for c in 0..<cols {
            for r in 0..<rows {
                let seed = Double(c * 79 + r * 31)
                let phase = (t * speed + seed * 17).truncatingRemainder(dividingBy: 800.0)
                let x0 = Double(c) * (Double(size.width) / Double(cols)) + sin(seed) * 6 + dx * phase
                let y0 = Double(r) * (Double(size.height) / Double(rows)) + cos(seed) * 6 + dy * phase
                let x = x0.truncatingRemainder(dividingBy: Double(size.width) + 40) - 20
                let y = y0.truncatingRemainder(dividingBy: Double(size.height) + 40) - 20

                var path = Path()
                path.move(to: CGPoint(x: x, y: y))
                path.addLine(to: CGPoint(x: x + dx * length, y: y + dy * length))
                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 1.0, lineCap: .round))
            }
        }
    }

    // MARK: - Snow flakes (dots that drift down + sideways with sway)

    private func drawSnow(context: GraphicsContext, size: CGSize, t: TimeInterval) {
        let count = 90
        for i in 0..<count {
            let seed = Double(i)
            let phase = (t * 30 + seed * 13).truncatingRemainder(dividingBy: 500.0)
            let baseX = (seed * 67).truncatingRemainder(dividingBy: Double(size.width))
            let sway = sin(t * 1.2 + seed * 0.5) * 14
            let x = baseX + sway
            let y = phase
            let r = 1.5 + sin(seed) * 0.8
            let rect = CGRect(x: x, y: y, width: r * 2, height: r * 2)
            context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.85)))
        }
    }

    // MARK: - Wind: subtle horizontal lines that flow + fade

    private func drawWindLines(context: GraphicsContext, size: CGSize, t: TimeInterval) {
        let theta = (windDeg - 90) * .pi / 180
        let dx = cos(theta)
        let dy = sin(theta)
        let lines = 22
        for i in 0..<lines {
            let seed = Double(i) * 31
            let phase = (t * 80 + seed * 11).truncatingRemainder(dividingBy: 900.0)
            let yBase = (seed * 19).truncatingRemainder(dividingBy: Double(size.height))
            let length = 50.0 + sin(seed) * 25
            let x = phase - 60
            let y = yBase + sin(t * 0.6 + seed) * 4

            var path = Path()
            path.move(to: CGPoint(x: x, y: y))
            path.addQuadCurve(
                to: CGPoint(x: x + dx * length, y: y + dy * length),
                control: CGPoint(x: x + dx * length * 0.5, y: y + dy * length * 0.5 - 6)
            )
            context.stroke(path, with: .color(.white.opacity(0.35)), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
        }
    }
}
