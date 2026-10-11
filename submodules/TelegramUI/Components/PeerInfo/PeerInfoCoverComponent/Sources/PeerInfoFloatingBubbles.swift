import Foundation
import UIKit
import Display
import ComponentFlow
import ComponentDisplayAdapters

/// Glassy emoji bubbles that orbit the profile avatar and "dance" (wobble and pulse on
/// their own beat), plus a soft halo ring that breathes around the avatar.
///
/// The set of emoji is picked from the peer id, so every profile gets its own little crowd.
/// Everything is Core Animation (no per-frame work). Under Reduce Motion the bubbles are laid
/// out statically and the halo is a still ring.
final class PeerInfoFloatingBubbles: SimpleLayer {
    private static let emojis: [String] = ["✨", "🎧", "💬", "🌙", "🔥", "💜", "🎈", "🌈", "⭐️", "🍀", "🦋", "🎵", "🫧", "🍒", "🪩", "🚀"]
    private static let bubbleCount = 6

    private let container = CALayer()
    private let halo = CAShapeLayer()
    private var bubbles: [CALayer] = []

    private var currentSeed: Int64?
    private var currentRadius: CGFloat = 0.0
    private var currentTint: UIColor?
    private var currentReduceMotion = false

    override init() {
        super.init()

        self.addSublayer(self.container)

        self.halo.fillColor = nil
        self.halo.lineWidth = 2.0
        self.container.addSublayer(self.halo)
    }

    override init(layer: Any) {
        super.init(layer: layer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// - Parameters:
    ///   - center: the avatar centre in this layer's coordinate space.
    ///   - avatarRadius: the avatar's unscaled radius.
    ///   - avatarScale: the avatar's current scale, so the orbit grows and shrinks with it.
    ///   - alpha: overall opacity (fades out as the header collapses).
    func update(center: CGPoint, avatarRadius: CGFloat, avatarScale: CGFloat, tint: UIColor, seed: Int64, alpha: CGFloat, size: CGSize, transition: ComponentTransition) {
        self.frame = CGRect(origin: CGPoint(), size: size)

        self.container.bounds = CGRect(origin: CGPoint(), size: CGSize())
        self.container.position = center
        self.container.transform = CATransform3DMakeScale(avatarScale, avatarScale, 1.0)
        transition.setAlpha(layer: self, alpha: max(0.0, min(1.0, alpha)))

        let reduceMotion = UIAccessibility.isReduceMotionEnabled
        let needsRebuild = self.currentSeed != seed
            || abs(self.currentRadius - avatarRadius) > 0.5
            || self.currentTint != tint
            || self.currentReduceMotion != reduceMotion
        if needsRebuild {
            self.currentSeed = seed
            self.currentRadius = avatarRadius
            self.currentTint = tint
            self.currentReduceMotion = reduceMotion
            self.rebuild(avatarRadius: avatarRadius, tint: tint, seed: seed, reduceMotion: reduceMotion)
        }
    }

    private func rebuild(avatarRadius: CGFloat, tint: UIColor, seed: Int64, reduceMotion: Bool) {
        for bubble in self.bubbles {
            bubble.removeFromSuperlayer()
        }
        self.bubbles = []
        self.halo.removeAllAnimations()

        // Halo: a ring just outside the avatar that breathes.
        let haloRadius = avatarRadius + 7.0
        self.halo.bounds = CGRect(x: -haloRadius, y: -haloRadius, width: haloRadius * 2.0, height: haloRadius * 2.0)
        self.halo.position = CGPoint()
        self.halo.path = UIBezierPath(ovalIn: CGRect(x: -haloRadius, y: -haloRadius, width: haloRadius * 2.0, height: haloRadius * 2.0)).cgPath
        self.halo.strokeColor = tint.withAlphaComponent(0.55).cgColor
        self.halo.opacity = 0.35
        if !reduceMotion {
            let pulse = CABasicAnimation(keyPath: "opacity")
            pulse.fromValue = 0.18
            pulse.toValue = 0.7
            pulse.duration = 1.7
            pulse.autoreverses = true
            pulse.repeatCount = .infinity
            pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.halo.add(pulse, forKey: "haloPulse")

            let grow = CABasicAnimation(keyPath: "transform.scale")
            grow.fromValue = 0.985
            grow.toValue = 1.05
            grow.duration = 1.7
            grow.autoreverses = true
            grow.repeatCount = .infinity
            grow.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.halo.add(grow, forKey: "haloGrow")
        }

        // Deterministic picks from the peer id.
        var state = UInt64(bitPattern: seed) &* 6364136223846793005 &+ 1442695040888963407
        func next() -> Int {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Int((state >> 33) & 0x7fffffff)
        }
        var pool = PeerInfoFloatingBubbles.emojis

        let count = PeerInfoFloatingBubbles.bubbleCount
        let scale = UIScreenScale

        for index in 0 ..< count {
            let emoji = pool.remove(at: next() % pool.count)
            let diameter: CGFloat = 30.0 + CGFloat(index % 3) * 6.0

            let bubble = CALayer()
            bubble.bounds = CGRect(origin: CGPoint(), size: CGSize(width: diameter, height: diameter))
            bubble.cornerRadius = diameter / 2.0
            bubble.backgroundColor = tint.withAlphaComponent(0.2).cgColor
            bubble.borderWidth = 1.0
            bubble.borderColor = UIColor.white.withAlphaComponent(0.4).cgColor
            bubble.shadowColor = tint.cgColor
            bubble.shadowOpacity = 0.45
            bubble.shadowRadius = 6.0
            bubble.shadowOffset = CGSize()

            // A soft highlight in the upper left makes it read as glass.
            let gloss = CAGradientLayer()
            gloss.type = .radial
            gloss.frame = bubble.bounds
            gloss.cornerRadius = diameter / 2.0
            gloss.startPoint = CGPoint(x: 0.3, y: 0.25)
            gloss.endPoint = CGPoint(x: 1.0, y: 1.0)
            gloss.colors = [UIColor.white.withAlphaComponent(0.42).cgColor, UIColor.white.withAlphaComponent(0.02).cgColor]
            bubble.addSublayer(gloss)

            let text = CATextLayer()
            text.string = emoji
            text.fontSize = diameter * 0.52
            text.alignmentMode = .center
            text.contentsScale = scale
            text.frame = CGRect(x: 0.0, y: (diameter - diameter * 0.66) / 2.0, width: diameter, height: diameter * 0.66)
            bubble.addSublayer(text)

            // Each bubble gets its own ellipse around the avatar.
            let phase = CGFloat(index) / CGFloat(count)
            let radiusX = avatarRadius + 32.0 + CGFloat(index % 3) * 11.0
            let radiusY = (avatarRadius + 24.0 + CGFloat((index + 1) % 2) * 14.0) * 0.92

            let angle = phase * 2.0 * CGFloat.pi
            bubble.position = CGPoint(x: cos(angle) * radiusX, y: sin(angle) * radiusY)
            self.container.addSublayer(bubble)
            self.bubbles.append(bubble)

            if reduceMotion {
                continue
            }

            let orbitDuration = 17.0 + Double(index) * 3.9
            let orbit = CAKeyframeAnimation(keyPath: "position")
            orbit.path = UIBezierPath(ovalIn: CGRect(x: -radiusX, y: -radiusY, width: radiusX * 2.0, height: radiusY * 2.0)).cgPath
            orbit.calculationMode = .paced
            orbit.duration = orbitDuration
            orbit.repeatCount = .infinity
            orbit.timeOffset = orbitDuration * Double(phase)
            if index % 2 == 1 {
                orbit.speed = -1.0
            }
            bubble.add(orbit, forKey: "orbit")

            // The "dance": a wobble and a pulse on separate beats.
            let wobble = CABasicAnimation(keyPath: "transform.rotation.z")
            wobble.fromValue = -0.3
            wobble.toValue = 0.3
            wobble.duration = 0.9 + Double(index) * 0.17
            wobble.autoreverses = true
            wobble.repeatCount = .infinity
            wobble.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            bubble.add(wobble, forKey: "wobble")

            let beat = CABasicAnimation(keyPath: "transform.scale")
            beat.fromValue = 0.9
            beat.toValue = 1.12
            beat.duration = 0.75 + Double(index) * 0.13
            beat.autoreverses = true
            beat.repeatCount = .infinity
            beat.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            bubble.add(beat, forKey: "beat")
        }
    }
}
