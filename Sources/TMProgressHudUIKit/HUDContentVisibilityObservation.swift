// SPDX-License-Identifier: MIT
// Portions Copyright 2009-2020 Matej Bukovinski.
// Swift port Copyright 2026 Tomasz Maciejko and TMProgressHud contributors.
// Reference: 4a7c5f3e53cdea77c5dcb8578c2ee5acacdf6781. See THIRD_PARTY_NOTICES.md.
import UIKit

/// Keeps one visibility observation per content view, invalidating only its current container.
@MainActor
final class HUDContentVisibilityObservation {
    private weak var container: UIView?
    private var observedContent: [UIView] = []
    private var visibilityObservations: [NSKeyValueObservation] = []

    func update(content: [UIView], container: UIView) {
        let sameContent =
            observedContent.count == content.count
            && zip(observedContent, content).allSatisfy { $0.0 === $0.1 }
        guard self.container !== container || !sameContent else { return }
        for observation in visibilityObservations { observation.invalidate() }
        self.container = container
        observedContent = content
        visibilityObservations = content.map { view in
            view.observe(\.isHidden) { [weak container] _, _ in
                // KVO is synchronous with UIKit's main-actor-only isHidden setter.
                // Verify that executor before invalidating constraints; never defer the layout request.
                MainActor.assumeIsolated { container?.setNeedsUpdateConstraints() }
            }
        }
    }
}
