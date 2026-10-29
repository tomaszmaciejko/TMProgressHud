// SPDX-License-Identifier: MIT
// Copyright 2026 Tomasz Maciejko and TMProgressHud contributors.
import UIKit

/// Builds known indicators and delegates adaptation of client views.
@MainActor
enum IndicatorFactory {
    enum ReusePolicy {
        /// A complete selection must not adopt a view supplied by the client.
        case libraryViewsOnly
        /// Compatibility setters may adopt matching client views, preserving their progress operation.
        case includingClientViews
    }

    /// A nil selection represents compatibility custom content without a view.
    static func make(
        for content: TMProgressHudContent?, reusing previous: Indicator?, reusePolicy: ReusePolicy
    ) -> Indicator? {
        guard let content else { return nil }
        switch content {
        case .activity: return activityIndicator(reusing: previous, policy: reusePolicy)
        case .outlinedCircle: return circularIndicator(reusing: previous, policy: reusePolicy, isAnnular: false)
        case .ring: return circularIndicator(reusing: previous, policy: reusePolicy, isAnnular: true)
        case .bar: return barIndicator()
        case .custom(let view, let updateProgress):
            return ClientIndicatorAdapter.make(for: view, updateProgress: updateProgress)
        case .text: return nil
        }
    }

    private static func activityIndicator(reusing previous: Indicator?, policy: ReusePolicy) -> Indicator {
        let construction = IndicatorConstruction<UIActivityIndicatorView>(reusing: previous, policy: policy) {
            let spinner = UIActivityIndicatorView(style: .large)
            spinner.color = .white
            return spinner
        }
        let spinner = construction.view
        spinner.startAnimating()
        return construction.makeIndicator(
            libraryProgressUpdater: nil, colorUpdater: IndicatorColoring.activityUpdater(for: spinner))
    }

    private static func circularIndicator(
        reusing previous: Indicator?, policy: ReusePolicy, isAnnular: Bool
    ) -> Indicator {
        let construction = IndicatorConstruction(reusing: previous, policy: policy) { TMRoundProgressView() }
        let circle = construction.view
        if circle.isAnnular != isAnnular {
            circle.isAnnular = isAnnular
        }
        return construction.makeIndicator(
            libraryProgressUpdater: { circle.progress = $0 },
            colorUpdater: IndicatorColoring.circularUpdater(for: circle))
    }

    private static func barIndicator() -> Indicator {
        // Compatibility preserves the historical fresh-bar behavior, unlike circles and spinners.
        // Repeating an unchanged selection is handled by the HUD before it reaches this factory.
        let bar = TMBarProgressView()
        return Indicator(
            view: bar, origin: .library, progressUpdater: { bar.progress = $0 },
            colorUpdater: IndicatorColoring.barUpdater(for: bar))
    }
}
