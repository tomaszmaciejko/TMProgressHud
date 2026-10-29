// SPDX-License-Identifier: MIT
// Portions Copyright 2009-2020 Matej Bukovinski.
// Swift port Copyright 2026 Tomasz Maciejko and TMProgressHud contributors.
// Reference: 4a7c5f3e53cdea77c5dcb8578c2ee5acacdf6781. See THIRD_PARTY_NOTICES.md.
import UIKit

/// Coordinates the installed layout and observes visibility without touching client constraints.
@MainActor
final class LayoutCoordinator {
    struct Configuration {
        let layout: TMProgressHudLayout
        let minimumSize: CGSize
        let isSquare: Bool
    }

    private var installedLayout: LayoutInstallation?
    private let visibilityObservation = ContentVisibilityObservation()

    /// Applies configuration to visible content, replacing the installation only when its container or bezel changes.
    ///
    /// Observes hidden content as well, so showing it can request a new constraint update.
    func update(container: UIView, bezel: UIView, content: [UIView], configuration: Configuration) {
        visibilityObservation.observeVisibility(of: content, invalidating: container)
        let visibleViews = visibleContent(in: content)
        let activeInstallation: LayoutInstallation
        if let installedLayout, installedLayout.matches(container: container, bezel: bezel) {
            activeInstallation = installedLayout
        } else {
            installedLayout?.deactivate()
            activeInstallation = LayoutInstallation(
                container: container, bezel: bezel, visibleContent: visibleViews)
            activeInstallation.activate()
            installedLayout = activeInstallation
        }
        activeInstallation.update(visibleContent: visibleViews, configuration: configuration)
    }

    /// Refreshes gaps after intrinsic content sizes change without rebuilding constraints.
    func updateInterItemSpacing() {
        installedLayout?.updateInterItemSpacing()
    }

    private func visibleContent(in content: [UIView]) -> [UIView] {
        content.filter { !$0.isHidden }
    }
}
