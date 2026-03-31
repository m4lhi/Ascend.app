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

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = makeScene()
        
        // Erlaubt das Drehen mit dem Finger!
        scnView.allowsCameraControl = true 
        scnView.backgroundColor = UIColor.clear
        scnView.autoenablesDefaultLighting = true
        
        if let scene = scnView.scene {
            // Umgebungslicht
            let ambientLight = SCNLight()
            ambientLight.type = .ambient
            ambientLight.intensity = 200
            let ambientNode = SCNNode()
            ambientNode.light = ambientLight
            scene.rootNode.addChildNode(ambientNode)
            
            // Spotlicht für die Glanzkanten
            let spotLight = SCNLight()
            spotLight.type = .spot
            spotLight.intensity = 1500
            spotLight.castsShadow = true
            let spotNode = SCNNode()
            spotNode.light = spotLight
            spotNode.position = SCNVector3(x: 4, y: 5, z: 8)
            spotNode.look(at: SCNVector3(0, 0, 0))
            scene.rootNode.addChildNode(spotNode)
        }
        
        return scnView
    }

    func updateUIView(_ scnView: SCNView, context: Context) {}

    private func makeScene() -> SCNScene {
        let scene = SCNScene()

        let coinRadius: CGFloat = 3.0
        let coinHeight: CGFloat = 0.5
        
        // 1. Die Münze (Zylinder)
        let coinGeometry = SCNCylinder(radius: coinRadius, height: coinHeight)
        
        let mainMat = SCNMaterial()
        mainMat.lightingModel = .physicallyBased
        mainMat.metalness.contents = 1.0
        mainMat.roughness.contents = 0.25
        
        let uiColor = UIColor(badgeColor)
        
        if isUnlocked {
            mainMat.diffuse.contents = uiColor
        } else {
            mainMat.diffuse.contents = UIColor.darkGray
            mainMat.metalness.contents = 0.6
            mainMat.roughness.contents = 0.6
        }
        
        coinGeometry.materials = [mainMat, mainMat, mainMat]
        
        let coinNode = SCNNode(geometry: coinGeometry)
        // Zylinder steht aufrecht, sodass wir auf die flache Seite schauen
        coinNode.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
        
        // 2. Das Icon (als Plane auf der Münze, Vorder- und Rückseite)
        if let iconImage = createSymbolImage(name: iconName, color: .white) {
            let iconRadius: CGFloat = 3.2
            
            // Vorderseite
            let frontPlane = SCNPlane(width: iconRadius, height: iconRadius)
            let frontMat = SCNMaterial()
            frontMat.diffuse.contents = iconImage
            frontMat.isDoubleSided = false
            if isUnlocked {
                frontMat.emission.contents = uiColor
            }
            frontPlane.materials = [frontMat]
            
            let frontNode = SCNNode(geometry: frontPlane)
            frontNode.position = SCNVector3(0, coinHeight / 2.0 + 0.02, 0)
            frontNode.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
            coinNode.addChildNode(frontNode)
            
            // Rückseite (Spiegelverkehrt)
            let backPlane = SCNPlane(width: iconRadius, height: iconRadius)
            let backMat = SCNMaterial()
            backMat.diffuse.contents = iconImage
            backMat.isDoubleSided = false
            if isUnlocked {
                backMat.emission.contents = uiColor
            }
            backPlane.materials = [backMat]
            
            let backNode = SCNNode(geometry: backPlane)
            backNode.position = SCNVector3(0, -coinHeight / 2.0 - 0.02, 0)
            // Um 180 Grad gedreht für die Rückseite
            backNode.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
            coinNode.addChildNode(backNode)
        }
        
        // 3. Der Premium-Rand
        let rimGeom = SCNTube(innerRadius: coinRadius - 0.2, outerRadius: coinRadius, height: coinHeight + 0.1)
        let rimMat = SCNMaterial()
        rimMat.lightingModel = .physicallyBased
        rimMat.metalness.contents = 1.0
        rimMat.roughness.contents = 0.1
        rimMat.diffuse.contents = isUnlocked ? uiColor : UIColor.darkGray
        rimGeom.materials = [rimMat]
        
        let rimNode = SCNNode(geometry: rimGeom)
        coinNode.addChildNode(rimNode)

        // Wrapper Node für die Rotation
        let spinNode = SCNNode()
        spinNode.addChildNode(coinNode)
        
        // 4. Langsame, endlose Drehung
        let spin = CABasicAnimation(keyPath: "eulerAngles.y")
        spin.byValue = NSNumber(value: Float.pi * 2)
        spin.duration = 15.0
        spin.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
        spin.repeatCount = .infinity
        spinNode.addAnimation(spin, forKey: "spin")
        
        scene.rootNode.addChildNode(spinNode)
        
        // Kamera
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        if let camera = cameraNode.camera {
            camera.zNear = 0.1
        }
        cameraNode.position = SCNVector3(0, 0, 9.5)
        scene.rootNode.addChildNode(cameraNode)
        
        return scene
    }
    
    // SF Symbol als hochauflösendes Bild rendern
    private func createSymbolImage(name: String, color: UIColor) -> UIImage? {
        let config = UIImage.SymbolConfiguration(pointSize: 500, weight: .bold)
        if let image = UIImage(systemName: name, withConfiguration: config) {
            return image.withTintColor(color, renderingMode: .alwaysOriginal)
        }
        return nil
    }
}
