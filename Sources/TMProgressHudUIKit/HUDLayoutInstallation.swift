// SPDX-License-Identifier: MIT
// Portions Copyright 2009-2020 Matej Bukovinski.
// Swift port Copyright 2026 Tomasz Maciejko and TMProgressHud contributors.
// Reference: 4a7c5f3e53cdea77c5dcb8578c2ee5acacdf6781. See THIRD_PARTY_NOTICES.md.
import UIKit

/// Owns bezel constraints and replaces only the content layout when arranged views change.
@MainActor
final class HUDLayoutInstallation {
    private weak var container: UIView?
    private weak var bezel: UIView?
    private let topSpacer: UIView
    private let bottomSpacer: UIView
    private let bezelConstraints: HUDBezelConstraints
    private var contentLayout: HUDContentLayout

    init(container: UIView, bezel: UIView, views: [UIView], topSpacer: UIView, bottomSpacer: UIView) {
        self.container = container
        self.bezel = bezel
        self.topSpacer = topSpacer
        self.bottomSpacer = bottomSpacer
        bezel.addSubview(topSpacer)
        bezel.addSubview(bottomSpacer)
        bezelConstraints = HUDBezelConstraints(container: container, bezel: bezel)
        contentLayout = HUDContentLayout(views: views, bezel: bezel, topSpacer: topSpacer, bottomSpacer: bottomSpacer)
        NSLayoutConstraint.activate(bezelConstraints.outerEdges)
        contentLayout.activate()
    }

    func matches(container: UIView, bezel: UIView) -> Bool {
        self.container === container && self.bezel === bezel
    }

    func deactivate() {
        contentLayout.deactivate()
        NSLayoutConstraint.deactivate(
            bezelConstraints.outerEdges + bezelConstraints.positioning + bezelConstraints.sizing)
    }

    func update(content views: [UIView], in bezel: UIView, configuration: HUDLayout.Configuration) {
        if !contentLayout.matches(views) {
            contentLayout.deactivate()
            contentLayout = HUDContentLayout(
                views: views, bezel: bezel, topSpacer: topSpacer, bottomSpacer: bottomSpacer)
            contentLayout.activate()
        }
        bezelConstraints.update(configuration)
        contentLayout.update(configuration.layout.contentInsets)
    }

    func updateInterItemSpacing() {
        contentLayout.updateInterItemSpacing()
    }
}
