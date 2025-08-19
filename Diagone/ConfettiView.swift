import SwiftUI
import UIKit

/// A simple confetti burst implemented using `CAEmitterLayer`. When the view
/// appears it emits coloured rectangles that fall and fade out. The effect
/// automatically stops after a short duration. Use this view as an overlay
/// triggered on puzzle completion.
struct ConfettiView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // Remove any existing emitters before creating a new one
        uiView.layer.sublayers?.forEach { layer in
            if layer.name == "confettiEmitter" {
                layer.removeFromSuperlayer()
            }
        }
        // Create emitter layer
        let emitter = CAEmitterLayer()
        emitter.name = "confettiEmitter"
        emitter.emitterShape = .line
        emitter.emitterPosition = CGPoint(x: uiView.bounds.midX, y: -10)
        emitter.emitterSize = CGSize(width: uiView.bounds.size.width, height: 2)
        emitter.birthRate = 0
        // Configure confetti cells
        let colors: [UIColor] = [
            UIColor(red: 0.99, green: 0.77, blue: 0.27, alpha: 1.0), // warm yellow
            UIColor(red: 0.12, green: 0.35, blue: 0.65, alpha: 1.0), // NYT blue
            UIColor(red: 0.95, green: 0.27, blue: 0.29, alpha: 1.0), // red
            UIColor(red: 0.48, green: 0.78, blue: 0.64, alpha: 1.0)  // green
        ]
        var cells: [CAEmitterCell] = []
        for color in colors {
            let cell = CAEmitterCell()
            cell.birthRate = 6
            cell.lifetime = 3.0
            cell.lifetimeRange = 0.0
            cell.velocity = 120
            cell.velocityRange = 40
            cell.emissionLongitude = .pi
            cell.emissionRange = .pi / 4
            cell.spin = 3.5
            cell.spinRange = 1.0
            cell.scale = 0.6
            cell.scaleRange = 0.3
            cell.color = color.cgColor
            // Create a small rectangle image for confetti
            let size: CGFloat = 8.0
            UIGraphicsBeginImageContext(CGSize(width: size, height: size))
            let context = UIGraphicsGetCurrentContext()!
            context.setFillColor(color.cgColor)
            context.fill(CGRect(x: 0, y: 0, width: size, height: size))
            let image = UIGraphicsGetImageFromCurrentImageContext()!
            UIGraphicsEndImageContext()
            cell.contents = image.cgImage
            cells.append(cell)
        }
        emitter.emitterCells = cells
        uiView.layer.addSublayer(emitter)
        // Trigger emission once; we ramp up and down the birth rate to create a burst
        DispatchQueue.main.asyncAfter(deadline: .now()) {
            emitter.birthRate = 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                emitter.birthRate = 0
            }
        }
    }
}