// SPDX-License-Identifier: MIT
// Portions Copyright 2009-2020 Matej Bukovinski.
// Swift port Copyright 2026 Tomasz Maciejko and TMProgressHud contributors.
// Reference: 4a7c5f3e53cdea77c5dcb8578c2ee5acacdf6781. See THIRD_PARTY_NOTICES.md.
import UIKit

/// Owns the content chain and its inner spacing independently of bezel placement.
@MainActor
final class ContentLayout {
    private struct HorizontalConstraints {
        let left: NSLayoutConstraint
        let right: NSLayoutConstraint
        let center: NSLayoutConstraint

        var allConstraints: [NSLayoutConstraint] { [center, left, right] }

        init(view: UIView, bezel: UIView) {
            left = view.leftAnchor.constraint(greaterThanOrEqualTo: bezel.leftAnchor)
            right = view.rightAnchor.constraint(lessThanOrEqualTo: bezel.rightAnchor)
            center = view.centerXAnchor.constraint(equalTo: bezel.centerXAnchor)
        }

        func updateInsets(_ insets: UIEdgeInsets) {
            left.constant = insets.left
            right.constant = -insets.right
            // Center within the inset area using physical left/right edges.
            center.constant = (insets.left - insets.right) / 2
        }
    }

    private struct Gap {
        let following: UIView
        let constraint: NSLayoutConstraint
    }

    private let contentViews: [UIView]
    private let horizontalConstraints: [HorizontalConstraints]
    private let gaps: [Gap]
    private let boundaryConstraints: [NSLayoutConstraint]
    private let topPadding: NSLayoutConstraint
    private let bottomPadding: NSLayoutConstraint
    private let paddingBalance: NSLayoutConstraint

    private var allConstraints: [NSLayoutConstraint] {
        boundaryConstraints + [topPadding, bottomPadding, paddingBalance]
            + horizontalConstraints.flatMap(\.allConstraints) + gaps.map(\.constraint)
    }

    /// Builds inactive constraints for visible content and the installation-owned spacing views.
    init(visibleContent views: [UIView], bezel: UIView, topSpacer: UIView, bottomSpacer: UIView) {
        contentViews = views
        let arrangedViews = [topSpacer] + views + [bottomSpacer]
        horizontalConstraints = arrangedViews.map { HorizontalConstraints(view: $0, bezel: bezel) }
        gaps = zip(views, views.dropFirst()).map { preceding, following in
            Gap(
                following: following,
                constraint: following.topAnchor.constraint(equalTo: preceding.bottomAnchor))
        }
        var boundaries = [
            topSpacer.topAnchor.constraint(equalTo: bezel.topAnchor),
            bottomSpacer.bottomAnchor.constraint(equalTo: bezel.bottomAnchor),
        ]
        if let first = views.first, let last = views.last {
            boundaries += [
                first.topAnchor.constraint(equalTo: topSpacer.bottomAnchor),
                bottomSpacer.topAnchor.constraint(equalTo: last.bottomAnchor),
            ]
        } else {
            boundaries.append(bottomSpacer.topAnchor.constraint(equalTo: topSpacer.bottomAnchor))
        }
        boundaryConstraints = boundaries
        topPadding = topSpacer.heightAnchor.constraint(greaterThanOrEqualToConstant: 0)
        bottomPadding = bottomSpacer.heightAnchor.constraint(greaterThanOrEqualToConstant: 0)
        paddingBalance = topSpacer.heightAnchor.constraint(equalTo: bottomSpacer.heightAnchor)
    }

    /// Compares identity and order, allowing text and intrinsic sizes to change without rebuilding constraints.
    func hasSameVisibleContent(as views: [UIView]) -> Bool {
        contentViews.count == views.count && zip(contentViews, views).allSatisfy { $0.0 === $0.1 }
    }

    /// Activates only this content chain; its views must already share the bezel hierarchy.
    func activate() {
        NSLayoutConstraint.activate(allConstraints)
    }

    /// Deactivates this content chain without removing views or modifying client constraints.
    func deactivate() {
        NSLayoutConstraint.deactivate(allConstraints)
    }

    /// Applies inner insets and refreshes inter-item spacing without replacing constraints.
    func updateContentInsets(_ insets: UIEdgeInsets) {
        topPadding.constant = insets.top
        bottomPadding.constant = insets.bottom
        // Split extra vertical space evenly, preserving the requested top/bottom difference.
        paddingBalance.constant = insets.top - insets.bottom
        for constraints in horizontalConstraints { constraints.updateInsets(insets) }
        updateInterItemSpacing()
    }

    /// Adds one gap before each nonempty item after the first, skipping empty items in between.
    func updateInterItemSpacing() {
        guard let first = contentViews.first else { return }
        var hasEarlierContent = participatesInSpacing(first)
        for gap in gaps {
            let hasFollowingContent = participatesInSpacing(gap.following)
            gap.constraint.constant =
                hasEarlierContent && hasFollowingContent ? DefaultMetrics.Layout.interItemSpacing : 0
            hasEarlierContent = hasEarlierContent || hasFollowingContent
        }
    }

    private func participatesInSpacing(_ view: UIView) -> Bool {
        // No intrinsic metric still permits client constraints to size the view; only an exact zero is empty.
        !view.isHidden && view.intrinsicContentSize != .zero
    }
}
