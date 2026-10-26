// SPDX-License-Identifier: MIT
// Portions Copyright 2009-2020 Matej Bukovinski.
// Swift port Copyright 2026 Tomasz Maciejko and TMProgressHud contributors.
// Reference: 4a7c5f3e53cdea77c5dcb8578c2ee5acacdf6781. See THIRD_PARTY_NOTICES.md.
import UIKit

/// A configurable solid or blurred HUD background, isolated to the main actor.
@MainActor
@objc(TMBackgroundView)
open class TMBackgroundView: UIView {
    private enum ArchiveKeys {
        static let effectView = "TMBackgroundView.effectView"
    }

    private enum Defaults {
        #if os(tvOS)
            static let blurEffectStyle: UIBlurEffect.Style = .regular
        #else
            static let blurEffectStyle: UIBlurEffect.Style = .systemThickMaterial
        #endif
    }

    /// The background style.
    ///
    /// The default is blur.
    @objc open dynamic var style: TMProgressHudBackgroundStyle = .blur {
        didSet {
            if oldValue != style { updateBackground() }
        }
    }

    /// The system blur material.

    ///

    /// The default is regular on tvOS and systemThickMaterial on iOS.
    @objc open dynamic var blurEffectStyle: UIBlurEffect.Style = Defaults.blurEffectStyle {
        didSet {
            if oldValue != blurEffectStyle { updateBackground() }
        }
    }

    /// The container tint, initially nil.

    ///

    /// Nil clears the tint without removing the blur.
    @objc open dynamic var color: UIColor? {
        get { storedColor }
        set {
            guard storedColor != newValue else { return }
            storedColor = newValue
            backgroundColor = color
        }
    }

    private var storedColor: UIColor? = nil

    private var effectView: UIVisualEffectView?

    /// Creates a background using the reference blur defaults.
    public override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        updateBackground()
    }

    init(frame: CGRect, style: TMProgressHudBackgroundStyle) {
        self.style = style
        super.init(frame: frame)
        clipsToBounds = true
        updateBackground()
    }

    /// Decodes a background and applies the supported Swift background defaults.
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        if coder.containsValue(forKey: ArchiveKeys.effectView) {
            effectView = coder.decodeObject(forKey: ArchiveKeys.effectView) as? UIVisualEffectView
        }
        clipsToBounds = true
        updateBackground()
    }

    /// Encodes UIKit view state and identifies the owned effect view without persisting HUD configuration.
    open override func encode(with coder: NSCoder) {
        super.encode(with: coder)
        coder.encode(effectView, forKey: ArchiveKeys.effectView)
    }

    /// The smallest intrinsic size; surrounding content determines the final size.
    open override var intrinsicContentSize: CGSize { .zero }

    private func updateBackground() {
        if style == .blur {
            updateBlur()
        } else {
            effectView?.removeFromSuperview()
            effectView = nil
        }
        backgroundColor = color
    }

    private func updateBlur() {
        let effect = UIBlurEffect(style: blurEffectStyle)
        if let effectView {
            effectView.effect = effect
            return
        }
        let view = UIVisualEffectView(effect: effect)
        view.frame = bounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        insertSubview(view, at: 0)
        layer.allowsGroupOpacity = false
        effectView = view
    }
}
