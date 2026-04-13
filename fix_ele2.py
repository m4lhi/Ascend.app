import re
path = "Ascent/ElevationProfileView.swift"
with open(path, "r") as f:
    text = f.read()

# Replace withAnimation blocks manually.
text = re.sub(
    r'withAnimation\(\.interactiveSpring\(response: 0.2, dampingFraction: 0.8\)\) \{\s*(selectedDistance = distance)\s*\}',
    r'\1',
    text
)
text = re.sub(
    r'withAnimation\(\.spring\(\)\) \{\s*(selectedDistance = nil)\s*\}',
    r'\1',
    text
)

# And one for map pin animation!
text = re.sub(
    r'\.overlay\(Circle\(\)\.stroke\(Color\.white, lineWidth: 3\)\)\s*\.shadow\(radius: 4\)',
    r'.overlay(Circle().stroke(Color.white, lineWidth: 3))\n                                    .shadow(radius: 4)\n                                    .animation(.none, value: sel)',
    text
)

with open(path, "w") as f:
    f.write(text)
