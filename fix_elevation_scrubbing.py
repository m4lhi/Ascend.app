with open("Ascent/ElevationProfileView.swift", "r") as f:
    text = f.read()

# Add binding for external selected distance
if "@Binding var externalScrubDistance: Double?" not in text:
    print("Will patch")
