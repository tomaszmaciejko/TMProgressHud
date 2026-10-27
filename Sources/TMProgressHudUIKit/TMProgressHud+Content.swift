// SPDX-License-Identifier: MIT
// Portions Copyright 2009-2020 Matej Bukovinski.
// Swift port Copyright 2026 Tomasz Maciejko and TMProgressHud contributors.
// Reference: 4a7c5f3e53cdea77c5dcb8578c2ee5acacdf6781. See THIRD_PARTY_NOTICES.md.
import UIKit

extension TMProgressHud {
    func configureView() {
        isOpaque = false
        backgroundColor = .clear
        alpha = 0
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        layer.allowsGroupOpacity = false
        installContentViews()
        updateIndicator(reusePolicy: .includingClientViews)
    }

    /// The current indicator selection, including compatibility getter overrides and its custom progress function.
    ///
    /// Nil represents compatibility custom mode without a view. Text, colors and progress remain independent.
    public var contentConfiguration: TMProgressHudContent? {
        let selectedMode = mode
        let selectedView = customView
        let updateProgress = selectedView === contentSelection.customView ? contentSelection.updateProgress : nil
        return .init(mode: selectedMode, customView: selectedView, updateProgress: updateProgress)
    }

    /// Applies a complete content selection and updates the indicator.
    ///
    /// Non-custom selections release the retained custom view. Compatibility mode and customView getters
    /// reflect the selection. Prior KVO notifications see the previous selection; post notifications
    /// see both updated values. A nested selection from a prior callback finishes before this write.
    /// Use post notifications to select subsequent content.
    public func setContent(_ content: TMProgressHudContent) {
        let selection = content.selection
        var changedKeys: [String] = []
        if contentSelection.mode != selection.mode { changedKeys.append(#keyPath(TMProgressHud.mode)) }
        if contentSelection.customView !== selection.customView {
            changedKeys.append(#keyPath(TMProgressHud.customView))
        }
        let updatesProgressFunction = contentSelection.updateProgress != nil || selection.updateProgress != nil
        let replacesCustomIndicator = selection.mode != .customView && managedIndicator?.origin == .client
        guard !changedKeys.isEmpty || updatesProgressFunction || replacesCustomIndicator else { return }
        for key in changedKeys { willChangeValue(forKey: key) }
        contentSelection = selection
        updateIndicator(reusePolicy: .libraryViewsOnly)
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
            item.numberOfLines = 0
            item.adjustsFontSizeToFitWidth = false
            item.adjustsFontForContentSizeCategory = true
            item.textAlignment = .center
            item.textColor = contentColor
            item.isOpaque = false
            item.backgroundColor = .clear
        }
        label.font = UIFontMetrics(forTextStyle: .headline).scaledFont(
            for: .boldSystemFont(ofSize: HUDMetrics.titleFontSize), compatibleWith: label.traitCollection)
        detailsLabel.font = UIFontMetrics(forTextStyle: .caption1).scaledFont(
            for: .boldSystemFont(ofSize: HUDMetrics.detailFontSize), compatibleWith: detailsLabel.traitCollection)
        button.titleLabel?.textAlignment = .center
        button.titleLabel?.lineBreakMode = .byTruncatingTail
        button.titleLabel?.font = UIFontMetrics(forTextStyle: .caption1).scaledFont(
            for: .boldSystemFont(ofSize: HUDMetrics.detailFontSize), compatibleWith: button.traitCollection)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.setTitleColor(contentColor, for: .normal)
    }

    func updateIndicator(reusePolicy: HUDIndicatorFactory.ReusePolicy) {
        let generation = UUID()
        indicatorUpdateGeneration = generation
        let previousIndicator = indicator
        let replacement = HUDIndicatorFactory.make(
            for: contentConfiguration, reusing: managedIndicator, reusePolicy: reusePolicy)
        // Client callbacks can select newer content during construction, installation or coloring.
        guard generation == indicatorUpdateGeneration else { return }
        managedIndicator = replacement
        guard installIndicator(replacement, replacing: previousIndicator, generation: generation) else { return }
        let view = replacement?.view
        view?.translatesAutoresizingMaskIntoConstraints = false
        view?.setContentCompressionResistancePriority(HUDMetrics.contentPriority, for: .horizontal)
        view?.setContentCompressionResistancePriority(HUDMetrics.contentPriority, for: .vertical)
        setNeedsUpdateConstraints()
        if view !== previousIndicator { replacement?.updateColor(contentColor) }
        guard generation == indicatorUpdateGeneration else { return }
        replacement?.updateProgress(progress)
    }

    private func installIndicator(_ replacement: HUDIndicator?, replacing previous: UIView?, generation: UUID) -> Bool {
        guard replacement?.view !== previous else { return true }
        previous?.removeFromSuperview()
        guard generation == indicatorUpdateGeneration else { return false }
        if let view = replacement?.view { bezelView.addSubview(view) }
        return generation == indicatorUpdateGeneration
    }

    func forwardProgress() {
        managedIndicator?.updateProgress(progress)
    }

    /// Recolors labels, the normal button title and the current indicator without changing its default color.
    ///
    /// Explicit coloring overrides the compatibility appearance proxy. A ring's remaining-area opacity
    /// is derived from the supplied color, including its alpha and appearance traits.
    public func applyContentColor(_ color: UIColor) {
        applyContentColor(color, policy: .explicit)
    }

    func updateContentColor(_ color: UIColor?) {
        guard let color else { return }
        applyContentColor(color, policy: .compatibility)
    }

    private func applyContentColor(_ color: UIColor, policy: HUDIndicator.ColorPolicy) {
        label.textColor = color
        detailsLabel.textColor = color
        button.setTitleColor(color, for: .normal)
        managedIndicator?.updateColor(color, policy: policy)
    }
}
