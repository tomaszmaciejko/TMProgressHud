// SPDX-License-Identifier: MIT
// Copyright 2026 Tomasz Maciejko and TMProgressHud contributors.
import UIKit

/// Builds complete indicators, keeping runtime capability detection at the client-view boundary.
@MainActor
enum HUDIndicatorFactory {
    enum ReusePolicy {
        case libraryViewsOnly
        case includingClientViews

        func allowsReuse(of origin: HUDIndicator.Origin) -> Bool {
            switch self {
            case .libraryViewsOnly: origin == .library
            case .includingClientViews: true
            }
        }
    }

    /// A nil selection represents compatibility custom content without a view.
    static func make(
        for content: TMProgressHudContent?, reusing previous: HUDIndicator?, reusePolicy: ReusePolicy
    ) -> HUDIndicator? {
        guard let content else { return nil }
        let reusable = reusableIndicator(from: previous, policy: reusePolicy)
        switch content {
        case .activity: return activityIndicator(reusing: reusable)
        case .outlinedCircle: return circularIndicator(reusing: reusable, isAnnular: false)
        case .ring: return circularIndicator(reusing: reusable, isAnnular: true)
        case .bar: return barIndicator()
        case .custom(let view), .legacyCustom(let view):
            return clientIndicator(for: view, allowsLegacyProgress: content.allowsLegacyProgress)
        case .text: return nil
        }
    }

    private static func reusableIndicator(from previous: HUDIndicator?, policy: ReusePolicy) -> HUDIndicator? {
        guard let previous, policy.allowsReuse(of: previous.origin) else { return nil }
        return previous
    }

    private static func makeOrReuse<View: UIView>(
        from previous: HUDIndicator?, createView: () -> View
    ) -> (view: View, origin: HUDIndicator.Origin) {
        if let previous, let view = previous.view as? View {
            return (view, previous.origin)
        }
        return (createView(), .library)
    }

    private static func activityIndicator(reusing previous: HUDIndicator?) -> HUDIndicator {
        let (spinner, origin) = makeOrReuse(from: previous) { () -> UIActivityIndicatorView in
            let spinner = UIActivityIndicatorView(style: .large)
            spinner.color = .white
            return spinner
        }
        spinner.startAnimating()
        return HUDIndicator(
            view: spinner, origin: origin,
            progressUpdater: builtInProgressUpdater(for: spinner, origin: origin, libraryUpdater: nil),
            colorUpdater: HUDIndicatorColoring.activityUpdater(for: spinner))
    }

    private static func circularIndicator(reusing previous: HUDIndicator?, isAnnular: Bool) -> HUDIndicator {
        let (circle, origin) = makeOrReuse(from: previous) { TMRoundProgressView() }
        if circle.isAnnular != isAnnular {
            circle.isAnnular = isAnnular
        }
        return HUDIndicator(
            view: circle, origin: origin,
            progressUpdater: builtInProgressUpdater(
                for: circle, origin: origin, libraryUpdater: { circle.progress = $0 }),
            colorUpdater: HUDIndicatorColoring.circularUpdater(for: circle))
    }

    private static func barIndicator() -> HUDIndicator {
        let bar = TMBarProgressView()
        return HUDIndicator(
            view: bar, origin: .library, progressUpdater: { bar.progress = $0 },
            colorUpdater: HUDIndicatorColoring.barUpdater(for: bar))
    }

    private static func builtInProgressUpdater(
        for view: UIView, origin: HUDIndicator.Origin, libraryUpdater: HUDIndicator.ProgressUpdater?
    ) -> HUDIndicator.ProgressUpdater? {
        // Compatibility reuse retains the client view's declared or legacy progress contract.
        switch origin {
        case .library: libraryUpdater
        case .client: clientProgressUpdater(for: view, allowsLegacyProgress: true)
        }
    }

    private static func clientIndicator(for view: UIView, allowsLegacyProgress: Bool) -> HUDIndicator {
        HUDIndicator(
            view: view, origin: .client,
            progressUpdater: clientProgressUpdater(for: view, allowsLegacyProgress: allowsLegacyProgress),
            colorUpdater: clientColorUpdater(for: view))
    }

    private static func clientProgressUpdater(
        for view: UIView, allowsLegacyProgress: Bool
    ) -> HUDIndicator.ProgressUpdater? {
        switch view {
        case let reportingView as any TMProgressHudProgressReporting:
            return { reportingView.progress = $0 }
        case let circle as TMRoundProgressView:
            return { circle.progress = $0 }
        case let bar as TMBarProgressView:
            return { bar.progress = $0 }
        case let nativeProgressView as UIProgressView:
            return { nativeProgressView.progress = $0 }
        default:
            guard allowsLegacyProgress, let legacyAdapter = HUDLegacyProgressAdapter(view: view) else {
                return nil
            }
            return { legacyAdapter.updateProgress($0) }
        }
    }

    private static func clientColorUpdater(for view: UIView) -> HUDIndicator.ColorUpdater {
        switch view {
        case let circle as TMRoundProgressView:
            return HUDIndicatorColoring.circularUpdater(for: circle)
        case let bar as TMBarProgressView:
            return HUDIndicatorColoring.barUpdater(for: bar)
        case let spinner as UIActivityIndicatorView:
            return HUDIndicatorColoring.activityUpdater(for: spinner)
        default:
            return HUDIndicatorColoring.tintUpdater(for: view)
        }
    }
}
