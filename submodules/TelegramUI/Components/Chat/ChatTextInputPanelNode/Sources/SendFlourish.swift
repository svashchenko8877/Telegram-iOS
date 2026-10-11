import Foundation
import UIKit

/// A small celebration when a message is sent: the send button squashes and pops, a ripple
/// ring expands from it, and a fan of dots shoots up and away, in the direction the message
/// travels. Pure Core Animation, removes itself, and does nothing under Reduce Motion.
enum SendFlourish {
    static func play(in container: UIView, from button: UIView, tint: UIColor) {
        if UIAccessibility.isReduceMotionEnabled {
            return
        }

        // The button itself.
        let pop = CAKeyframeAnimation(keyPath: "transform.scale")
        pop.values = [1.0, 0.76, 1.2, 1.0]
        pop.keyTimes = [0.0, 0.25, 0.62, 1.0]
        pop.duration = 0.46
        pop.timingFunctions = [
            CAMediaTimingFunction(name: .easeIn),
            CAMediaTimingFunction(name: .easeOut),
            CAMediaTimingFunction(name: .easeInEaseOut)
        ]
        button.layer.add(pop, forKey: "sendPop")

        let center = button.convert(CGPoint(x: button.bounds.midX, y: button.bounds.midY), to: container)

        let overlay = UIView(frame: container.bounds)
        overlay.isUserInteractionEnabled = false
        container.addSubview(overlay)

        // Ripple ring.
        let ring = CAShapeLayer()
        ring.path = UIBezierPath(ovalIn: CGRect(x: -12.0, y: -12.0, width: 24.0, height: 24.0)).cgPath
        ring.position = center
        ring.fillColor = nil
        ring.strokeColor = tint.withAlphaComponent(0.8).cgColor
        ring.lineWidth = 2.0
        ring.opacity = 0.0
        overlay.layer.addSublayer(ring)

        let ringScale = CABasicAnimation(keyPath: "transform.scale")
        ringScale.fromValue = 0.6
        ringScale.toValue = 3.2
        let ringFade = CAKeyframeAnimation(keyPath: "opacity")
        ringFade.values = [0.0, 0.85, 0.0]
        ringFade.keyTimes = [0.0, 0.18, 1.0]
        let ringGroup = CAAnimationGroup()
        ringGroup.animations = [ringScale, ringFade]
        ringGroup.duration = 0.55
        ringGroup.timingFunction = CAMediaTimingFunction(name: .easeOut)
        ringGroup.fillMode = .forwards
        ringGroup.isRemovedOnCompletion = false
        ring.add(ringGroup, forKey: "ring")

        // A fan of dots, up and slightly to the left (the message flies into the chat).
        let dotCount = 9
        for index in 0 ..< dotCount {
            let fraction = CGFloat(index) / CGFloat(dotCount - 1)
            let angle = -CGFloat.pi * (0.95 - 0.7 * fraction)
            let distance: CGFloat = 46.0 + CGFloat((index * 5) % 4) * 11.0
            let size: CGFloat = index % 2 == 0 ? 6.0 : 4.0

            let dot = CALayer()
            dot.bounds = CGRect(origin: CGPoint(), size: CGSize(width: size, height: size))
            dot.cornerRadius = size / 2.0
            dot.backgroundColor = (index % 3 == 0 ? UIColor.white : tint).cgColor
            dot.position = center
            dot.opacity = 0.0
            overlay.layer.addSublayer(dot)

            let move = CABasicAnimation(keyPath: "position")
            move.fromValue = NSValue(cgPoint: center)
            move.toValue = NSValue(cgPoint: CGPoint(x: center.x + cos(angle) * distance, y: center.y + sin(angle) * distance))
            move.timingFunction = CAMediaTimingFunction(controlPoints: 0.1, 0.8, 0.25, 1.0)

            let fade = CAKeyframeAnimation(keyPath: "opacity")
            fade.values = [0.0, 1.0, 1.0, 0.0]
            fade.keyTimes = [0.0, 0.1, 0.5, 1.0]

            let shrink = CABasicAnimation(keyPath: "transform.scale")
            shrink.fromValue = 1.1
            shrink.toValue = 0.3

            let group = CAAnimationGroup()
            group.animations = [move, fade, shrink]
            group.duration = 0.6
            group.fillMode = .forwards
            group.isRemovedOnCompletion = false
            dot.add(group, forKey: "dot")
        }

        // Confetti: small coloured pieces that tumble up and to the left.
        let confettiColors: [UIColor] = [tint, UIColor.white, UIColor(rgb: 0xffd36b), UIColor(rgb: 0xff7eb6), UIColor(rgb: 0x7be0a8)]
        for index in 0 ..< 14 {
            let fraction = CGFloat(index) / 13.0
            let angle = -CGFloat.pi * (0.98 - 0.62 * fraction)
            let distance: CGFloat = 70.0 + CGFloat((index * 7) % 5) * 16.0
            let piece = CALayer()
            let width: CGFloat = 5.0 + CGFloat(index % 3) * 2.0
            piece.bounds = CGRect(origin: CGPoint(), size: CGSize(width: width, height: width * 0.55))
            piece.cornerRadius = 1.0
            piece.backgroundColor = confettiColors[index % confettiColors.count].cgColor
            piece.position = center
            piece.opacity = 0.0
            overlay.layer.addSublayer(piece)
            
            let target = CGPoint(x: center.x + cos(angle) * distance, y: center.y + sin(angle) * distance + 26.0)
            let move = CAKeyframeAnimation(keyPath: "position")
            let path = UIBezierPath()
            path.move(to: center)
            path.addQuadCurve(to: target, controlPoint: CGPoint(x: center.x + cos(angle) * distance * 0.7, y: center.y + sin(angle) * distance * 1.25))
            move.path = path.cgPath
            move.timingFunction = CAMediaTimingFunction(controlPoints: 0.15, 0.7, 0.3, 1.0)
            
            let spin = CABasicAnimation(keyPath: "transform.rotation.z")
            spin.fromValue = 0.0
            spin.toValue = (index % 2 == 0 ? 1.0 : -1.0) * CGFloat.pi * (2.0 + CGFloat(index % 3))
            
            let fade = CAKeyframeAnimation(keyPath: "opacity")
            fade.values = [0.0, 1.0, 1.0, 0.0]
            fade.keyTimes = [0.0, 0.08, 0.7, 1.0]
            
            let group = CAAnimationGroup()
            group.animations = [move, spin, fade]
            group.duration = 0.95
            group.beginTime = piece.convertTime(CACurrentMediaTime(), from: nil) + Double(index % 4) * 0.02
            group.fillMode = .both
            group.isRemovedOnCompletion = false
            piece.add(group, forKey: "confetti")
        }
        
        // A paper plane takes off along an arc and shrinks into the distance.
        let plane = CAShapeLayer()
        let planePath = UIBezierPath()
        planePath.move(to: CGPoint(x: 0.0, y: 0.0))
        planePath.addLine(to: CGPoint(x: 24.0, y: 10.0))
        planePath.addLine(to: CGPoint(x: 0.0, y: 20.0))
        planePath.addLine(to: CGPoint(x: 6.0, y: 10.0))
        planePath.close()
        plane.path = planePath.cgPath
        plane.bounds = CGRect(x: 0.0, y: 0.0, width: 24.0, height: 20.0)
        plane.fillColor = UIColor.white.cgColor
        plane.shadowColor = tint.cgColor
        plane.shadowOpacity = 0.9
        plane.shadowRadius = 6.0
        plane.shadowOffset = CGSize()
        plane.position = center
        plane.opacity = 0.0
        overlay.layer.addSublayer(plane)
        
        let flight = UIBezierPath()
        flight.move(to: center)
        flight.addCurve(to: CGPoint(x: center.x - 150.0, y: center.y - 190.0), controlPoint1: CGPoint(x: center.x + 40.0, y: center.y - 70.0), controlPoint2: CGPoint(x: center.x - 60.0, y: center.y - 200.0))
        let fly = CAKeyframeAnimation(keyPath: "position")
        fly.path = flight.cgPath
        fly.calculationMode = .paced
        fly.rotationMode = .rotateAuto
        fly.timingFunction = CAMediaTimingFunction(controlPoints: 0.3, 0.1, 0.6, 1.0)
        let planeScale = CABasicAnimation(keyPath: "transform.scale")
        planeScale.fromValue = 1.1
        planeScale.toValue = 0.35
        let planeFade = CAKeyframeAnimation(keyPath: "opacity")
        planeFade.values = [0.0, 1.0, 1.0, 0.0]
        planeFade.keyTimes = [0.0, 0.08, 0.75, 1.0]
        let planeGroup = CAAnimationGroup()
        planeGroup.animations = [fly, planeScale, planeFade]
        planeGroup.duration = 0.9
        planeGroup.fillMode = .both
        planeGroup.isRemovedOnCompletion = false
        plane.add(planeGroup, forKey: "plane")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { [weak overlay] in
            overlay?.removeFromSuperview()
        }
    }
    
    /// Voice message sent: the mic button pops, two ripples leave it, and a little waveform
    /// rises from it, each bar growing in turn and then drifting up and fading, as if the
    /// recording were lifting off into the chat.
    static func playVoice(in container: UIView, from button: UIView, tint: UIColor) {
        if UIAccessibility.isReduceMotionEnabled {
            return
        }
        
        let pop = CAKeyframeAnimation(keyPath: "transform.scale")
        pop.values = [1.0, 0.7, 1.25, 1.0]
        pop.keyTimes = [0.0, 0.22, 0.6, 1.0]
        pop.duration = 0.5
        pop.timingFunctions = [
            CAMediaTimingFunction(name: .easeIn),
            CAMediaTimingFunction(name: .easeOut),
            CAMediaTimingFunction(name: .easeInEaseOut)
        ]
        button.layer.add(pop, forKey: "voicePop")
        
        let center = button.convert(CGPoint(x: button.bounds.midX, y: button.bounds.midY), to: container)
        
        let overlay = UIView(frame: container.bounds)
        overlay.isUserInteractionEnabled = false
        container.addSubview(overlay)
        
        // Two ripples, one after the other.
        for ringIndex in 0 ..< 2 {
            let ring = CAShapeLayer()
            ring.path = UIBezierPath(ovalIn: CGRect(x: -14.0, y: -14.0, width: 28.0, height: 28.0)).cgPath
            ring.position = center
            ring.fillColor = nil
            ring.strokeColor = tint.withAlphaComponent(0.75).cgColor
            ring.lineWidth = 2.0
            ring.opacity = 0.0
            overlay.layer.addSublayer(ring)
            
            let scale = CABasicAnimation(keyPath: "transform.scale")
            scale.fromValue = 0.6
            scale.toValue = 3.6
            let fade = CAKeyframeAnimation(keyPath: "opacity")
            fade.values = [0.0, 0.8, 0.0]
            fade.keyTimes = [0.0, 0.2, 1.0]
            let group = CAAnimationGroup()
            group.animations = [scale, fade]
            group.duration = 0.65
            group.beginTime = ring.convertTime(CACurrentMediaTime(), from: nil) + Double(ringIndex) * 0.16
            group.timingFunction = CAMediaTimingFunction(name: .easeOut)
            group.fillMode = .both
            group.isRemovedOnCompletion = false
            ring.add(group, forKey: "ring")
        }
        
        // The rising waveform.
        let heights: [CGFloat] = [10.0, 18.0, 28.0, 36.0, 26.0, 40.0, 24.0, 32.0, 18.0, 12.0]
        let barWidth: CGFloat = 3.0
        let spacing: CGFloat = 6.0
        let totalWidth = CGFloat(heights.count) * barWidth + CGFloat(heights.count - 1) * spacing
        for (index, height) in heights.enumerated() {
            let x = center.x - totalWidth / 2.0 + CGFloat(index) * (barWidth + spacing) + barWidth / 2.0
            
            let bar = CALayer()
            bar.bounds = CGRect(origin: CGPoint(), size: CGSize(width: barWidth, height: height))
            bar.cornerRadius = barWidth / 2.0
            bar.backgroundColor = (index % 3 == 0 ? UIColor.white : tint).cgColor
            bar.anchorPoint = CGPoint(x: 0.5, y: 1.0)
            bar.position = CGPoint(x: x, y: center.y - 14.0)
            bar.opacity = 0.0
            overlay.layer.addSublayer(bar)
            
            let delay = Double(index) * 0.035
            
            let grow = CAKeyframeAnimation(keyPath: "transform.scale.y")
            grow.values = [0.05, 1.15, 1.0, 0.7]
            grow.keyTimes = [0.0, 0.3, 0.55, 1.0]
            
            let rise = CABasicAnimation(keyPath: "position.y")
            rise.fromValue = bar.position.y
            rise.toValue = bar.position.y - 46.0 - height * 0.4
            rise.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.7, 0.3, 1.0)
            
            let fade = CAKeyframeAnimation(keyPath: "opacity")
            fade.values = [0.0, 1.0, 1.0, 0.0]
            fade.keyTimes = [0.0, 0.12, 0.6, 1.0]
            
            let group = CAAnimationGroup()
            group.animations = [grow, rise, fade]
            group.duration = 0.85
            group.beginTime = bar.convertTime(CACurrentMediaTime(), from: nil) + delay
            group.fillMode = .both
            group.isRemovedOnCompletion = false
            bar.add(group, forKey: "bar")
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak overlay] in
            overlay?.removeFromSuperview()
        }
    }
}

/// When the message field is tapped, a bright line draws itself around its edge and fades,
/// like the field "waking up".
enum FocusGlow {
    static func play(on view: UIView, tint: UIColor) {
        if UIAccessibility.isReduceMotionEnabled || view.bounds.width < 10.0 || view.bounds.height < 10.0 {
            return
        }
        let bounds = view.bounds.insetBy(dx: 0.5, dy: 0.5)
        let glow = CAShapeLayer()
        glow.frame = view.bounds
        glow.path = UIBezierPath(roundedRect: bounds, cornerRadius: bounds.height / 2.0).cgPath
        glow.fillColor = nil
        glow.strokeColor = tint.cgColor
        glow.lineWidth = 2.0
        glow.lineCap = .round
        glow.shadowColor = tint.cgColor
        glow.shadowOpacity = 0.9
        glow.shadowRadius = 6.0
        glow.shadowOffset = CGSize()
        glow.strokeEnd = 1.0
        glow.opacity = 0.0
        view.layer.addSublayer(glow)
        
        let draw = CABasicAnimation(keyPath: "strokeEnd")
        draw.fromValue = 0.0
        draw.toValue = 1.0
        draw.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        let fade = CAKeyframeAnimation(keyPath: "opacity")
        fade.values = [0.0, 1.0, 1.0, 0.0]
        fade.keyTimes = [0.0, 0.1, 0.55, 1.0]
        let group = CAAnimationGroup()
        group.animations = [draw, fade]
        group.duration = 0.8
        group.fillMode = .forwards
        group.isRemovedOnCompletion = false
        glow.add(group, forKey: "focusGlow")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak glow] in
            glow?.removeFromSuperlayer()
        }
    }
}

/// A few tiny sparks float up from the caret with every keystroke.
enum TypingSparks {
    static func play(from input: UIView, in container: UIView, tint: UIColor) {
        if UIAccessibility.isReduceMotionEnabled {
            return
        }
        guard let textInput = input as? UITextInput, let end = textInput.selectedTextRange?.end else {
            return
        }
        let caret = textInput.caretRect(for: end)
        if !caret.height.isFinite || caret.height < 1.0 || caret.height > 120.0 || !caret.minX.isFinite || !caret.midY.isFinite {
            return
        }
        let origin = input.convert(CGPoint(x: caret.maxX, y: caret.midY), to: container)
        
        let colors: [UIColor] = [tint, UIColor.white, UIColor(rgb: 0xffd36b)]
        let offsets: [CGFloat] = [-9.0, 3.0, 13.0]
        for index in 0 ..< 3 {
            let size: CGFloat = index == 1 ? 3.0 : 4.0
            let spark = CALayer()
            spark.bounds = CGRect(origin: CGPoint(), size: CGSize(width: size, height: size))
            spark.cornerRadius = size / 2.0
            spark.backgroundColor = colors[index].cgColor
            spark.position = origin
            spark.opacity = 0.0
            container.layer.addSublayer(spark)
            
            let move = CABasicAnimation(keyPath: "position")
            move.fromValue = NSValue(cgPoint: origin)
            move.toValue = NSValue(cgPoint: CGPoint(x: origin.x + offsets[index], y: origin.y - 20.0 - CGFloat(index) * 7.0))
            move.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.8, 0.3, 1.0)
            let fade = CAKeyframeAnimation(keyPath: "opacity")
            fade.values = [0.0, 1.0, 0.0]
            fade.keyTimes = [0.0, 0.2, 1.0]
            let shrink = CABasicAnimation(keyPath: "transform.scale")
            shrink.fromValue = 1.2
            shrink.toValue = 0.3
            let group = CAAnimationGroup()
            group.animations = [move, fade, shrink]
            group.duration = 0.5
            group.fillMode = .forwards
            group.isRemovedOnCompletion = false
            spark.add(group, forKey: "spark")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak spark] in
                spark?.removeFromSuperlayer()
            }
        }
    }
}
