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

    /// A localized percentage for finite progress, bounded to 0...100 percent.
    ///
    /// An application-supplied accessibility value takes precedence; nil restores automatic formatting.
    open override var accessibilityValue: String? {
        get {
            super.accessibilityValue ?? HUDProgressAccessibility.value(for: progress, language: accessibilityLanguage)
        }
        set { super.accessibilityValue = newValue }
    }

    private func configureDrawing() {
        backgroundColor = .clear
        contentMode = .redraw
        isOpaque = false
        isAccessibilityElement = true
        accessibilityTraits.insert(.updatesFrequently)
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
        let outline = rect.insetBy(dx: Geometry.border, dy: Geometry.border)
        guard outline.width > 0, outline.height > 0 else { return }
        let borderPath = capsule(in: outline)
        context.addPath(borderPath.cgPath)
        context.setLineWidth(Geometry.border)
        context.setStrokeColor(lineColor.cgColor)
        context.setFillColor(progressRemainingColor.cgColor)
        context.drawPath(using: .fillStroke)

        let interior = rect.insetBy(dx: Geometry.inset, dy: Geometry.inset)
        guard interior.width > 0, interior.height > 0 else { return }
        let fraction = CGFloat(HUDProgressValue.boundedFraction(progress))
        context.addPath(capsule(in: interior).cgPath)
        context.clip()
        context.setFillColor(progressColor.cgColor)
        context.fill(
            CGRect(
                x: interior.minX, y: interior.minY,
                width: interior.width * fraction, height: interior.height))
    }

    private func capsule(in rect: CGRect) -> UIBezierPath {
        UIBezierPath(roundedRect: rect, cornerRadius: min(rect.width, rect.height) / 2)
    }
}
