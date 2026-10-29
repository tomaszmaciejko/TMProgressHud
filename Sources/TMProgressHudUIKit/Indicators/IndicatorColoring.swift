// SPDX-License-Identifier: MIT
// Copyright 2026 Tomasz Maciejko and TMProgressHud contributors.
import UIKit

private let remainingTrackAlpha: CGFloat = 0.1

/// Builds color operations for known view types and resolves compatibility appearance rules.
@MainActor
enum IndicatorColoring {
    private typealias ColorPolicy = Indicator.ColorPolicy

    private enum AppearanceProperty {
        case activityColor
        case circleProgressColor
        case circleTrackColor
        case barProgressColor
        case barOutlineColor
    }

    static func activityUpdater(for view: UIActivityIndicatorView) -> Indicator.ColorUpdater {
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

    static func circularUpdater(for view: TMRoundProgressView) -> Indicator.ColorUpdater {
        { color, policy in
            view.progressTintColor = resolveColor(
                for: .circleProgressColor, policy: policy,
                suppliedColor: color, fallback: view.progressTintColor)
            view.backgroundTintColor = resolveColor(
                for: .circleTrackColor, policy: policy,
                suppliedColor: circularTrackColor(from: color, policy: policy),
                fallback: view.backgroundTintColor)
        }
    }

    static func barUpdater(for view: TMBarProgressView) -> Indicator.ColorUpdater {
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

    static func tintUpdater(for view: UIView) -> Indicator.ColorUpdater {
        { color, _ in
            if let color { view.tintColor = color }
        }
    }

    private static func circularTrackColor(from color: UIColor?, policy: ColorPolicy) -> UIColor? {
        guard let color else { return nil }
        switch policy {
        case .compatibility:
            return color.withAlphaComponent(remainingTrackAlpha)
        case .explicit:
            return UIColor { traits in
                let resolvedColor = color.resolvedColor(with: traits)
                let trackAlpha = resolvedColor.cgColor.alpha * remainingTrackAlpha
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
