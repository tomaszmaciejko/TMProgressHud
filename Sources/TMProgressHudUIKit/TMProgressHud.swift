// SPDX-License-Identifier: MIT
// Portions Copyright 2009-2020 Matej Bukovinski.
// Swift port Copyright 2026 Tomasz Maciejko and TMProgressHud contributors.
// Reference: 4a7c5f3e53cdea77c5dcb8578c2ee5acacdf6781. See THIRD_PARTY_NOTICES.md.
import UIKit

/// A progress and status view hosted in a caller-provided UIKit view.
@MainActor
@objc(TMProgressHud)
open class TMProgressHud: UIView {
    // MARK: - Content and appearance

    /// The compatibility content mode.
    ///
    /// Prefer setContent(_:) for a complete selection.
    @objc open dynamic var mode: TMProgressHudMode {
        get { contentSelection.mode }
        set {
            guard contentSelection.mode != newValue else { return }
            contentSelection.mode = newValue
            updateIndicator()
        }
    }

    /// Compatibility custom content.
    ///
    /// Prefer setContent(.custom(view)) to select it in one operation.
    @objc open dynamic var customView: UIView? {
        get { contentSelection.customView }
        set {
            guard contentSelection.customView !== newValue else { return }
            contentSelection.customView = newValue
            if mode == .customView { updateIndicator() }
        }
    }

    /// The default color for newly created indicators; changing it does not recolor existing content.
    public var defaultIndicatorColor: UIColor? = UIColor.label.withAlphaComponent(HUDMetrics.contentAlpha)

    /// A bulk color for current content and newly created indicators.
    ///
    /// A different non-nil value recolors current content. Direct view customizations survive mode changes.
    /// Nil disables bulk coloring without clearing colors; use clear for transparency.
    /// Container UIAppearance settings take precedence over the bulk color.
    @objc open dynamic var contentColor: UIColor? {
        get { defaultIndicatorColor }
        set {
            guard defaultIndicatorColor != newValue else { return }
            defaultIndicatorColor = newValue
            updateContentColor(contentColor)
        }
    }

    /// The mutable short-message label.
    @objc open dynamic var label: UILabel { storedLabel }

    /// The mutable multiline detail label.
    @objc open dynamic var detailsLabel: UILabel { storedDetailsLabel }

    /// The mutable action button.
    @objc open dynamic var button: UIButton { storedButton }

    /// The mutable bezel background view.
    @objc open dynamic var bezelView: TMBackgroundView { storedBezelView }

    /// The full-host background view behind the bezel.
    @objc open dynamic var backgroundView: TMBackgroundView { storedBackgroundView }

    /// Enables center tilt effects, initially false; repeated presentations preserve the enabled effect.
    @objc(defaultMotionEffectsEnabled) open dynamic var areDefaultMotionEffectsEnabled: Bool {
        @objc(areDefaultMotionEffectsEnabled) get { storedMotionEffectsEnabled }
        @objc(setDefaultMotionEffectsEnabled:) set {
            guard storedMotionEffectsEnabled != newValue else { return }
            storedMotionEffectsEnabled = newValue
            updateBezelMotionEffects()
        }
    }

    // MARK: - Progress

    /// Unnormalized progress; values are forwarded to supported indicators without clamping.
    @objc open dynamic var progress: Float = 0 {
        didSet {
            if oldValue != progress {
                forwardProgress()
            }
        }
    }

    /// Progress observed while the HUD is presented in a window.
    ///
    /// Updates arrive on the main actor. Hiding or detaching stops observation; showing reads the latest value.
    @objc open dynamic var progressObject: Progress? {
        didSet { updateProgressObservation() }
    }

    // MARK: - Layout

    /// Compatibility offset: projects edge anchors to legacy extremes and assigns only position.
    @objc open dynamic var offset: CGPoint {
        get { layoutPreferences.compatibilityOffset }
        set {
            guard layoutPreferences.compatibilityOffset != newValue else { return }
            layoutPreferences.position = .legacy(newValue)
            setNeedsUpdateConstraints()
        }
    }

    /// Compatibility spacing: reads the top content inset and assigns uniform inner and outer spacing.
    @objc open dynamic var margin: CGFloat {
        get { layoutPreferences.compatibilityMargin }
        set {
            let insets = HUDLayoutPreferences.uniformInsets(newValue)
            guard layoutPreferences.contentInsets != insets || layoutPreferences.hostInsets != insets else { return }
            layoutPreferences.contentInsets = insets
            layoutPreferences.hostInsets = insets
            setNeedsUpdateConstraints()
        }
    }

    /// Minimum bezel size, initially zero.
    @objc open dynamic var minSize: CGSize = .zero {
        didSet {
            if oldValue != minSize {
                setNeedsUpdateConstraints()
            }
        }
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

    // MARK: - Presentation options

    /// Seconds to wait before showing.
    ///
    /// Nonpositive values show immediately. Re-showing visible content does not reapply the grace delay.
    @objc open dynamic var graceTime: TimeInterval = 0

    /// The minimum visible duration in monotonic seconds, initially zero.
    @objc open dynamic var minShowTime: TimeInterval = 0

    /// Controls future transition motion and current HUD-owned tilt effects, following the system by default.
    public var motionPolicy: TMProgressHudMotionPolicy {
        get { motionSettings.policy }
        set { motionSettings.policy = newValue }
    }

    /// The transition style, initially fade.
    @objc open dynamic var animationType: TMProgressHudAnimation = .fade

    /// Whether hiding removes the HUD from its host; ordinary initialization defaults to false.
    @objc open dynamic var removeFromSuperViewOnHide = false

    /// The weak optional lifecycle delegate.
    @objc open dynamic weak var delegate: (any TMProgressHudDelegate)?

    /// A compatibility callback consumed by the next completed hide, before the optional delegate.
    ///
    /// Cleared before invocation. Prefer the per-request hide completion; use the delegate for recurring events.
    @objc open dynamic var completionBlock: TMProgressHudCompletionBlock?

    // MARK: - Owned state

    private enum ArchiveKeys {
        static let backgroundView = "TMProgressHud.backgroundView"
        static let bezelView = "TMProgressHud.bezelView"
    }

    private var storedSquare = false
    private var storedMotionEffectsEnabled = false
    private let storedBezelView = TMBackgroundView()
    private let storedBackgroundView = TMBackgroundView(frame: .zero, style: .solidColor)
    private let storedLabel = UILabel()
    private let storedDetailsLabel = UILabel()
    private let storedButton: UIButton = HUDRoundedButtonView(type: .custom)
    private let hudLayout = HUDLayout()
    private lazy var presentation = HUDPresentation(host: self)
    private lazy var progressBinding = HUDProgressBinding { [weak self] in self?.progress = $0 }

    var layoutPreferences = HUDLayoutPreferences()
    var contentSelection: (mode: TMProgressHudMode, customView: UIView?) = (.indeterminate, nil)
    lazy var motionSettings = HUDMotionSettings { [weak self] in self?.updateBezelMotionEffects() }
    var managedIndicator: HUDIndicator?
    var indicator: UIView? { managedIndicator?.view }
    var bezelMotionEffects: UIMotionEffectGroup?
    var hasHideRequest: Bool { presentation.hasHideRequest }

    // MARK: - Initialization

    /// Creates a HUD without attaching it to a host.
    public required override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
    }

    /// Creates a HUD using the host bounds, without attaching it.
    @objc(initWithView:) public required convenience init(view: UIView) {
        self.init(frame: view.bounds)
    }

    /// Decodes UIKit view state and creates one content hierarchy with current defaults.
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        for key in [ArchiveKeys.backgroundView, ArchiveKeys.bezelView] {
            guard coder.containsValue(forKey: key) else { continue }
            (coder.decodeObject(forKey: key) as? UIView)?.removeFromSuperview()
        }
        configureView()
    }

    /// Encodes UIKit view state and identifies owned views for reconstruction with current defaults.
    open override func encode(with coder: NSCoder) {
        super.encode(with: coder)
        coder.encode(storedBackgroundView, forKey: ArchiveKeys.backgroundView)
        coder.encode(storedBezelView, forKey: ArchiveKeys.bezelView)
    }

    // MARK: - Presentation and lookup

    /// Creates, attaches and shows a HUD that removes itself when hidden.
    @objc(showHUDAddedTo:animated:) open dynamic class func showAdded(to view: UIView, animated: Bool) -> Self {
        let hud = self.init(view: view)
        hud.removeFromSuperViewOnHide = true
        view.addSubview(hud)
        hud.show(animated: animated)
        return hud
    }

    /// Hides the last direct HUD child without a hide request, returning whether one was found.
    @objc(hideHUDForView:animated:) open dynamic class func hide(for view: UIView, animated: Bool) -> Bool {
        guard let hud = forView(view) else { return false }
        hud.removeFromSuperViewOnHide = true
        hud.hide(animated: animated)
        return true
    }

    /// Finds the last direct child of this HUD class, including subclasses, without a hide request.
    @objc(HUDForView:) open dynamic class func forView(_ view: UIView) -> Self? {
        for child in view.subviews.reversed() {
            if let hud = child as? Self, !hud.hasHideRequest {
                return hud
            }
        }
        return nil
    }

    /// Starts a presentation, replacing pending work and any unfinished previous hide.
    @objc(showAnimated:) open dynamic func show(animated: Bool) {
        presentation.show(animated: animated)
    }

    /// Hides the HUD after satisfying its minimum visible duration.
    @objc(hideAnimated:) open dynamic func hide(animated: Bool) {
        presentation.hide(animated: animated)
    }

    /// Hides the HUD and invokes a one-shot completion after it is hidden and optionally removed.
    ///
    /// A new show discards this request's completion. Repeated hides while waiting for the minimum duration
    /// keep the first request's completion; hides during or after dismissal are ignored.
    /// This completion runs before the compatibility completionBlock and delegate notification.
    @objc(hideAnimated:completion:) public final func hide(
        animated: Bool, completion: @escaping @MainActor (TMProgressHud) -> Void
    ) {
        presentation.hide(animated: animated) { [weak self] in
            guard let self else { return }
            completion(self)
        }
    }

    /// Replaces any pending delayed-hide request, in monotonic seconds.
    ///
    /// Nonpositive or NaN delays run on the next actor turn. Unrepresentable positive delays remain pending.
    @objc(hideAnimated:afterDelay:) open dynamic func hide(animated: Bool, afterDelay delay: TimeInterval) {
        presentation.hide(animated: animated, afterDelay: delay)
    }

    // MARK: - UIView lifecycle

    /// Synchronizes the frame with the host when attached or reparented.
    open override func didMoveToSuperview() {
        super.didMoveToSuperview()
        if let superview {
            frame = superview.bounds
        }
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
        if let indicator {
            content.insert(indicator, at: 0)
        }
        hudLayout.update(
            container: self, bezel: bezelView, content: content,
            configuration: .init(layout: layoutConfiguration, minimumSize: minSize, isSquare: isSquare))
        super.updateConstraints()
    }

    /// Updates content padding when constraints do not require rebuilding.
    open override func layoutSubviews() {
        if !needsUpdateConstraints() {
            hudLayout.updatePadding()
        }
        super.layoutSubviews()
    }

    // MARK: - Internal coordination

    func setTimingEnvironment(_ timing: HUDTimingEnvironment) {
        presentation.timing = timing
    }

    func updateProgressObservation() {
        if window != nil && presentation.isShowingContent {
            progressBinding.replace(with: progressObject)
            progressBinding.start()
        } else {
            progressBinding.stop()
            progressBinding.replace(with: nil)
        }
    }

    private func configureView() {
        isOpaque = false
        backgroundColor = .clear
        alpha = 0
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        layer.allowsGroupOpacity = false
        installContentViews()
        updateIndicator()
    }
}
