path = "Ascent/ElevationProfileView.swift"
with open(path, "r") as f:
    text = f.read()

old = """struct ElevationProfileView: View {
    let routePoints: [CLLocation]
    var currentPosition: Double? = nil // distance km from start for live tracker
    var compact: Bool = false
    
    @State private var selectedDistance: Double?
    @State private var zoomScale: Double = 1.0
    @State private var processTask: Task<Void, Never>? = nil"""

new = """struct ElevationProfileView: View {
    let routePoints: [CLLocation]
    var currentPosition: Double? = nil // distance km from start for live tracker
    var compact: Bool = false
    var scrubDistanceOut: Binding<Double?>? = nil
    
    @State private var internalSelectedDistance: Double?
    private var selectedDistance: Double? {
        get { scrubDistanceOut?.wrappedValue ?? internalSelectedDistance }
        nonmutating set {
            if let binding = self.scrubDistanceOut {
                binding.wrappedValue = newValue
            } else {
                self.internalSelectedDistance = newValue
            }
        }
    }
    @State private var zoomScale: Double = 1.0
    @State private var processTask: Task<Void, Never>? = nil"""

with open(path, "w") as f:
    f.write(text.replace(old, new))
