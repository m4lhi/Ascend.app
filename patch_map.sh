sed -i '' 's/        Map {/    private var simplifiedCoordinates: [CLLocationCoordinate2D] {\n        guard coordinates.count > 30 else { return coordinates }\n        let step = coordinates.count \/ 30\n        var result: [CLLocationCoordinate2D] = []\n        for i in stride(from: 0, to: coordinates.count, by: step) {\n            result.append(coordinates[i])\n        }\n        if let last = coordinates.last {\n            result.append(last)\n        }\n        return result\n    }\n\n    var body: some View {\n        Map {/' Ascent/ActivityCardView.swift

sed -i '' 's/MapPolyline(coordinates: coordinates)/MapPolyline(coordinates: simplifiedCoordinates)/' Ascent/ActivityCardView.swift

sed -i '' 's/\.mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))/\.mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))\n        \.mapControlVisibility(.hidden)/' Ascent/ActivityCardView.swift
