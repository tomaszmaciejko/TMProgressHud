// SPDX-License-Identifier: MIT
// Portions Copyright 2009-2020 Matej Bukovinski.
// Swift port Copyright 2026 Tomasz Maciejko and TMProgressHud contributors.
// Reference: 4a7c5f3e53cdea77c5dcb8578c2ee5acacdf6781. See THIRD_PARTY_NOTICES.md.
import UIKit

/// A main-actor TMProgressHud hosted in a caller-provided view.
@MainActor
@objc(TMProgressHud)
open class TMProgressHud: UIView {
    /// The displayed indicator/content mode.
    ///
    /// Initially indeterminate.
    @objc open dynamic var mode: TMProgressHudMode = .indeterminate {
        didSet { if oldValue != mode { updateIndicators() } }
    }
    /// The weak optional lifecycle delegate.
    @objc open dynamic weak var delegate: (any TMProgressHudDelegate)?
    /// Called once when hiding completes, before the optional delegate.
    ///
    /// Repeated hide calls after completion do not repeat callbacks. A new show supersedes unfinished hiding.
    @objc open dynamic var completionBlock: TMProgressHudCompletionBlock?
    /// Seconds to wait before showing.
    ///
    /// Nonpositive values show immediately. Re-showing an already visible HUD does not reapply the grace delay.
    @objc open dynamic var graceTime: TimeInterval = 0
    /// The minimum visible duration in monotonic seconds, initially zero.
    @objc open dynamic var minShowTime: TimeInterval = 0
    /// Whether hiding removes the HUD from its host.
    ///
    /// Ordinary initialization defaults to false.
    @objc open dynamic var removeFromSuperViewOnHide = false
    /// A bulk color for current content and newly created indicators.
    ///
    /// Changing to a non-nil value updates labels, the button and the current indicator.
    /// Direct view customizations survive mode changes. Assigning the same value does nothing.
    /// Nil disables bulk coloring without clearing existing colors; use clear for transparency.
    /// Container UIAppearance settings on indicators are not overwritten by bulk coloring.
    @objc open dynamic var contentColor: UIColor? {
        get { storedContentColor }
        set {
            guard storedContentColor != newValue else { return }
            storedContentColor = newValue
            updateViewsForColor(contentColor)
        }
    }
    /// The transition style, initially fade.
    @objc open dynamic var animationType: TMProgressHudAnimation = .fade
    /// Offset relative to the host center, constrained by the minimum outer margin.
    @objc open dynamic var offset: CGPoint = .zero {
        didSet { if oldValue != offset { setNeedsUpdateConstraints() } }
    }
    /// Inner and minimum outer margin in points, initially 20.
    @objc open dynamic var margin: CGFloat = HUDMetrics.margin {
        didSet { if oldValue != margin { setNeedsUpdateConstraints() } }
    }
    /// Minimum bezel size, initially zero.
    @objc open dynamic var minSize: CGSize = .zero {
        didSet { if oldValue != minSize { setNeedsUpdateConstraints() } }
    }
    /// Whether to request a square bezel when constraints permit.
    @objc(square) open dynamic var isSquare: Bool {
        @objc(isSquare) get { storedSquare }
        @objc(setSquare:) set {
            guard storedSquare != newValue else { return }
            storedSquare = newValue
            setNeedsUpdateConstraints()
        }
    }
    /// Enables center tilt effects, initially false; repeated presentations preserve the enabled effect.
    @objc(defaultMotionEffectsEnabled) open dynamic var areDefaultMotionEffectsEnabled: Bool {
        @objc(areDefaultMotionEffectsEnabled) get { storedMotionEffectsEnabled }
        @objc(setDefaultMotionEffectsEnabled:) set {
            guard storedMotionEffectsEnabled != newValue else { return }
            storedMotionEffectsEnabled = newValue
            updateBezelMotionEffects()
        }
    }
    /// Unnormalized progress; values are forwarded to supported indicators without clamping.
    @objc open dynamic var progress: Float = 0 {
        didSet { if oldValue != progress { forwardProgress() } }
    }
    /// Progress observed while the HUD is presented in a window.
    ///
    /// Updates arrive on the main actor. Hiding or detaching stops observation; showing reads the latest value.
    @objc open dynamic var progressObject: Progress? {
        didSet { updateProgressObservation() }
    }
    /// The caller's custom content, used in customView mode.
    @objc open dynamic var customView: UIView? {
        didSet { if oldValue !== customView && mode == .customView { updateIndicators() } }
    }
    /// The mutable bezel background view.
    @objc open dynamic var bezelView: TMBackgroundView { storedBezelView }
    /// The full-host background view behind the bezel.
    @objc open dynamic var backgroundView: TMBackgroundView { storedBackgroundView }
    /// The mutable short-message label.
    @objc open dynamic var label: UILabel { storedLabel }
    /// The mutable multiline detail label.
    @objc open dynamic var detailsLabel: UILabel { storedDetailsLabel }
    /// The mutable reference action button.
    @objc open dynamic var button: UIButton { storedButton }

    private var storedContentColor: UIColor? = UIColor.label.withAlphaComponent(HUDMetrics.contentAlpha)
    private var storedSquare = false
    private var storedMotionEffectsEnabled = false
    private let storedBezelView = TMBackgroundView()
    private let storedBackgroundView = TMBackgroundView()
    private let storedLabel = UILabel()
    private let storedDetailsLabel = UILabel()
    private let storedButton: UIButton = HUDRoundedButtonView(type: .custom)
    private let hudLayout = HUDLayout()

    private lazy var presentation = HUDPresentation(host: self)
    func setTimingEnvironment(_ timing: HUDTimingEnvironment) { presentation.timing = timing }
    var hasFinished: Bool { presentation.hasFinished }
    var managedIndicator: HUDIndicator?
    var indicator: UIView? { managedIndicator?.view }
    var bezelMotionEffects: UIMotionEffectGroup?
    private lazy var progressBinding = HUDProgressBinding { [weak self] in self?.progress = $0 }

    func updateProgressObservation() {
        if window != nil && presentation.isShowingContent {
            progressBinding.replace(with: progressObject)
            progressBinding.start()
        } else {
            progressBinding.stop()
            progressBinding.replace(with: nil)
        }
    }

    /// Creates a HUD without attaching it to a host.
    public required override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    /// Creates a HUD using the host bounds, without attaching it.
    @objc(initWithView:) public required convenience init(view: UIView) {
        self.init(frame: view.bounds)
    }

    /// Decodes a HUD and initializes the reference content hierarchy.
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    /// Creates, attaches and shows a HUD that removes itself when hidden.
    @objc(showHUDAddedTo:animated:) open dynamic class func showAdded(to view: UIView, animated: Bool) -> Self {
        let hud = self.init(view: view)
        hud.removeFromSuperViewOnHide = true
        view.addSubview(hud)
        hud.show(animated: animated)
        return hud
    }

    /// Hides the last unfinished direct HUD child, returning whether one was found.
    @objc(hideHUDForView:animated:) open dynamic class func hide(for view: UIView, animated: Bool) -> Bool {
        guard let hud = forView(view) else { return false }
        hud.removeFromSuperViewOnHide = true
        hud.hide(animated: animated)
        return true
    }

    /// Finds the last unfinished direct child of this HUD class, including subclasses.
    @objc(HUDForView:) open dynamic class func forView(_ view: UIView) -> Self? {
        for child in view.subviews.reversed() {
            if let hud = child as? Self, !hud.hasFinished { return hud }
        }
        return nil
    }

    /// Synchronizes the frame with the host when attached or reparented.
    open override func didMoveToSuperview() {
        super.didMoveToSuperview()
        if let superview { frame = superview.bounds }
        updateProgressObservation()
    }

    /// Starts or stops progress observation when the presentation gains or loses a window.
    open override func didMoveToWindow() {
        super.didMoveToWindow()
        updateProgressObservation()
    }

    /// Updates owned constraints for the current content and layout configuration.
    open override func updateConstraints() {
        var content = [label, detailsLabel, button]
        if let indicator { content.insert(indicator, at: 0) }
        hudLayout.update(
            container: self, bezel: bezelView, content: content,
            configuration: .init(offset: offset, margin: margin, minimumSize: minSize, isSquare: isSquare))
        super.updateConstraints()
    }

    /// Updates content padding when constraints do not require rebuilding.
    open override func layoutSubviews() {
        if !needsUpdateConstraints() { hudLayout.updatePadding() }
        super.layoutSubviews()
    }

    /// Starts a presentation, replacing pending work and any unfinished previous hide.
    @objc(showAnimated:) open dynamic func show(animated: Bool) { presentation.show(animated: animated) }

    /// Hides the HUD after satisfying its minimum visible duration.
    @objc(hideAnimated:) open dynamic func hide(animated: Bool) { presentation.hide(animated: animated) }

    /// Replaces any pending delayed-hide request, in monotonic seconds.
    ///
    /// Nonpositive or NaN delays run on the next actor turn. Unrepresentable positive delays remain pending.
    @objc(hideAnimated:afterDelay:) open dynamic func hide(animated: Bool, afterDelay delay: TimeInterval) {
        presentation.hide(animated: animated, afterDelay: delay)
    }

    func commonInit() {
        isOpaque = false
        backgroundColor = .clear
        alpha = 0
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        layer.allowsGroupOpacity = false
        setupViews()
        updateIndicators()
    }
}
