// SPDX-License-Identifier: MIT
// Copyright 2026 Tomasz Maciejko and TMProgressHud contributors.
import UIKit

/// Owns the view and the operations supported by one selected indicator.
@MainActor
struct HUDIndicator {
    let view: UIView
    private let receiveProgress: ((Float) -> Void)?
    private let receiveColor: (UIColor?) -> Void

    func updateProgress(_ progress: Float) { receiveProgress?(progress) }
    func updateColor(_ color: UIColor?) { receiveColor(color) }

    static func make(mode: TMProgressHudMode, customView: UIView?, reusing previous: UIView?) -> HUDIndicator? {
        switch mode {
        case .indeterminate:
            let spinner = previous as? UIActivityIndicatorView ?? UIActivityIndicatorView(style: .large)
            if spinner !== previous {
                spinner.color = .white
                spinner.startAnimating()
            }
            return spinnerIndicator(spinner)
        case .determinate, .annularDeterminate:
            let round = previous as? TMRoundProgressView ?? TMRoundProgressView()
            let annular = mode == .annularDeterminate
            if round.isAnnular != annular {
                round.isAnnular = annular
                round.setNeedsDisplay()
            }
            return roundIndicator(round)
        case .determinateHorizontalBar: return barIndicator(TMBarProgressView())
        case .customView: return customView.map(customIndicator)
        case .text: return nil
        }
    }

    private static func spinnerIndicator(_ view: UIActivityIndicatorView) -> HUDIndicator {
        HUDIndicator(view: view, receiveProgress: nil) { color in
            view.color =
                appearanceColor(#selector(getter: UIActivityIndicatorView.color), of: UIActivityIndicatorView.self)
                ?? color ?? view.color
        }
    }

    private static func roundIndicator(_ view: TMRoundProgressView) -> HUDIndicator {
        HUDIndicator(view: view, receiveProgress: { view.progress = $0 }) { color in
            view.progressTintColor =
                appearanceColor(
                    #selector(getter: TMRoundProgressView.progressTintColor), of: TMRoundProgressView.self)
                ?? color ?? view.progressTintColor
            view.backgroundTintColor =
                appearanceColor(
                    #selector(getter: TMRoundProgressView.backgroundTintColor), of: TMRoundProgressView.self)
                ?? color?.withAlphaComponent(HUDMetrics.remainingAlpha) ?? view.backgroundTintColor
        }
    }

    private static func barIndicator(_ view: TMBarProgressView) -> HUDIndicator {
        HUDIndicator(view: view, receiveProgress: { view.progress = $0 }) { color in
            view.progressColor =
                appearanceColor(#selector(getter: TMBarProgressView.progressColor), of: TMBarProgressView.self)
                ?? color ?? view.progressColor
            view.lineColor =
                appearanceColor(#selector(getter: TMBarProgressView.lineColor), of: TMBarProgressView.self)
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
        } else {
            receiveProgress = HUDLegacyProgressAdapter(view: view).map { adapter in
                { adapter.updateProgress($0) }
            }
        }
        return HUDIndicator(view: view, receiveProgress: receiveProgress) { color in
            if let color { view.tintColor = color }
        }
    }

    private static func appearanceColor(_ getter: Selector, of type: UIView.Type) -> UIColor? {
        let proxy = type.appearance(whenContainedInInstancesOf: [TMProgressHud.self])
        return proxy.perform(getter)?.takeUnretainedValue() as? UIColor
    }
}
