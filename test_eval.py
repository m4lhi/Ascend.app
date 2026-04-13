import re
with open("Ascent/ElevationProfileView.swift", "r") as f:
    text = f.read()

# Let's ensure the `withAnimation` in ElevationProfileView.swift was genuinely removed.
# I had a script but maybe it didn't find the exact match string.
m1 = "withAnimation(.interactiveSpring(response: 0.2, dampingFraction: 0.8))"
m2 = "withAnimation(.spring())"
if m1 in text or m2 in text:
    print("Found! Needs regex replace again.")
else:
    print("Clean")
