// SPDX-License-Identifier: MIT
// Copyright 2026 Tomasz Maciejko and TMProgressHud contributors.
import UIKit

/// Retains an indicator view and adapts its progress and color updates.
@MainActor
struct HUDIndicator {
    enum Origin {
        case library
        case client
    }

    enum ReusePolicy {
        case libraryViewsOnly
        case includingClientViews

        func allowsReuse(of origin: Origin) -> Bool {
            switch self {
            case .libraryViewsOnly: origin == .library
            case .includingClientViews: true
            }
        }
    }

    enum ColorPolicy {
        /// Preserves appearance precedence and the historical fixed track opacity.
        case compatibility
        case explicit

        var trackOpacity: TrackOpacity {
            switch self {
            case .compatibility: .fixed
            case .explicit: .relativeToSource
            }
        }
    }

    enum TrackOpacity {
        case fixed
        case relativeToSource
    }

    private enum AppearanceProperty {
        case activityColor
        case circleProgressColor
        case circleTrackColor
        case barProgressColor
        case barOutlineColor
    }

    private typealias ProgressUpdater = (Float) -> Void
    private typealias ColorUpdater = (UIColor?, ColorPolicy) -> Void

    let view: UIView

    /// Tracks who supplied the view, even after compatibility setters change its mode.
    let origin: Origin
    private let applyProgress: ProgressUpdater?
    private let applyColor: ColorUpdater

    func updateProgress(_ progress: Float) {
        applyProgress?(progress)
    }

    func updateColor(_ color: UIColor?, policy: ColorPolicy = .compatibility) {
        applyColor(color, policy)
    }

    /// A nil selection represents compatibility custom content without a view.
    static func make(
        for content: TMProgressHudContent?, reusing previous: HUDIndicator?, reusePolicy: ReusePolicy
    ) -> HUDIndicator? {
        guard let content else { return nil }

        let reusableView = reusableView(from: previous, policy: reusePolicy)
        guard let view = makeView(for: content, reusing: reusableView) else { return nil }

        let origin = origin(of: view, selectedBy: content, previous: previous)
        return HUDIndicator(
            view: view, origin: origin,
            applyProgress: progressUpdater(for: view, allowsLegacyProgress: content.allowsLegacyProgress),
            applyColor: colorUpdater(for: view))
    }

    private static func reusableView(from previous: HUDIndicator?, policy: ReusePolicy) -> UIView? {
        guard let previous else { return nil }
        guard policy.allowsReuse(of: previous.origin) else { return nil }
        return previous.view
    }

    private static func origin(
        of view: UIView, selectedBy content: TMProgressHudContent, previous: HUDIndicator?
    ) -> Origin {
        switch content {
        case .custom, .legacyCustom:
            return .client
        default:
            guard let previous, view === previous.view else { return .library }
            return previous.origin
        }
    }

    private static func makeView(for content: TMProgressHudContent, reusing previous: UIView?) -> UIView? {
        switch content {
        case .activity: return activityView(reusing: previous)
        case .outlinedCircle: return circularView(reusing: previous, isAnnular: false)
        case .ring: return circularView(reusing: previous, isAnnular: true)
        case .bar: return TMBarProgressView()
        case .custom(let view), .legacyCustom(let view): return view
        case .text: return nil
        }
    }

    private static func activityView(reusing previous: UIView?) -> UIActivityIndicatorView {
        let spinner = previous as? UIActivityIndicatorView ?? UIActivityIndicatorView(style: .large)
        if spinner !== previous {
            spinner.color = .white
        }
        spinner.startAnimating()
        return spinner
    }

    private static func circularView(reusing previous: UIView?, isAnnular: Bool) -> TMRoundProgressView {
        let circle = previous as? TMRoundProgressView ?? TMRoundProgressView()
        if circle.isAnnular != isAnnular {
            circle.isAnnular = isAnnular
        }
        return circle
    }

    private static func activityColorUpdater(for view: UIActivityIndicatorView) -> ColorUpdater {
        { color, policy in
            let selectedColor: UIColor?
            if let preferredColor = preferredColor(for: .activityColor, policy: policy, suppliedColor: color) {
                selectedColor = preferredColor
            } else {
                selectedColor = view.color
            }
            view.color = selectedColor
        }
    }

    private static func circularColorUpdater(for view: TMRoundProgressView) -> ColorUpdater {
        { color, policy in
            view.progressTintColor = resolveColor(
                for: .circleProgressColor, policy: policy,
                suppliedColor: color, fallback: view.progressTintColor)
            view.backgroundTintColor = resolveColor(
                for: .circleTrackColor, policy: policy,
                suppliedColor: circularTrackColor(from: color, opacity: policy.trackOpacity),
                fallback: view.backgroundTintColor)
        }
    }

    private static func barColorUpdater(for view: TMBarProgressView) -> ColorUpdater {
        { color, policy in
            view.progressColor = resolveColor(
                for: .barProgressColor, policy: policy,
                suppliedColor: color, fallback: view.progressColor)
            view.lineColor = resolveColor(
                for: .barOutlineColor, policy: policy,
                suppliedColor: color, fallback: view.lineColor)
        }
    }

    // Evaluate supplied and current colors only when earlier sources provide no color.
    private static func resolveColor(
        for property: AppearanceProperty, policy: ColorPolicy,
        suppliedColor: @autoclosure () -> UIColor?, fallback: @autoclosure () -> UIColor
    ) -> UIColor {
        if let preferredColor = preferredColor(for: property, policy: policy, suppliedColor: suppliedColor()) {
            return preferredColor
        }
        return fallback()
    }

    private static func preferredColor(
        for property: AppearanceProperty, policy: ColorPolicy, suppliedColor: @autoclosure () -> UIColor?
    ) -> UIColor? {
        if let appearanceColor = registeredAppearanceColor(for: property, policy: policy) {
            return appearanceColor
        }
        return suppliedColor()
    }

    private static func progressUpdater(for view: UIView, allowsLegacyProgress: Bool) -> ProgressUpdater? {
        if let reportingView = view as? any TMProgressHudProgressReporting {
            return { reportingView.progress = $0 }
        }
        if let circle = view as? TMRoundProgressView {
            return { circle.progress = $0 }
        }
        if let bar = view as? TMBarProgressView {
            return { bar.progress = $0 }
        }
        if let nativeProgressView = view as? UIProgressView {
            return { nativeProgressView.progress = $0 }
        }
        if allowsLegacyProgress, let legacyAdapter = HUDLegacyProgressAdapter(view: view) {
            return { legacyAdapter.updateProgress($0) }
        }
        return nil
    }

    private static func colorUpdater(for view: UIView) -> ColorUpdater {
        if let circle = view as? TMRoundProgressView {
            return circularColorUpdater(for: circle)
        }
        if let bar = view as? TMBarProgressView {
            return barColorUpdater(for: bar)
        }
        if let spinner = view as? UIActivityIndicatorView {
            return activityColorUpdater(for: spinner)
        }
        return { color, _ in
            if let color { view.tintColor = color }
        }
    }

    private static func circularTrackColor(from color: UIColor?, opacity: TrackOpacity) -> UIColor? {
        guard let color else { return nil }
        switch opacity {
        case .fixed:
            return color.withAlphaComponent(HUDMetrics.remainingAlpha)
        case .relativeToSource:
            return UIColor { traits in
                let resolvedColor = color.resolvedColor(with: traits)
                let trackAlpha = resolvedColor.cgColor.alpha * HUDMetrics.remainingAlpha
                return resolvedColor.withAlphaComponent(trackAlpha)
            }
        }
    }

    private static func registeredAppearanceColor(for property: AppearanceProperty, policy: ColorPolicy) -> UIColor? {
        if case .explicit = policy { return nil }
        let proxy: UIView
        let getter: Selector
        switch property {
        case .activityColor:
            proxy = UIActivityIndicatorView.appearance(whenContainedInInstancesOf: [TMProgressHud.self])
            getter = #selector(getter: UIActivityIndicatorView.color)
        case .circleProgressColor:
            proxy = TMRoundProgressView.appearance(whenContainedInInstancesOf: [TMProgressHud.self])
            getter = #selector(getter: TMRoundProgressView.progressTintColor)
        case .circleTrackColor:
            proxy = TMRoundProgressView.appearance(whenContainedInInstancesOf: [TMProgressHud.self])
            getter = #selector(getter: TMRoundProgressView.backgroundTintColor)
        case .barProgressColor:
            proxy = TMBarProgressView.appearance(whenContainedInInstancesOf: [TMProgressHud.self])
            getter = #selector(getter: TMBarProgressView.progressColor)
        case .barOutlineColor:
            proxy = TMBarProgressView.appearance(whenContainedInInstancesOf: [TMProgressHud.self])
            getter = #selector(getter: TMBarProgressView.lineColor)
        }
        // Registration can be absent even when the instance property is nonoptional.
        return proxy.perform(getter)?.takeUnretainedValue() as? UIColor
    }
}
