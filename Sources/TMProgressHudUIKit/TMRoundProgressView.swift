// SPDX-License-Identifier: MIT
// Portions Copyright 2009-2020 Matej Bukovinski.
// Swift port Copyright 2026 Tomasz Maciejko and TMProgressHud contributors.
// Reference: 4a7c5f3e53cdea77c5dcb8578c2ee5acacdf6781. See THIRD_PARTY_NOTICES.md.
import UIKit

/// The reference circular progress indicator, supporting pie and annular drawing.
@MainActor
@objc(TMRoundProgressView)
open class TMRoundProgressView: UIView {
    private enum Geometry {
        static let size = CGSize(width: 37, height: 37)
        static let lineWidth: CGFloat = 2
        static let backgroundAlpha: CGFloat = CGFloat(Float(0.1))
        // Match the original C conversion (float)M_PI, not Swift Float.pi.
        static let referencePi = Float(Double.pi)
        static let startAngle = -CGFloat(referencePi) / 2
        static let fullTurn = 2 * CGFloat(referencePi)
    }

    /// The unnormalized progress value.

    ///

    /// A changed value requests drawing.
    @objc open dynamic var progress: Float = 0 {
        didSet {
            if oldValue != progress { setNeedsDisplay() }
        }
    }

    /// The progress color, initially white.
    @objc open dynamic var progressTintColor: UIColor {
        get { storedProgressTintColor }
        set {
            guard storedProgressTintColor != newValue else { return }
            storedProgressTintColor = newValue
            setNeedsDisplay()
        }
    }

    private var storedProgressTintColor: UIColor = .white

    /// The remaining/background color, initially white at alpha 0.1.
    @objc open dynamic var backgroundTintColor: UIColor {
        get { storedBackgroundTintColor }
        set {
            guard storedBackgroundTintColor != newValue else { return }
            storedBackgroundTintColor = newValue
            setNeedsDisplay()
        }
    }

    private var storedBackgroundTintColor: UIColor = UIColor(white: 1, alpha: Geometry.backgroundAlpha)

    /// Whether to draw an annular indicator.

    ///

    /// Changing this alone does not request redraw, matching the reference.
    @objc(annular) open dynamic var isAnnular: Bool {
        @objc(isAnnular) get { storedAnnular }
        @objc(setAnnular:) set { storedAnnular = newValue }
    }

    private var storedAnnular = false

    /// Creates a 37-by-37-point indicator.
    public convenience init() {
        self.init(frame: CGRect(origin: .zero, size: Geometry.size))
    }

    /// Creates a transparent indicator with the supplied frame.
    public override init(frame: CGRect) {
        super.init(frame: frame)
        configureDrawing()
    }

    /// Decodes an indicator using initialized Swift color defaults.
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureDrawing()
    }

    private func configureDrawing() {
        backgroundColor = .clear
        isOpaque = false
        registerForTraitChanges(UITraitCollection.systemTraitsAffectingColorAppearance) {
            (view: TMRoundProgressView, _) in
            view.setNeedsDisplay()
        }
    }

    /// The reference 37-by-37-point intrinsic size.
    open override var intrinsicContentSize: CGSize { Geometry.size }

    /// Draws the current progress using the reference geometry.
    open override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        if isAnnular { drawRing() } else { drawPie(in: context) }
    }

    private func drawRing() {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = (bounds.width - Geometry.lineWidth) / 2
        let background = UIBezierPath(
            arcCenter: center, radius: radius, startAngle: Geometry.startAngle,
            endAngle: Geometry.startAngle + Geometry.fullTurn, clockwise: true
        )
        background.lineWidth = Geometry.lineWidth
        background.lineCapStyle = .butt
        backgroundTintColor.set()
        background.stroke()
        let path = UIBezierPath(
            arcCenter: center, radius: radius, startAngle: Geometry.startAngle,
            endAngle: Geometry.startAngle + CGFloat(progress * 2 * Geometry.referencePi), clockwise: true
        )
        path.lineWidth = Geometry.lineWidth
        path.lineCapStyle = .square
        progressTintColor.set()
        path.stroke()
    }

    private func drawPie(in context: CGContext) {
        let lineWidth = Geometry.lineWidth
        let circle = bounds.insetBy(dx: lineWidth / 2, dy: lineWidth / 2)
        progressTintColor.setStroke()
        backgroundTintColor.setFill()
        context.setLineWidth(lineWidth)
        context.strokeEllipse(in: circle)
        let pathWidth = lineWidth * 2
        let path = UIBezierPath(
            arcCenter: CGPoint(x: bounds.midX, y: bounds.midY),
            radius: bounds.width / 2 - pathWidth / 2,
            startAngle: Geometry.startAngle,
            endAngle: Geometry.startAngle + CGFloat(progress * 2 * Geometry.referencePi),
            clockwise: true
        )
        path.lineWidth = pathWidth
        path.lineCapStyle = .butt
        context.setBlendMode(.copy)
        progressTintColor.set()
        path.stroke()
    }
}
