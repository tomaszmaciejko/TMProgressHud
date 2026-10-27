// SPDX-License-Identifier: MIT
// Copyright 2026 Tomasz Maciejko and TMProgressHud contributors.
import UIKit

/// Builds complete indicators, keeping runtime capability detection at the client-view boundary.
@MainActor
enum HUDIndicatorFactory {
    enum SelectionContext {
        case completeSelection
        case compatibilityProperties
    }

    private enum ClientProgressContract {
        case typed
        case legacyCompatible
    }

    private enum ViewResolution<View: UIView> {
        case library(View)
        case compatibilityClient(View)

        var view: View {
            switch self {
            case .library(let view), .compatibilityClient(let view): view
            }
        }
    }

    /// A nil selection represents compatibility custom content without a view.
    static func make(
        for content: TMProgressHudContent?, reusing previous: HUDIndicator?, context: SelectionContext
    ) -> HUDIndicator? {
        guard let content else { return nil }
        let reusable = reusableView(from: previous, context: context)
        return buildIndicator(for: content, reusing: reusable)
    }

    private static func buildIndicator(
        for content: TMProgressHudContent, reusing previous: ViewResolution<UIView>?
    ) -> HUDIndicator? {
        switch content {
        case .activity: return activityIndicator(reusing: previous)
        case .outlinedCircle: return circularIndicator(reusing: previous, isAnnular: false)
        case .ring: return circularIndicator(reusing: previous, isAnnular: true)
        case .bar: return barIndicator()
        case .custom(let view): return clientIndicator(for: view, contract: .typed)
        case .legacyCustom(let view): return clientIndicator(for: view, contract: .legacyCompatible)
        case .text: return nil
        }
    }

    private static func reusableView(
        from previous: HUDIndicator?, context: SelectionContext
    ) -> ViewResolution<UIView>? {
        guard let previous else { return nil }
        switch previous.origin {
        case .library:
            return .library(previous.view)
        case .client:
            guard context == .compatibilityProperties else { return nil }
            return .compatibilityClient(previous.view)
        }
    }

    private static func makeOrReuse<View: UIView>(
        from previous: ViewResolution<UIView>?, createView: () -> View
    ) -> ViewResolution<View> {
        guard let previous, let view = previous.view as? View else {
            return .library(createView())
        }
        switch previous {
        case .library: return .library(view)
        case .compatibilityClient: return .compatibilityClient(view)
        }
    }

    private static func activityIndicator(reusing previous: ViewResolution<UIView>?) -> HUDIndicator {
        let resolved = makeOrReuse(from: previous) { () -> UIActivityIndicatorView in
            let spinner = UIActivityIndicatorView(style: .large)
            spinner.color = .white
            return spinner
        }
        let spinner = resolved.view
        spinner.startAnimating()
        return indicator(
            from: resolved, libraryProgressUpdater: nil,
            colorUpdater: HUDIndicatorColoring.activityUpdater(for: spinner))
    }

    private static func circularIndicator(
        reusing previous: ViewResolution<UIView>?, isAnnular: Bool
    ) -> HUDIndicator {
        let resolved = makeOrReuse(from: previous) { TMRoundProgressView() }
        let circle = resolved.view
        if circle.isAnnular != isAnnular {
            circle.isAnnular = isAnnular
        }
        return indicator(
            from: resolved, libraryProgressUpdater: { circle.progress = $0 },
            colorUpdater: HUDIndicatorColoring.circularUpdater(for: circle))
    }

    private static func barIndicator() -> HUDIndicator {
        let bar = TMBarProgressView()
        return HUDIndicator(
            view: bar, origin: .library, progressUpdater: { bar.progress = $0 },
            colorUpdater: HUDIndicatorColoring.barUpdater(for: bar))
    }

    private static func indicator<View: UIView>(
        from resolved: ViewResolution<View>, libraryProgressUpdater: HUDIndicator.ProgressUpdater?,
        colorUpdater: @escaping HUDIndicator.ColorUpdater
    ) -> HUDIndicator {
        switch resolved {
        case .library(let view):
            return HUDIndicator(
                view: view, origin: .library, progressUpdater: libraryProgressUpdater, colorUpdater: colorUpdater)
        case .compatibilityClient(let view):
            return clientIndicator(for: view, contract: .legacyCompatible, colorUpdater: colorUpdater)
        }
    }

    private static func clientIndicator(for view: UIView, contract: ClientProgressContract) -> HUDIndicator {
        clientIndicator(for: view, contract: contract, colorUpdater: clientColorUpdater(for: view))
    }

    private static func clientIndicator(
        for view: UIView, contract: ClientProgressContract, colorUpdater: @escaping HUDIndicator.ColorUpdater
    ) -> HUDIndicator {
        HUDIndicator(
            view: view, origin: .client,
            progressUpdater: clientProgressUpdater(for: view, contract: contract), colorUpdater: colorUpdater)
    }

    private static func clientProgressUpdater(
        for view: UIView, contract: ClientProgressContract
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
            return legacyProgressUpdater(for: view, contract: contract)
        }
    }

    private static func legacyProgressUpdater(
        for view: UIView, contract: ClientProgressContract
    ) -> HUDIndicator.ProgressUpdater? {
        guard contract == .legacyCompatible, let adapter = HUDLegacyProgressAdapter(view: view) else { return nil }
        return { adapter.updateProgress($0) }
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
