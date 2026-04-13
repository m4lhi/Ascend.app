path = "Ascent/ElevationProfileView.swift"
with open(path, "r") as f:
    text = f.read()

old = """                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let x = value.location.x - geometry[proxy.plotFrame!].origin.x
                                if let distance: Double = proxy.value(atX: x) {
                                    withAnimation(.interactiveSpring(response: 0.2, dampingFraction: 0.8)) {
                                        selectedDistance = distance
                                    }
                                }
                            }
                            .onEnded { _ in
                                withAnimation(.spring()) { selectedDistance = nil }
                            }"""

new = """                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let x = value.location.x - geometry[proxy.plotFrame!].origin.x
                                if let distance: Double = proxy.value(atX: x) {
                                    selectedDistance = distance
                                }
                            }
                            .onEnded { _ in
                                selectedDistance = nil
                            }"""

if old in text:
    print("Found! Patching...")
    with open(path, "w") as f:
        f.write(text.replace(old, new))
else:
    print("Not found!")
