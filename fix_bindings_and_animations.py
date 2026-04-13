import re
with open("Ascent/ElevationProfileView.swift", "r") as f:
    text = f.read()

# Replace any stray withAnimation(.spring) that still exists
text = re.sub(r'withAnimation\(\.spring\(\)\) \{\s*selectedDistance = nil\s*\}', r'selectedDistance = nil', text)
text = re.sub(r'withAnimation\(\.interactiveSpring\(response: 0.2, dampingFraction: 0.8\)\) \{\s*selectedDistance = distance\s*\}', r'selectedDistance = distance', text)

with open("Ascent/ElevationProfileView.swift", "w") as f:
    f.write(text)
