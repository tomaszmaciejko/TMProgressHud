// SPDX-License-Identifier: MIT
// Portions Copyright 2009-2020 Matej Bukovinski.
// Swift port Copyright 2026 Tomasz Maciejko and TMProgressHud contributors.
// Reference: 4a7c5f3e53cdea77c5dcb8578c2ee5acacdf6781. See THIRD_PARTY_NOTICES.md.
import UIKit

/// A rounded horizontal progress bar.
@MainActor
@objc(TMBarProgressView)
open class TMBarProgressView: UIView {
    private enum Geometry {
        static let defaultSize = CGSize(width: 120, height: 20)
        static let intrinsicSize = CGSize(width: 120, height: 10)
        static let border: CGFloat = 2
        static let inset: CGFloat = 4
    }

    /// The unnormalized progress value.
    ///
    /// A change requests redraw.
    @objc open dynamic var progress: Float = 0 {
        didSet {
            if oldValue != progress { setNeedsDisplay() }
        }
    }

    /// The border color, initially white.
    ///
    /// Changing the color requests redraw.
    @objc open dynamic var lineColor: UIColor {
        get { storedLineColor }
        set {
            let needsRedraw = storedLineColor != newValue
            storedLineColor = newValue
            if needsRedraw { setNeedsDisplay() }
        }
    }

    private var storedLineColor: UIColor = .white

    /// The remaining-area color, initially clear.
    @objc open dynamic var progressRemainingColor: UIColor {
        get { storedProgressRemainingColor }
        set {
            guard storedProgressRemainingColor != newValue else { return }
            storedProgressRemainingColor = newValue
            setNeedsDisplay()
        }
    }

    private var storedProgressRemainingColor: UIColor = .clear

    /// The filled-area color, initially white.
    @objc open dynamic var progressColor: UIColor {
        get { storedProgressColor }
        set {
            guard storedProgressColor != newValue else { return }
            storedProgressColor = newValue
            setNeedsDisplay()
        }
    }

    private var storedProgressColor: UIColor = .white

    /// Creates a 120-by-20-point default frame.
    public convenience init() {
        self.init(frame: CGRect(origin: .zero, size: Geometry.defaultSize))
    }

    /// Creates a transparent progress bar.
    public override init(frame: CGRect) {
        super.init(frame: frame)
        configureDrawing()
    }

    /// Decodes a progress bar with initialized Swift color defaults.
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureDrawing()
    }

    private func configureDrawing() {
        backgroundColor = .clear
        isOpaque = false
        registerForTraitChanges(UITraitCollection.systemTraitsAffectingColorAppearance) {
            (view: TMBarProgressView, _) in
            view.setNeedsDisplay()
        }
    }

    /// The 120-by-10-point intrinsic content size.
    open override var intrinsicContentSize: CGSize { Geometry.intrinsicSize }

    /// Draws the border and current progress fill.
    open override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.saveGState()
        defer { context.restoreGState() }
        context.translateBy(x: bounds.minX, y: bounds.minY)
        drawBar(in: CGRect(origin: .zero, size: bounds.size), context: context)
    }

    private func drawBar(in rect: CGRect, context: CGContext) {
        let border = Geometry.border
        let inset = Geometry.inset
        let borderRadius = rect.height / 2 - border
        context.setLineWidth(border)
        context.setStrokeColor(lineColor.cgColor)
        context.setFillColor(progressRemainingColor.cgColor)
        outline(in: rect, inset: border, radius: borderRadius, context: context)
        context.drawPath(using: .fillStroke)
        context.setFillColor(progressColor.cgColor)
        let radius = borderRadius - border
        let amount = CGFloat(progress) * rect.width
        if amount >= radius + inset && amount <= rect.width - radius - inset {
            drawMiddle(amount: amount, radius: radius, rect: rect, context: context)
        } else if amount > radius + inset {
            drawRight(amount: amount, radius: radius, rect: rect, context: context)
        } else if amount < radius + inset && amount > 0 {
            drawLeft(radius: radius, rect: rect, context: context)
        }
    }

    private func outline(in rect: CGRect, inset: CGFloat, radius: CGFloat, context: CGContext) {
        context.move(to: CGPoint(x: inset, y: rect.height / 2))
        context.addArc(
            tangent1End: CGPoint(x: inset, y: inset), tangent2End: CGPoint(x: radius + inset, y: inset), radius: radius)
        context.addArc(
            tangent1End: CGPoint(x: rect.width - inset, y: inset),
            tangent2End: CGPoint(x: rect.width - inset, y: rect.height / 2), radius: radius)
        context.addArc(
            tangent1End: CGPoint(x: rect.width - inset, y: rect.height - inset),
            tangent2End: CGPoint(x: rect.width - radius - inset, y: rect.height - inset), radius: radius)
        context.addArc(
            tangent1End: CGPoint(x: inset, y: rect.height - inset), tangent2End: CGPoint(x: inset, y: rect.height / 2),
            radius: radius)
    }

    private func startHalf(top: Bool, radius: CGFloat, rect: CGRect, context: CGContext) {
        let inset = Geometry.inset
        let y = top ? inset : rect.height - inset
        context.move(to: CGPoint(x: inset, y: rect.height / 2))
        context.addArc(
            tangent1End: CGPoint(x: inset, y: y), tangent2End: CGPoint(x: radius + inset, y: y), radius: radius)
    }

    private func drawMiddle(amount: CGFloat, radius: CGFloat, rect: CGRect, context: CGContext) {
        for top in [true, false] {
            startHalf(top: top, radius: radius, rect: rect, context: context)
            context.addLine(to: CGPoint(x: amount, y: top ? Geometry.inset : rect.height - Geometry.inset))
            context.addLine(to: CGPoint(x: amount, y: radius + Geometry.inset))
        }
        context.fillPath()
    }

    private func drawRight(amount: CGFloat, radius: CGFloat, rect: CGRect, context: CGContext) {
        let centerX = rect.width - radius - Geometry.inset
        let rawAngle = acos((amount - centerX) / radius)
        let angle = rawAngle.isNaN ? 0 : rawAngle
        for top in [true, false] {
            startHalf(top: top, radius: radius, rect: rect, context: context)
            context.addLine(to: CGPoint(x: centerX, y: top ? Geometry.inset : rect.height - Geometry.inset))
            context.addArc(
                center: CGPoint(x: centerX, y: rect.height / 2), radius: radius,
                startAngle: top ? .pi : -.pi, endAngle: top ? -angle : angle, clockwise: !top)
            context.addLine(to: CGPoint(x: amount, y: rect.height / 2))
        }
        context.fillPath()
    }

    private func drawLeft(radius: CGFloat, rect: CGRect, context: CGContext) {
        for top in [true, false] {
            startHalf(top: top, radius: radius, rect: rect, context: context)
            context.addLine(to: CGPoint(x: radius + Geometry.inset, y: rect.height / 2))
        }
        context.fillPath()
    }
}
