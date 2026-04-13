path = "Ascent/ElevationProfileView.swift"
with open(path, "r") as f:
    text = f.read()

# I want to be 100% sure we don't change Map region while scrubbing in compact=false mode.
# If Map(interactionModes: []) { ... } is not updating region on scrub. Wait, `profile.mapCoords` isn't bound to position!

