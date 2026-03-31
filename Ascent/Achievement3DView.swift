import SwiftUI
import SceneKit

// =========================================
// === DATEI: Achievement3DView.swift ===
// === Interaktive 3D Münze für Badges ===
// =========================================

struct Achievement3DView: UIViewRepresentable {
    let iconName: String
    let badgeColor: Color
    let isUnlocked: Bool

    // Custom Coordinator für seidige, kontrollierte Drehung
    class Coordinator: NSObject {
        var spinNode: SCNNode?
        var lastAngleY: Float = 0.0
        var isDragging = false
        
        // Fügt ein permanentes sanftes Drehen hinzu
        func startIdleRotation() {
            guard let node = spinNode else { return }
            node.removeAllAnimations()
            let spin = CABasicAnimation(keyPath: "eulerAngles.y")
            // Dreht sich von der aktuellen Position weiter
            spin.fromValue = node.eulerAngles.y
            spin.toValue = node.eulerAngles.y + (Float.pi * 2)
            spin.duration = 40.0 // Extrem majestätisch und langsam
            spin.repeatCount = .infinity
            node.addAnimation(spin, forKey: "idleSpin")
        }
        
        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let view = gesture.view, let node = spinNode else { return }
            
            let translation = gesture.translation(in: view)
            // Faktor 0.005: Sehr geringe Empfindlichkeit (Premium-Gefühl)
            let angleDelta = Float(translation.x) * 0.005
            
            switch gesture.state {
            case .began:
                isDragging = true
                node.removeAllAnimations() // Stoppt die Auto-Rotation beim Anfassen
            case .changed:
                node.eulerAngles.y = lastAngleY + angleDelta
            case .ended, .cancelled:
                isDragging = false
                lastAngleY = node.eulerAngles.y
                startIdleRotation() // Setzt Auto-Rotation extrem langsam fort
            default:
                break
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator()
    }

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        
        // 1. PERFORMANCE: Szene wird nur ein einziges Mal berechnet und gecached!
        let scene = makeScene(context: context)
        scnView.scene = scene
        
        // 2. TRANSPARENZ: Zwingt den Hintergrund dazu absolut durchsichtig zu sein
        scnView.backgroundColor = UIColor.clear
        scnView.isOpaque = false 
        
        // 3. EIGENE INTERAKTION: Apple Camera Control ist deaktiviert (weil zu wild)
        scnView.allowsCameraControl = false
        
        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        scnView.addGestureRecognizer(panGesture)
        
        // Startet sofort die langsame Grund-Rotation
        context.coordinator.startIdleRotation()
        
        return scnView
    }

    func updateUIView(_ scnView: SCNView, context: Context) {
        // Bleibt leer -> Keine Lags durch SwiftUI Re-Renders
    }

    private func makeScene(context: Context) -> SCNScene {
        let scene = SCNScene()
        
        // --- LICHTER (Majestätische Berg-Beleuchtung) ---
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.intensity = 600
        let ambientNode = SCNNode()
        ambientNode.light = ambientLight
        scene.rootNode.addChildNode(ambientNode)
        
        let spotLight = SCNLight()
        spotLight.type = .spot
        spotLight.intensity = 3500 // Starker Lichtkegel für die Bergkanten
        spotLight.castsShadow = true
        let spotNode = SCNNode()
        spotNode.light = spotLight
        spotNode.position = SCNVector3(x: 4, y: 10, z: 12)
        spotNode.look(at: SCNVector3(x: 0, y: 0, z: 0))
        scene.rootNode.addChildNode(spotNode)
        
        let rimLight = SCNLight()
        rimLight.type = .spot
        rimLight.intensity = 2000
        let rimLightNode = SCNNode()
        rimLightNode.light = rimLight
        rimLightNode.position = SCNVector3(x: -8, y: -2, z: -10)
        rimLightNode.look(at: SCNVector3(x: 0, y: 0, z: 0))
        scene.rootNode.addChildNode(rimLightNode)

        // --- BERG GEOMETRIE (Stilisierter Ascent-Berg) ---
        let path = UIBezierPath()
        // Wir zeichnen die Shilouette eines massiven, stilisierten Berges
        path.move(to: CGPoint(x: -3.6, y: -2.0))
        path.addLine(to: CGPoint(x: -1.2, y: 0.8))  // Kleinerer Nebengipfel
        path.addLine(to: CGPoint(x: -0.2, y: 0.2))  // Tal
        path.addLine(to: CGPoint(x: 1.8, y: 3.2))   // Großer Hauptgipfel
        path.addLine(to: CGPoint(x: 3.6, y: -2.0))  // Rechte Basis
        path.close()
        
        // Extrudiert den 2D-Pfad zu einem massiven 3D-Berg (Dicke der Medaille)
        let mountainGeom = SCNShape(path: path, extrusionDepth: 0.8)
        mountainGeom.chamferRadius = 0.15 // Diese Abrundung wirft das krasse Licht!
        
        // --- PREMIUM MATERIALIEN ---
        let uiColor = UIColor(badgeColor)
        
        // 1. Die Front- und Rückseite: Dunkles, spiegelndes Onyx-Glas
        let glassMat = SCNMaterial()
        glassMat.lightingModel = .physicallyBased
        glassMat.metalness.contents = 0.95
        glassMat.roughness.contents = 0.1
        glassMat.diffuse.contents = UIColor(white: 0.1, alpha: 1.0)
        if isUnlocked {
            glassMat.emission.contents = uiColor.withAlphaComponent(0.05) // Subtiler Tiefe-Glow
        }
        
        // 2. Die Extrusion-Seiten: Dunkler rauer Stahl
        let sideMat = SCNMaterial()
        sideMat.lightingModel = .physicallyBased
        sideMat.metalness.contents = 0.8
        sideMat.roughness.contents = 0.4
        sideMat.diffuse.contents = UIColor(white: 0.15, alpha: 1.0)
        
        // 3. Die Kanten (Abrundungen): Leuchtender Kategorie-Glow
        let edgeMat = SCNMaterial()
        edgeMat.lightingModel = .physicallyBased
        edgeMat.metalness.contents = 1.0
        edgeMat.roughness.contents = 0.0 // Super glänzend!
        
        if isUnlocked {
            edgeMat.diffuse.contents = uiColor
            edgeMat.emission.contents = uiColor.withAlphaComponent(0.4) // Aktiv leuchtende Kanten
        } else {
            edgeMat.diffuse.contents = UIColor.darkGray
            edgeMat.metalness.contents = 0.7
            edgeMat.roughness.contents = 0.5
        }
        
        // Zuweisung (Reihenfolge bei SCNShape: Front, Back, Sides, EdgeFront, EdgeBack)
        mountainGeom.materials = [glassMat, glassMat, sideMat, edgeMat, edgeMat]
        
        let mountainNode = SCNNode(geometry: mountainGeom)
        // Setzt den Mittelpunkt (Pivot) des Berges in seine Mitte, damit er sich perfekt dreht
        mountainNode.pivot = SCNMatrix4MakeTranslation(0, 0, 0.4)

        // --- ICON (Eingebettet im dunklen Berg-Glas) ---
        if let iconImage = createSymbolImage(name: iconName, color: .white) {
            let iconRadius: CGFloat = 2.4
            
            // Vorderseite
            let frontPlane = SCNPlane(width: iconRadius, height: iconRadius)
            let frontMat = SCNMaterial()
            frontMat.isDoubleSided = false
            frontMat.lightingModel = .physicallyBased
            frontMat.diffuse.contents = iconImage
            frontMat.transparent.contents = iconImage
            
            if isUnlocked {
                frontMat.emission.contents = uiColor
                frontMat.metalness.contents = 1.0
                frontMat.roughness.contents = 0.0
            } else {
                frontMat.diffuse.contents = UIColor(white: 0.8, alpha: 0.5)
            }
            frontPlane.materials = [frontMat]
            
            let frontNode = SCNNode(geometry: frontPlane)
            // Position auf dem Berg positioniert (leicht in der Mitte schwebend)
            frontNode.position = SCNVector3(x: 0.2, y: -0.2, z: 0.42)
            mountainNode.addChildNode(frontNode)
            
            // Rückseite
            let backPlane = SCNPlane(width: iconRadius, height: iconRadius)
            let backMat = SCNMaterial()
            backMat.isDoubleSided = false
            backMat.lightingModel = .physicallyBased
            backMat.diffuse.contents = iconImage
            backMat.transparent.contents = iconImage
            
            if isUnlocked {
                backMat.emission.contents = uiColor
                backMat.metalness.contents = 1.0
                backMat.roughness.contents = 0.0
            } else {
                backMat.diffuse.contents = UIColor(white: 0.8, alpha: 0.5)
            }
            backPlane.materials = [backMat]
            
            let backNode = SCNNode(geometry: backPlane)
            backNode.position = SCNVector3(x: 0.2, y: -0.2, z: -0.42)
            // Damit das Icon auf der Rückseite richtig rum liegt
            backNode.eulerAngles = SCNVector3(0, Float.pi, 0)
            mountainNode.addChildNode(backNode)
        }

        // --- WRAPPER FÜR DIE ZENTRIERTE ROTATION ---
        let spinNode = SCNNode()
        spinNode.addChildNode(mountainNode)
        scene.rootNode.addChildNode(spinNode)
        
        // Übergabe an den Coordinator, der die Drehung managed
        context.coordinator.spinNode = spinNode
        
        // --- KAMERA ---
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        if let camera = cameraNode.camera {
            camera.zNear = 0.1
        }
        // Kamera ist weiter weg, da der Berg eine schöne, massive Form hat
        cameraNode.position = SCNVector3(x: 0, y: 0.5, z: 12)
        scene.rootNode.addChildNode(cameraNode)
        
        return scene
    }
    
    private func createSymbolImage(name: String, color: UIColor) -> UIImage? {
        let config = UIImage.SymbolConfiguration(pointSize: 220, weight: .bold)
        if let image = UIImage(systemName: name, withConfiguration: config) {
            return image.withTintColor(color, renderingMode: .alwaysOriginal)
        }
        return nil
    }
}

