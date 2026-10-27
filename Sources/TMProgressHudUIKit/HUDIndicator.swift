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
        case appearanceFirst
        case explicit
    }

    let view: UIView
    /// The view keeps its origin when compatibility setters reuse it in a built-in mode.
    let origin: Origin
    private let receiveProgress: ((Float) -> Void)?
    private let receiveColor: (UIColor?, ColorPolicy) -> Void

    func updateProgress(_ progress: Float) {
        receiveProgress?(progress)
    }
    func updateColor(_ color: UIColor?, policy: ColorPolicy = .appearanceFirst) {
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
                appearanceColor(
                    #selector(getter: UIActivityIndicatorView.color), of: UIActivityIndicatorView.self, policy: policy)
                ?? color ?? view.color
        }
    }

    private static func roundIndicator(_ view: TMRoundProgressView, origin: Origin) -> HUDIndicator {
        HUDIndicator(view: view, origin: origin, receiveProgress: { view.progress = $0 }) { color, policy in
            view.progressTintColor =
                appearanceColor(
                    #selector(getter: TMRoundProgressView.progressTintColor), of: TMRoundProgressView.self,
                    policy: policy)
                ?? color ?? view.progressTintColor
            view.backgroundTintColor =
                appearanceColor(
                    #selector(getter: TMRoundProgressView.backgroundTintColor), of: TMRoundProgressView.self,
                    policy: policy)
                ?? remainingColor(from: color, policy: policy) ?? view.backgroundTintColor
        }
    }

    private static func barIndicator(_ view: TMBarProgressView, origin: Origin) -> HUDIndicator {
        HUDIndicator(view: view, origin: origin, receiveProgress: { view.progress = $0 }) { color, policy in
            view.progressColor =
                appearanceColor(
                    #selector(getter: TMBarProgressView.progressColor), of: TMBarProgressView.self, policy: policy)
                ?? color ?? view.progressColor
            view.lineColor =
                appearanceColor(
                    #selector(getter: TMBarProgressView.lineColor), of: TMBarProgressView.self, policy: policy)
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

    private static func remainingColor(from color: UIColor?, policy: ColorPolicy) -> UIColor? {
        color.map { color in
            if case .appearanceFirst = policy {
                return color.withAlphaComponent(HUDMetrics.remainingAlpha)
            }
            return UIColor { traits in
                let resolved = color.resolvedColor(with: traits)
                return resolved.withAlphaComponent(resolved.cgColor.alpha * HUDMetrics.remainingAlpha)
            }
        }
    }

    private static func appearanceColor(_ getter: Selector, of type: UIView.Type, policy: ColorPolicy) -> UIColor? {
        if case .explicit = policy { return nil }
        let proxy = type.appearance(whenContainedInInstancesOf: [TMProgressHud.self])
        return proxy.perform(getter)?.takeUnretainedValue() as? UIColor
    }
}
