// SPDX-License-Identifier: MIT
// Portions Copyright 2009-2020 Matej Bukovinski.
// Swift port Copyright 2026 Tomasz Maciejko and TMProgressHud contributors.
// Reference: 4a7c5f3e53cdea77c5dcb8578c2ee5acacdf6781. See THIRD_PARTY_NOTICES.md.
import UIKit

/// Coordinates the installed layout and observes visibility without touching client constraints.
@MainActor
final class HUDLayout {
    struct Configuration {
        let layout: TMProgressHudLayout
        let minimumSize: CGSize
        let isSquare: Bool
    }

    private let topSpacer = UIView()
    private let bottomSpacer = UIView()
    private var installation: HUDLayoutInstallation?
    private let visibilityObservation = HUDContentVisibilityObservation()

    init() {
        for spacer in [topSpacer, bottomSpacer] {
            spacer.translatesAutoresizingMaskIntoConstraints = false
            spacer.isHidden = true
        }
    }

    func update(container: UIView, bezel: UIView, content: [UIView], configuration: Configuration) {
        visibilityObservation.update(content: content, container: container)
        let views = visibleContent(in: content)
        let current: HUDLayoutInstallation
        if let installation, installation.matches(container: container, bezel: bezel) {
            current = installation
        } else {
            installation?.deactivate()
            current = HUDLayoutInstallation(
                container: container, bezel: bezel, views: views, topSpacer: topSpacer, bottomSpacer: bottomSpacer)
            installation = current
        }
        current.update(content: views, in: bezel, configuration: configuration)
    }

    func updateInterItemSpacing() {
        installation?.updateInterItemSpacing()
    }

    private func visibleContent(in content: [UIView]) -> [UIView] {
        content.filter { !$0.isHidden }
    }
}
