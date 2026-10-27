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

    let view: UIView

    /// Tracks who supplied the view, even after compatibility setters change its mode.
    let origin: Origin
    private let applyProgress: ((Float) -> Void)?
    private let applyColor: (UIColor?, ColorPolicy) -> Void

    func updateProgress(_ progress: Float) {
        applyProgress?(progress)
    }

    func updateColor(_ color: UIColor?, policy: ColorPolicy = .compatibility) {
        applyColor(color, policy)
    }

    /// Text and compatibility custom content without a view produce no indicator.
    static func make(
        for content: TMProgressHudContent?, reusing previous: HUDIndicator?, reusePolicy: ReusePolicy
    ) -> HUDIndicator? {
        guard let content else { return nil }
        let selection = content.selection
        let reusable: UIView?
        if let previous, reusePolicy == .includingClientViews || previous.origin == .library {
            reusable = previous.view
        } else {
            reusable = nil
        }
        guard let view = makeView(for: selection, reusing: reusable) else { return nil }
        let origin: Origin
        if selection.mode == .customView {
            origin = .client
        } else if let previous, view === previous.view {
            origin = previous.origin
        } else {
            origin = .library
        }
        return indicator(for: view, origin: origin, allowsLegacyProgress: selection.allowsLegacyProgress)
    }

    private static func makeView(
        for selection: TMProgressHudContent.Selection, reusing previous: UIView?
    ) -> UIView? {
        switch selection.mode {
        case .indeterminate:
            let spinner = previous as? UIActivityIndicatorView ?? UIActivityIndicatorView(style: .large)
            if spinner !== previous {
                spinner.color = .white
            }
            spinner.startAnimating()
            return spinner
        case .determinate, .annularDeterminate:
            let round = previous as? TMRoundProgressView ?? TMRoundProgressView()
            let annular = selection.mode == .annularDeterminate
            if round.isAnnular != annular {
                round.isAnnular = annular
            }
            return round
        case .determinateHorizontalBar: return TMBarProgressView()
        case .customView:
            return selection.customView
        case .text: return nil
        }
    }

    private static func spinnerColors(_ view: UIActivityIndicatorView) -> (UIColor?, ColorPolicy) -> Void {
        { color, policy in
            view.color =
                registeredAppearanceColor(for: .activityColor, policy: policy)
                ?? color ?? view.color
        }
    }

    private static func roundColors(_ view: TMRoundProgressView) -> (UIColor?, ColorPolicy) -> Void {
        { color, policy in
            view.progressTintColor =
                registeredAppearanceColor(for: .circleProgressColor, policy: policy)
                ?? color ?? view.progressTintColor
            view.backgroundTintColor =
                registeredAppearanceColor(for: .circleTrackColor, policy: policy)
                ?? circularTrackColor(from: color, opacity: policy.trackOpacity) ?? view.backgroundTintColor
        }
    }

    private static func barColors(_ view: TMBarProgressView) -> (UIColor?, ColorPolicy) -> Void {
        { color, policy in
            view.progressColor =
                registeredAppearanceColor(for: .barProgressColor, policy: policy)
                ?? color ?? view.progressColor
            view.lineColor =
                registeredAppearanceColor(for: .barOutlineColor, policy: policy)
                ?? color ?? view.lineColor
        }
    }

    private static func indicator(
        for view: UIView, origin: Origin, allowsLegacyProgress: Bool
    ) -> HUDIndicator {
        HUDIndicator(
            view: view, origin: origin,
            applyProgress: progressUpdater(for: view, allowsLegacyProgress: allowsLegacyProgress),
            applyColor: colorUpdater(for: view))
    }

    private static func progressUpdater(for view: UIView, allowsLegacyProgress: Bool) -> ((Float) -> Void)? {
        if let reporting = view as? any TMProgressHudProgressReporting {
            return { reporting.progress = $0 }
        }
        if let round = view as? TMRoundProgressView { return { round.progress = $0 } }
        if let bar = view as? TMBarProgressView { return { bar.progress = $0 } }
        if let native = view as? UIProgressView { return { native.progress = $0 } }
        if allowsLegacyProgress, let adapter = HUDLegacyProgressAdapter(view: view) {
            return { adapter.updateProgress($0) }
        }
        return nil
    }

    private static func colorUpdater(for view: UIView) -> (UIColor?, ColorPolicy) -> Void {
        if let round = view as? TMRoundProgressView { return roundColors(round) }
        if let bar = view as? TMBarProgressView { return barColors(bar) }
        if let spinner = view as? UIActivityIndicatorView { return spinnerColors(spinner) }
        return { color, _ in
            if let color { view.tintColor = color }
        }
    }

    private static func circularTrackColor(from color: UIColor?, opacity: TrackOpacity) -> UIColor? {
        color.map { color in
            if case .fixed = opacity {
                return color.withAlphaComponent(HUDMetrics.remainingAlpha)
            }
            return UIColor { traits in
                let resolved = color.resolvedColor(with: traits)
                return resolved.withAlphaComponent(resolved.cgColor.alpha * HUDMetrics.remainingAlpha)
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
