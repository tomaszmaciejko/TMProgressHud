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
    /// The completion called before the optional delegate after each reference hide sequence.
    @objc open dynamic var completionBlock: TMProgressHudCompletionBlock?
    /// Seconds to wait before showing.
    ///
    /// Nonpositive values show immediately.
    @objc open dynamic var graceTime: TimeInterval = 0
    /// The minimum visible duration in seconds, initially zero.
    @objc open dynamic var minShowTime: TimeInterval = 0
    /// Whether hiding removes the HUD from its host.
    ///
    /// Ordinary initialization defaults to false.
    @objc open dynamic var removeFromSuperViewOnHide = false
    /// The content tint.
    ///
    /// Nil leaves existing individual view colors unchanged.
    @objc open dynamic var contentColor: UIColor? {
        get { storedContentColor }
        set {
            guard storedContentColor != newValue else { return }
            storedContentColor = newValue
            updateViewsForColor(newValue)
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
    /// Enables the reference center tilt effects, initially false.
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
    /// A progress object polled by display link, following the reference ownership and timing.
    @objc open dynamic var progressObject: Progress? {
        didSet { if oldValue !== progressObject { setProgressDisplayLinkEnabled(true) } }
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

    var timing = HUDTimingEnvironment()
    var useAnimation = false
    var hasFinished = false
    var showStarted: Date?
    var indicator: UIView?
    var paddingConstraints: [NSLayoutConstraint] = []
    var bezelConstraints: [NSLayoutConstraint] = []
    let topSpacer = UIView()
    let bottomSpacer = UIView()
    var bezelMotionEffects: UIMotionEffectGroup?
    weak var graceTimer: Timer?
    weak var minShowTimer: Timer?
    weak var hideDelayTimer: Timer?
    weak var progressDisplayLink: CADisplayLink? {
        didSet {
            if oldValue !== progressDisplayLink {
                oldValue?.invalidate()
                progressDisplayLink?.add(to: .main, forMode: .default)
            }
        }
    }

    // The public legacy notification name preserves upstream orientation observation
    // without referencing its SDK-deprecated constant. Autoresizing also tracks bounds.
    static let orientationNotification = Notification.Name("UIApplicationDidChangeStatusBarOrientationNotification")

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

    #if os(iOS) && !targetEnvironment(macCatalyst)
        deinit { NotificationCenter.default.removeObserver(self) }
    #endif

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
        synchronizeHostBounds()
    }

    /// Rebuilds the reference bezel/content constraints.
    open override func updateConstraints() {
        rebuildConstraints()
        super.updateConstraints()
    }

    /// Updates content padding when constraints do not require rebuilding.
    open override func layoutSubviews() {
        if !needsUpdateConstraints() { updatePaddingConstraints() }
        super.layoutSubviews()
    }

    /// Shows the HUD immediately or after graceTime, using the reference timing semantics.
    @objc(showAnimated:) open dynamic func show(animated: Bool) {
        minShowTimer?.invalidate()
        useAnimation = animated
        hasFinished = false
        if graceTime > 0 {
            graceTimer = timing.schedule(graceTime, self, #selector(handleGraceTimer), nil)
        } else {
            showUsingAnimation(useAnimation)
        }
    }

    /// Hides the HUD after satisfying its minimum visible duration.
    @objc(hideAnimated:) open dynamic func hide(animated: Bool) {
        graceTimer?.invalidate()
        useAnimation = animated
        hasFinished = true
        if minShowTime > 0, let showStarted {
            let elapsed = timing.now().timeIntervalSince(showStarted)
            if elapsed < minShowTime {
                minShowTimer = timing.schedule(minShowTime - elapsed, self, #selector(handleMinShowTimer), nil)
                return
            }
        }
        hideUsingAnimation(useAnimation)
    }

    /// Replaces any pending delayed-hide request; delay is expressed in seconds.
    @objc(hideAnimated:afterDelay:) open dynamic func hide(animated: Bool, afterDelay delay: TimeInterval) {
        hideDelayTimer?.invalidate()
        hideDelayTimer = timing.schedule(delay, self, #selector(handleHideTimer(_:)), animated)
    }

    func commonInit() {
        isOpaque = false
        backgroundColor = .clear
        alpha = 0
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        layer.allowsGroupOpacity = false
        setupViews()
        updateIndicators()
        #if os(iOS) && !targetEnvironment(macCatalyst)
            NotificationCenter.default.addObserver(
                self, selector: #selector(orientationDidChange), name: Self.orientationNotification, object: nil
            )
        #endif
    }

    #if os(iOS) && !targetEnvironment(macCatalyst)
        @objc func orientationDidChange() {
            guard superview != nil else { return }
            synchronizeHostBounds()
        }
    #endif

    func synchronizeHostBounds() {
        if let superview { frame = superview.bounds }
    }
}
