// SPDX-License-Identifier: MIT
// Copyright 2026 Tomasz Maciejko and TMProgressHud contributors.
import UIKit

/// Owns the view and the operations supported by one selected indicator.
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
    /// The view keeps its origin when compatibility setters reuse it in a built-in mode.
    let origin: Origin
    private let receiveProgress: ((Float) -> Void)?
    private let receiveColor: (UIColor?, ColorPolicy) -> Void

    func updateProgress(_ progress: Float) {
        receiveProgress?(progress)
    }
    func updateColor(_ color: UIColor?, policy: ColorPolicy = .compatibility) {
        receiveColor(color, policy)
    }

    static func make(
        for content: TMProgressHudContent?, reusing previous: HUDIndicator?, policy: ReusePolicy
    ) -> HUDIndicator? {
        guard let content else { return nil }
        let selection = content.selection
        let reusable: UIView?
        if let previous, policy == .includingClientViews || previous.origin == .library {
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

    private static func spinnerIndicator(_ view: UIActivityIndicatorView, origin: Origin) -> HUDIndicator {
        HUDIndicator(view: view, origin: origin, receiveProgress: nil) { color, policy in
            view.color =
                appearanceColor(for: .activityColor, policy: policy)
                ?? color ?? view.color
        }
    }

    private static func roundIndicator(_ view: TMRoundProgressView, origin: Origin) -> HUDIndicator {
        HUDIndicator(view: view, origin: origin, receiveProgress: { view.progress = $0 }) { color, policy in
            view.progressTintColor =
                appearanceColor(for: .circleProgressColor, policy: policy)
                ?? color ?? view.progressTintColor
            view.backgroundTintColor =
                appearanceColor(for: .circleTrackColor, policy: policy)
                ?? trackColor(from: color, opacity: policy.trackOpacity) ?? view.backgroundTintColor
        }
    }

    private static func barIndicator(_ view: TMBarProgressView, origin: Origin) -> HUDIndicator {
        HUDIndicator(view: view, origin: origin, receiveProgress: { view.progress = $0 }) { color, policy in
            view.progressColor =
                appearanceColor(for: .barProgressColor, policy: policy)
                ?? color ?? view.progressColor
            view.lineColor =
                appearanceColor(for: .barOutlineColor, policy: policy)
                ?? color ?? view.lineColor
        }
    }

    private static func indicator(
        for view: UIView, origin: Origin, allowsLegacyProgress: Bool
    ) -> HUDIndicator {
        if let round = view as? TMRoundProgressView { return roundIndicator(round, origin: origin) }
        if let bar = view as? TMBarProgressView { return barIndicator(bar, origin: origin) }
        if let spinner = view as? UIActivityIndicatorView { return spinnerIndicator(spinner, origin: origin) }
        let receiveProgress: ((Float) -> Void)?
        if let reporting = view as? any TMProgressHudProgressReporting {
            receiveProgress = { reporting.progress = $0 }
        } else if let native = view as? UIProgressView {
            receiveProgress = { native.progress = $0 }
        } else if allowsLegacyProgress, let adapter = HUDLegacyProgressAdapter(view: view) {
            receiveProgress = { adapter.updateProgress($0) }
        } else {
            receiveProgress = nil
        }
        return HUDIndicator(view: view, origin: origin, receiveProgress: receiveProgress) { color, _ in
            if let color { view.tintColor = color }
        }
    }

    private static func trackColor(from color: UIColor?, opacity: TrackOpacity) -> UIColor? {
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

    private static func appearanceColor(for property: AppearanceProperty, policy: ColorPolicy) -> UIColor? {
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
