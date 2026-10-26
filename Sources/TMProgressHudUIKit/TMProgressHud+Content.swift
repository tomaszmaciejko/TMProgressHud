// SPDX-License-Identifier: MIT
// Portions Copyright 2009-2020 Matej Bukovinski.
// Swift port Copyright 2026 Tomasz Maciejko and TMProgressHud contributors.
// Reference: 4a7c5f3e53cdea77c5dcb8578c2ee5acacdf6781. See THIRD_PARTY_NOTICES.md.
import UIKit

extension TMProgressHud {
    /// Applies a complete content selection before notifying observers or updating the indicator.
    ///
    /// Non-custom selections release the retained custom view. Compatibility mode and customView getters
    /// reflect the selection; their KVO notifications are delivered after both values have been updated.
    public func setContent(_ content: TMProgressHudContent) {
        let selection = content.selection
        var changedKeys: [String] = []
        if contentSelection.mode != selection.mode { changedKeys.append(#keyPath(TMProgressHud.mode)) }
        if contentSelection.customView !== selection.customView {
            changedKeys.append(#keyPath(TMProgressHud.customView))
        }
        guard !changedKeys.isEmpty else { return }
        for key in changedKeys { willChangeValue(forKey: key) }
        contentSelection = selection
        updateIndicator()
        for key in changedKeys.reversed() { didChangeValue(forKey: key) }
    }

    func installContentViews() {
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

    func updateIndicator() {
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

    func forwardProgress() {
        managedIndicator?.updateProgress(progress)
    }

    func updateContentColor(_ color: UIColor?) {
        guard let color else { return }
        label.textColor = color
        detailsLabel.textColor = color
        button.setTitleColor(color, for: .normal)
        managedIndicator?.updateColor(color)
    }
}
