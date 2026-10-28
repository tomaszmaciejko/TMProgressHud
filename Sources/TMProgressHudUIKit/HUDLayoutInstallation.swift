// SPDX-License-Identifier: MIT
// Portions Copyright 2009-2020 Matej Bukovinski.
// Swift port Copyright 2026 Tomasz Maciejko and TMProgressHud contributors.
// Reference: 4a7c5f3e53cdea77c5dcb8578c2ee5acacdf6781. See THIRD_PARTY_NOTICES.md.
import UIKit

/// Owns a bezel's prepared constraints and invisible spacing views for one container/bezel pair.
@MainActor
final class HUDLayoutInstallation {
    private weak var container: UIView?
    private weak var bezel: UIView?
    private let topSpacer = UIView()
    private let bottomSpacer = UIView()
    private let bezelConstraints: HUDBezelConstraints
    private var contentLayout: HUDContentLayout

    /// Prepares inactive constraints and owned spacing views without changing the supplied hierarchy.
    init(container: UIView, bezel: UIView, visibleContent: [UIView]) {
        self.container = container
        self.bezel = bezel
        for spacer in [topSpacer, bottomSpacer] {
            spacer.translatesAutoresizingMaskIntoConstraints = false
            // Invisible spacing views distribute vertical room above and below the content.
            spacer.isHidden = true
        }
        bezelConstraints = HUDBezelConstraints(container: container, bezel: bezel)
        contentLayout = HUDContentLayout(
            visibleContent: visibleContent, bezel: bezel, topSpacer: topSpacer, bottomSpacer: bottomSpacer)
    }

    /// Compares the bound view identities; content and configuration do not affect installation reuse.
    func matches(container: UIView, bezel: UIView) -> Bool {
        self.container === container && self.bezel === bezel
    }

    /// Inserts the owned spacing views and activates edge/content constraints if the bezel still exists.
    ///
    /// Call update afterward to apply position, size preferences and content insets.
    func activate() {
        guard let bezel else { return }
        bezel.addSubview(topSpacer)
        bezel.addSubview(bottomSpacer)
        NSLayoutConstraint.activate(bezelConstraints.outerEdges)
        contentLayout.activate()
    }

    /// Deactivates owned constraints and removes owned spacing views, preserving all client views and constraints.
    func deactivate() {
        contentLayout.deactivate()
        NSLayoutConstraint.deactivate(
            bezelConstraints.outerEdges + bezelConstraints.positioning + bezelConstraints.sizing)
        topSpacer.removeFromSuperview()
        bottomSpacer.removeFromSuperview()
    }

    /// Applies position, sizing, content insets and spacing, rebuilding only changed visible content.
    ///
    /// Does nothing after the bound bezel is released; activate before updating a new installation.
    func update(visibleContent visibleViews: [UIView], configuration: HUDLayout.Configuration) {
        guard let bezel else { return }
        if !contentLayout.hasSameVisibleContent(as: visibleViews) {
            contentLayout.deactivate()
            contentLayout = HUDContentLayout(
                visibleContent: visibleViews, bezel: bezel, topSpacer: topSpacer, bottomSpacer: bottomSpacer)
            contentLayout.activate()
        }
        bezelConstraints.update(configuration)
        contentLayout.updateContentInsets(configuration.layout.contentInsets)
    }

    /// Refreshes inter-item gaps using current content sizes, preserving the installed constraints.
    func updateInterItemSpacing() {
        contentLayout.updateInterItemSpacing()
    }
}
