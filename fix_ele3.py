with open("Ascent/ElevationProfileView.swift", "r") as f:
    text = f.read()

# Let's just find the exact block and replace
import re
text = re.sub(r'withAnimation\([^)]*\)\s*\{\s*(selectedDistance\s*=[^}]*)\}', r'\1', text)

with open("Ascent/ElevationProfileView.swift", "w") as f:
    f.write(text)
