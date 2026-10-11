import Foundation
import UIKit
import Display

/// A short celebratory burst of sparkles that radiates from the spot a reaction was tapped.
///
/// It is drawn with plain Core Animation shapes (no emitter, no per-frame work), removes
/// itself when finished, ignores touches, and does nothing under Reduce Motion.
public final class ReactionBurstView: UIView {
    private static let particleCount = 14
    private static let duration: Double = 0.85

    private init(frame: CGRect, center: CGPoint, colors: [UIColor]) {
        super.init(frame: frame)

        self.isUserInteractionEnabled = false
        self.layer.zPosition = 1000.0

        self.addParticles(center: center, colors: colors)
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Adds a burst centred on `center` (in the coordinate space of `container`).
    public static func play(in container: UIView, center: CGPoint, colors: [UIColor]) {
        if UIAccessibility.isReduceMotionEnabled || colors.isEmpty {
            return
        }
        let view = ReactionBurstView(frame: container.bounds, center: center, colors: colors)
        container.addSubview(view)
        DispatchQueue.main.asyncAfter(deadline: .now() + ReactionBurstView.duration + 0.1) { [weak view] in
            view?.removeFromSuperview()
        }
    }

    private func addParticles(center: CGPoint, colors: [UIColor]) {
        let count = ReactionBurstView.particleCount
        for index in 0 ..< count {
            let fraction = CGFloat(index) / CGFloat(count)
            // Evenly spread angles with a small deterministic jitter, so it looks organic
            // without being random from run to run.
            let jitter = CGFloat((index * 37) % 11) / 11.0 - 0.5
            let angle = fraction * 2.0 * CGFloat.pi + jitter * 0.35
            let distance: CGFloat = 46.0 + CGFloat((index * 53) % 7) * 7.0
            let size: CGFloat = index % 3 == 0 ? 9.0 : 5.5
            let color = colors[index % colors.count]

            let layer = CAShapeLayer()
            layer.bounds = CGRect(origin: CGPoint(), size: CGSize(width: size, height: size))
            layer.position = center
            layer.fillColor = color.cgColor
            layer.path = index % 3 == 0
                ? ReactionBurstView.sparklePath(size: size)
                : UIBezierPath(ovalIn: layer.bounds).cgPath
            layer.opacity = 0.0
            self.layer.addSublayer(layer)

            let target = CGPoint(x: center.x + cos(angle) * distance, y: center.y + sin(angle) * distance)

            let move = CABasicAnimation(keyPath: "position")
            move.fromValue = NSValue(cgPoint: center)
            move.toValue = NSValue(cgPoint: target)
            move.timingFunction = CAMediaTimingFunction(controlPoints: 0.12, 0.8, 0.24, 1.0)

            let scale = CAKeyframeAnimation(keyPath: "transform.scale")
            scale.values = [0.2, 1.15, 0.6]
            scale.keyTimes = [0.0, 0.35, 1.0]

            let fade = CAKeyframeAnimation(keyPath: "opacity")
            fade.values = [0.0, 1.0, 1.0, 0.0]
            fade.keyTimes = [0.0, 0.12, 0.55, 1.0]

            let spin = CABasicAnimation(keyPath: "transform.rotation.z")
            spin.fromValue = 0.0
            spin.toValue = (index % 2 == 0 ? 1.0 : -1.0) * CGFloat.pi * 0.75

            let group = CAAnimationGroup()
            group.animations = [move, scale, fade, spin]
            group.duration = ReactionBurstView.duration
            group.beginTime = layer.convertTime(CACurrentMediaTime(), from: nil) + Double(index % 4) * 0.012
            group.fillMode = .both
            group.isRemovedOnCompletion = false
            layer.add(group, forKey: "burst")
        }
    }

    /// A four-pointed sparkle that fits `size`.
    private static func sparklePath(size: CGFloat) -> CGPath {
        let c = size / 2.0
        let inner = size * 0.14
        let path = UIBezierPath()
        path.move(to: CGPoint(x: c, y: 0.0))
        path.addQuadCurve(to: CGPoint(x: size, y: c), controlPoint: CGPoint(x: c + inner, y: c - inner))
        path.addQuadCurve(to: CGPoint(x: c, y: size), controlPoint: CGPoint(x: c + inner, y: c + inner))
        path.addQuadCurve(to: CGPoint(x: 0.0, y: c), controlPoint: CGPoint(x: c - inner, y: c + inner))
        path.addQuadCurve(to: CGPoint(x: c, y: 0.0), controlPoint: CGPoint(x: c - inner, y: c - inner))
        path.close()
        return path.cgPath
    }
}
