import Foundation
import UIKit
import Display
import ComponentFlow
import ComponentDisplayAdapters

/// A slow, living colour wash for the profile header.
///
/// Three soft radial blobs, tinted from the profile's own two cover colours, drift and
/// breathe on slightly different cycles so the mix never repeats exactly. It is pure Core
/// Animation (no per-frame work), is skipped entirely under Reduce Motion, and sits behind
/// the avatar and pattern so it only adds depth to the existing gradient.
final class PeerInfoAuroraBackdrop: SimpleLayer {
    private struct Blob {
        /// Blob centre as a fraction of the cover size.
        let center: CGPoint
        /// Diameter as a fraction of the cover width.
        let diameter: CGFloat
        /// Hue offset applied to the cover colour, in turns (0.0 ... 1.0).
        let hueShift: CGFloat
        let brightness: CGFloat
        let alpha: Float
        let drift: CGSize
        let period: Double
    }

    private static let blobs: [Blob] = [
        Blob(center: CGPoint(x: 0.50, y: 0.42), diameter: 1.35, hueShift: 0.00, brightness: 1.18, alpha: 0.55, drift: CGSize(width: 0.10, height: 0.05), period: 17.0),
        Blob(center: CGPoint(x: 0.12, y: 0.12), diameter: 1.00, hueShift: 0.07, brightness: 1.10, alpha: 0.50, drift: CGSize(width: 0.14, height: 0.10), period: 23.0),
        Blob(center: CGPoint(x: 0.92, y: 0.78), diameter: 1.10, hueShift: -0.06, brightness: 1.25, alpha: 0.45, drift: CGSize(width: 0.12, height: 0.12), period: 29.0)
    ]

    private let blobLayers: [SimpleGradientLayer]
    private var animationsInstalled = false
    private var currentColors: (UIColor, UIColor)?

    override init() {
        self.blobLayers = PeerInfoAuroraBackdrop.blobs.map { _ in
            let layer = SimpleGradientLayer()
            layer.type = .radial
            layer.startPoint = CGPoint(x: 0.5, y: 0.5)
            layer.endPoint = CGPoint(x: 1.0, y: 1.0)
            return layer
        }

        super.init()

        self.masksToBounds = true
        for layer in self.blobLayers {
            self.addSublayer(layer)
        }
    }

    override init(layer: Any) {
        self.blobLayers = []
        super.init(layer: layer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private static func shifted(_ color: UIColor, hueShift: CGFloat, brightness: CGFloat) -> UIColor {
        var hue: CGFloat = 0.0
        var saturation: CGFloat = 0.0
        var value: CGFloat = 0.0
        var alpha: CGFloat = 0.0
        if color.getHue(&hue, saturation: &saturation, brightness: &value, alpha: &alpha) {
            var shiftedHue = hue + hueShift
            shiftedHue -= floor(shiftedHue)
            return UIColor(hue: shiftedHue, saturation: min(1.0, saturation * 0.95), brightness: min(1.0, value * brightness), alpha: 1.0)
        } else {
            return color
        }
    }

    /// - Parameters:
    ///   - colors: the profile's main and secondary cover colours, or nil to hide the backdrop.
    ///   - size: the visible cover size.
    func update(colors: (UIColor, UIColor)?, size: CGSize, transition: ComponentTransition) {
        guard let colors = colors, size.width > 1.0, size.height > 1.0 else {
            self.isHidden = true
            return
        }
        self.isHidden = false

        let colorsChanged: Bool
        if let current = self.currentColors {
            colorsChanged = current.0 != colors.0 || current.1 != colors.1
        } else {
            colorsChanged = true
        }
        self.currentColors = colors

        transition.setFrame(layer: self, frame: CGRect(origin: CGPoint(), size: size))

        for (index, blob) in PeerInfoAuroraBackdrop.blobs.enumerated() {
            let layer = self.blobLayers[index]
            // Alternate which cover colour each blob is drawn from, so both show up.
            let base = index % 2 == 0 ? colors.0 : colors.1
            let tint = PeerInfoAuroraBackdrop.shifted(base, hueShift: blob.hueShift, brightness: blob.brightness)

            if colorsChanged {
                layer.colors = [
                    tint.withAlphaComponent(1.0).cgColor,
                    tint.withAlphaComponent(0.55).cgColor,
                    tint.withAlphaComponent(0.0).cgColor
                ]
                layer.locations = [0.0, 0.45, 1.0]
            }
            layer.opacity = blob.alpha

            let diameter = size.width * blob.diameter
            let frame = CGRect(
                x: size.width * blob.center.x - diameter / 2.0,
                y: size.height * blob.center.y - diameter / 2.0,
                width: diameter,
                height: diameter
            )
            transition.setFrame(layer: layer, frame: frame)
        }

        self.updateAnimations(size: size)
    }

    private func updateAnimations(size: CGSize) {
        if UIAccessibility.isReduceMotionEnabled {
            if self.animationsInstalled {
                for layer in self.blobLayers {
                    layer.removeAllAnimations()
                }
                self.animationsInstalled = false
            }
            return
        }
        if self.animationsInstalled {
            return
        }
        self.animationsInstalled = true

        for (index, blob) in PeerInfoAuroraBackdrop.blobs.enumerated() {
            let layer = self.blobLayers[index]
            // Transform-based, so later frame updates (position/bounds) never fight the animation.
            let driftX = CABasicAnimation(keyPath: "transform.translation.x")
            driftX.fromValue = -size.width * blob.drift.width
            driftX.toValue = size.width * blob.drift.width
            driftX.duration = blob.period

            let driftY = CABasicAnimation(keyPath: "transform.translation.y")
            driftY.fromValue = size.width * blob.drift.height
            driftY.toValue = -size.width * blob.drift.height
            driftY.duration = blob.period * 0.83

            let breathe = CABasicAnimation(keyPath: "transform.scale")
            breathe.fromValue = 0.92
            breathe.toValue = 1.14
            breathe.duration = blob.period * 0.61

            for animation in [driftX, driftY, breathe] {
                animation.autoreverses = true
                animation.repeatCount = .infinity
                animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                // Start each cycle at a different phase so the blobs never line up.
                animation.timeOffset = blob.period * Double(index) * 0.37
                animation.isRemovedOnCompletion = false
            }
            layer.add(driftX, forKey: "auroraDriftX")
            layer.add(driftY, forKey: "auroraDriftY")
            layer.add(breathe, forKey: "auroraBreathe")
        }
    }
}
