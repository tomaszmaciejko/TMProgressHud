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
        let previousIndicator = indicator
        managedIndicator = HUDIndicator.make(mode: mode, customView: customView, reusing: previousIndicator)
        if indicator !== previousIndicator {
            previousIndicator?.removeFromSuperview()
            if let indicator { bezelView.addSubview(indicator) }
            managedIndicator?.updateColor(contentColor)
        }
        indicator?.translatesAutoresizingMaskIntoConstraints = false
        forwardProgress()
        indicator?.setContentCompressionResistancePriority(HUDMetrics.contentPriority, for: .horizontal)
        indicator?.setContentCompressionResistancePriority(HUDMetrics.contentPriority, for: .vertical)
        setNeedsUpdateConstraints()
    }

    func forwardProgress() { managedIndicator?.updateProgress(progress) }

    func updateViewsForColor(_ color: UIColor?) {
        guard let color else { return }
        label.textColor = color
        detailsLabel.textColor = color
        button.setTitleColor(color, for: .normal)
        managedIndicator?.updateColor(color)
    }

    func updateBezelMotionEffects() {
        if areDefaultMotionEffectsEnabled {
            guard bezelMotionEffects == nil else { return }
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
