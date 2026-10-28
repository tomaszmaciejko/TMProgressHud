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
    private var observedContent: [UIView] = []
    private var visibilityObservations: [NSKeyValueObservation] = []

    init() {
        for spacer in [topSpacer, bottomSpacer] {
            spacer.translatesAutoresizingMaskIntoConstraints = false
            spacer.isHidden = true
        }
    }

    func update(container: UIView, bezel: UIView, content: [UIView], configuration: Configuration) {
        observeVisibility(of: content, in: container)
        let views = visibleViews(in: content)
        let current: HUDLayoutInstallation
        if let installation, installation.matches(container: container, bezel: bezel, views: views) {
            current = installation
        } else {
            installation?.deactivate()
            current = HUDLayoutInstallation(
                container: container, bezel: bezel, views: views, topSpacer: topSpacer, bottomSpacer: bottomSpacer)
            installation = current
        }
        current.update(configuration)
    }

    func updatePadding() {
        installation?.updatePadding()
    }

    private func observeVisibility(of content: [UIView], in container: UIView) {
        let sameContent =
            observedContent.count == content.count
            && zip(observedContent, content).allSatisfy { $0.0 === $0.1 }
        guard !sameContent else { return }
        for observation in visibilityObservations { observation.invalidate() }
        observedContent = content
        visibilityObservations = content.map { view in
            view.observe(\.isHidden) { [weak container] _, _ in
                // KVO is synchronous with UIKit's main-actor-only isHidden setter.
                // Verify that executor before invalidating constraints; never defer the layout request.
                MainActor.assumeIsolated { container?.setNeedsUpdateConstraints() }
            }
        }
    }

    private func visibleViews(in content: [UIView]) -> [UIView] {
        [topSpacer] + content.filter { !$0.isHidden } + [bottomSpacer]
    }

}
