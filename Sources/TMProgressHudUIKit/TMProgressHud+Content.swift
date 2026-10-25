// SPDX-License-Identifier: MIT
// Portions Copyright 2009-2020 Matej Bukovinski.
// Swift port Copyright 2026 Tomasz Maciejko and TMProgressHud contributors.
// Reference: 4a7c5f3e53cdea77c5dcb8578c2ee5acacdf6781. See THIRD_PARTY_NOTICES.md.
import UIKit

extension TMProgressHud {
    func setupViews() {
        backgroundView.frame = bounds
        backgroundView.style = .solidColor
        backgroundView.backgroundColor = .clear
        backgroundView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        backgroundView.alpha = 0
        addSubview(backgroundView)
        bezelView.translatesAutoresizingMaskIntoConstraints = false
        bezelView.layer.cornerRadius = HUDMetrics.bezelRadius
        bezelView.alpha = 0
        addSubview(bezelView)
        configureLabels()
        for view in [label, detailsLabel, button] {
            view.translatesAutoresizingMaskIntoConstraints = false
            view.setContentCompressionResistancePriority(HUDMetrics.contentPriority, for: .horizontal)
            view.setContentCompressionResistancePriority(HUDMetrics.contentPriority, for: .vertical)
            bezelView.addSubview(view)
        }
    }

    private func configureLabels() {
        for item in [label, detailsLabel] {
            item.adjustsFontSizeToFitWidth = false
            item.textAlignment = .center
            item.textColor = contentColor
            item.isOpaque = false
            item.backgroundColor = .clear
        }
        label.font = .boldSystemFont(ofSize: HUDMetrics.titleFontSize)
        detailsLabel.font = .boldSystemFont(ofSize: HUDMetrics.detailFontSize)
        detailsLabel.numberOfLines = 0
        button.titleLabel?.textAlignment = .center
        button.titleLabel?.font = .boldSystemFont(ofSize: HUDMetrics.detailFontSize)
        button.setTitleColor(contentColor, for: .normal)
    }

    func updateIndicators() {
        switch mode {
        case .indeterminate: updateSpinner()
        case .determinateHorizontalBar: replaceIndicator(with: TMBarProgressView())
        case .determinate, .annularDeterminate: updateRoundIndicator()
        case .customView:
            if customView !== indicator { replaceIndicator(with: customView) }
        case .text: replaceIndicator(with: nil)
        }
        indicator?.translatesAutoresizingMaskIntoConstraints = false
        forwardProgress()
        indicator?.setContentCompressionResistancePriority(HUDMetrics.contentPriority, for: .horizontal)
        indicator?.setContentCompressionResistancePriority(HUDMetrics.contentPriority, for: .vertical)
        updateViewsForColor(contentColor)
        setNeedsUpdateConstraints()
    }

    private func updateSpinner() {
        guard !(indicator is UIActivityIndicatorView) else { return }
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = .white
        spinner.startAnimating()
        replaceIndicator(with: spinner)
    }

    private func updateRoundIndicator() {
        if !(indicator is TMRoundProgressView) { replaceIndicator(with: TMRoundProgressView()) }
        if mode == .annularDeterminate { (indicator as? TMRoundProgressView)?.isAnnular = true }
    }

    private func replaceIndicator(with replacement: UIView?) {
        indicator?.removeFromSuperview()
        indicator = replacement
        if let replacement { bezelView.addSubview(replacement) }
    }

    func forwardProgress() {
        if let indicator, indicator.responds(to: NSSelectorFromString("setProgress:")) {
            indicator.setValue(progress, forKey: "progress")
        }
    }

    func updateViewsForColor(_ color: UIColor?) {
        guard let color else { return }
        label.textColor = color
        detailsLabel.textColor = color
        button.setTitleColor(color, for: .normal)
        if let spinner = indicator as? UIActivityIndicatorView {
            if appearanceColor(#selector(getter: UIActivityIndicatorView.color), of: UIActivityIndicatorView.self)
                == nil
            {
                spinner.color = color
            }
        } else if let round = indicator as? TMRoundProgressView {
            updateRoundColors(round, color: color)
        } else if let bar = indicator as? TMBarProgressView {
            updateBarColors(bar, color: color)
        } else {
            indicator?.tintColor = color
        }
    }

    private func appearanceColor(_ getter: Selector, of type: UIView.Type) -> UIColor? {
        let proxy = type.appearance(whenContainedInInstancesOf: [TMProgressHud.self])
        return proxy.perform(getter)?.takeUnretainedValue() as? UIColor
    }

    private func updateRoundColors(_ view: TMRoundProgressView, color: UIColor) {
        if appearanceColor(#selector(getter: TMRoundProgressView.progressTintColor), of: TMRoundProgressView.self)
            == nil
        {
            view.progressTintColor = color
        }
        if appearanceColor(#selector(getter: TMRoundProgressView.backgroundTintColor), of: TMRoundProgressView.self)
            == nil
        {
            view.backgroundTintColor = color.withAlphaComponent(HUDMetrics.remainingAlpha)
        }
    }

    private func updateBarColors(_ view: TMBarProgressView, color: UIColor) {
        if appearanceColor(#selector(getter: TMBarProgressView.progressColor), of: TMBarProgressView.self) == nil {
            view.progressColor = color
        }
        if appearanceColor(#selector(getter: TMBarProgressView.lineColor), of: TMBarProgressView.self) == nil {
            view.lineColor = color
        }
    }

    func updateBezelMotionEffects() {
        if areDefaultMotionEffectsEnabled && bezelMotionEffects == nil {
            let horizontal = motionEffect(key: "center.x", type: .tiltAlongHorizontalAxis)
            let vertical = motionEffect(key: "center.y", type: .tiltAlongVerticalAxis)
            let group = UIMotionEffectGroup()
            group.motionEffects = [horizontal, vertical]
            bezelMotionEffects = group
            bezelView.addMotionEffect(group)
        } else if let effects = bezelMotionEffects {
            bezelMotionEffects = nil
            bezelView.removeMotionEffect(effects)
        }
    }

    private func motionEffect(key: String, type: UIInterpolatingMotionEffect.EffectType) -> UIInterpolatingMotionEffect
    {
        let effect = UIInterpolatingMotionEffect(keyPath: key, type: type)
        effect.maximumRelativeValue = HUDMetrics.motionOffset
        effect.minimumRelativeValue = -HUDMetrics.motionOffset
        return effect
    }
}
