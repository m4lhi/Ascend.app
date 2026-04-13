import re
path = "Ascent/ElevationProfileView.swift"
with open(path, "r") as f:
    text = f.read()

text = re.sub(
    r'withAnimation\(\.interactiveSpring\(response: 0.2, dampingFraction: 0.8\)\) \{\s*(.*?)\s*\}',
    r'\1',
    text
)
text = re.sub(
    r'withAnimation\(\.spring\(\)\) \{\s*(.*?)\s*\}',
    r'\1',
    text
)

with open(path, "w") as f:
    f.write(text)
print("Regex patched")
