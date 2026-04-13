path = "Ascent/ElevationProfileView.swift"
with open(path, "r") as f:
    text = f.read()

# Fix chartXSelection binding because we changed the property from @State
# to computed so we need to use a custom binding.
old_sel = "        .chartXSelection(value: $selectedDistance)"
new_sel = """        .chartXSelection(value: Binding(
            get: { self.selectedDistance },
            set: { self.selectedDistance = $0 }
        ))"""

if old_sel in text:
    with open(path, "w") as f:
        f.write(text.replace(old_sel, new_sel))
        print("Patched!")
else:
    print("Not found!")
