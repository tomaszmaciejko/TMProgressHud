// SPDX-License-Identifier: MIT
// Copyright 2026 Tomasz Maciejko and TMProgressHud contributors.
import UIKit

/// Owns the view and the operations supported by one selected indicator.
@MainActor
struct HUDIndicator {
    enum ColorPolicy {
        case appearanceFirst
        case explicit
    }

    let view: UIView
    private let receiveProgress: ((Float) -> Void)?
    private let receiveColor: (UIColor?, ColorPolicy) -> Void

    func updateProgress(_ progress: Float) {
        receiveProgress?(progress)
    }
    func updateColor(_ color: UIColor?, policy: ColorPolicy = .appearanceFirst) {
        receiveColor(color, policy)
    }

    static func make(mode: TMProgressHudMode, customView: UIView?, reusing previous: UIView?) -> HUDIndicator? {
        switch mode {
        case .indeterminate:
            let spinner = previous as? UIActivityIndicatorView ?? UIActivityIndicatorView(style: .large)
            if spinner !== previous {
                spinner.color = .white
            }
            spinner.startAnimating()
            return spinnerIndicator(spinner)
        case .determinate, .annularDeterminate:
            let round = previous as? TMRoundProgressView ?? TMRoundProgressView()
            let annular = mode == .annularDeterminate
            if round.isAnnular != annular {
                round.isAnnular = annular
            }
            return roundIndicator(round)
        case .determinateHorizontalBar: return barIndicator(TMBarProgressView())
        case .customView: return customView.map(customIndicator)
        case .text: return nil
        }
    }

    private static func spinnerIndicator(_ view: UIActivityIndicatorView) -> HUDIndicator {
        HUDIndicator(view: view, receiveProgress: nil) { color, policy in
            view.color =
                appearanceColor(
                    #selector(getter: UIActivityIndicatorView.color), of: UIActivityIndicatorView.self, policy: policy)
                ?? color ?? view.color
        }
    }

    private static func roundIndicator(_ view: TMRoundProgressView) -> HUDIndicator {
        HUDIndicator(view: view, receiveProgress: { view.progress = $0 }) { color, policy in
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

    private static func barIndicator(_ view: TMBarProgressView) -> HUDIndicator {
        HUDIndicator(view: view, receiveProgress: { view.progress = $0 }) { color, policy in
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

    private static func customIndicator(_ view: UIView) -> HUDIndicator {
        if let round = view as? TMRoundProgressView { return roundIndicator(round) }
        if let bar = view as? TMBarProgressView { return barIndicator(bar) }
        if let spinner = view as? UIActivityIndicatorView { return spinnerIndicator(spinner) }
        let receiveProgress: ((Float) -> Void)?
        if let reporting = view as? any TMProgressHudProgressReporting {
            receiveProgress = { reporting.progress = $0 }
        } else if let adapter = HUDLegacyProgressAdapter(view: view) {
            receiveProgress = { adapter.updateProgress($0) }
        } else {
            receiveProgress = nil
        }
        return HUDIndicator(view: view, receiveProgress: receiveProgress) { color, _ in
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
