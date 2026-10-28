// SPDX-License-Identifier: MIT
// Portions Copyright 2009-2020 Matej Bukovinski.
// Swift port Copyright 2026 Tomasz Maciejko and TMProgressHud contributors.
// Reference: 4a7c5f3e53cdea77c5dcb8578c2ee5acacdf6781. See THIRD_PARTY_NOTICES.md.
import UIKit

/// Owns the content chain and its inner spacing independently of bezel placement.
@MainActor
final class HUDContentLayout {
    private struct HorizontalConstraints {
        let left: NSLayoutConstraint
        let right: NSLayoutConstraint
        let center: NSLayoutConstraint

        var all: [NSLayoutConstraint] { [center, left, right] }

        init(view: UIView, bezel: UIView) {
            left = view.leftAnchor.constraint(greaterThanOrEqualTo: bezel.leftAnchor)
            right = view.rightAnchor.constraint(lessThanOrEqualTo: bezel.rightAnchor)
            center = view.centerXAnchor.constraint(equalTo: bezel.centerXAnchor)
        }

        func update(_ insets: UIEdgeInsets) {
            left.constant = insets.left
            right.constant = -insets.right
            center.constant = (insets.left - insets.right) / 2
        }
    }

    private struct Gap {
        let preceding: UIView
        let following: UIView
        let constraint: NSLayoutConstraint
    }

    private let arrangedViews: [UIView]
    private let horizontalConstraints: [HorizontalConstraints]
    private let gaps: [Gap]
    private let boundaryConstraints: [NSLayoutConstraint]
    private let topPadding: NSLayoutConstraint
    private let bottomPadding: NSLayoutConstraint
    private let paddingBalance: NSLayoutConstraint

    private var allConstraints: [NSLayoutConstraint] {
        boundaryConstraints + [topPadding, bottomPadding, paddingBalance]
            + horizontalConstraints.flatMap(\.all) + gaps.map(\.constraint)
    }

    init(views: [UIView], bezel: UIView, topSpacer: UIView, bottomSpacer: UIView) {
        arrangedViews = views
        horizontalConstraints = views.map { HorizontalConstraints(view: $0, bezel: bezel) }
        gaps = zip(views, views.dropFirst()).map { preceding, following in
            Gap(
                preceding: preceding, following: following,
                constraint: following.topAnchor.constraint(equalTo: preceding.bottomAnchor))
        }
        boundaryConstraints = [
            topSpacer.topAnchor.constraint(equalTo: bezel.topAnchor),
            bottomSpacer.bottomAnchor.constraint(equalTo: bezel.bottomAnchor),
        ]
        topPadding = topSpacer.heightAnchor.constraint(greaterThanOrEqualToConstant: 0)
        bottomPadding = bottomSpacer.heightAnchor.constraint(greaterThanOrEqualToConstant: 0)
        paddingBalance = topSpacer.heightAnchor.constraint(equalTo: bottomSpacer.heightAnchor)
    }

    func matches(_ views: [UIView]) -> Bool {
        arrangedViews.count == views.count && zip(arrangedViews, views).allSatisfy { $0.0 === $0.1 }
    }

    func activate() {
        NSLayoutConstraint.activate(allConstraints)
    }

    func deactivate() {
        NSLayoutConstraint.deactivate(allConstraints)
    }

    func update(_ insets: UIEdgeInsets) {
        topPadding.constant = insets.top
        bottomPadding.constant = insets.bottom
        paddingBalance.constant = insets.top - insets.bottom
        for constraints in horizontalConstraints { constraints.update(insets) }
        updatePadding()
    }

    func updatePadding() {
        var hasEarlierVisibleContent = false
        for gap in gaps {
            let isPrecedingVisible = !gap.preceding.isHidden && gap.preceding.intrinsicContentSize != .zero
            let isFollowingVisible = !gap.following.isHidden && gap.following.intrinsicContentSize != .zero
            let needsPadding = isFollowingVisible && (isPrecedingVisible || hasEarlierVisibleContent)
            gap.constraint.constant = needsPadding ? HUDMetrics.padding : 0
            hasEarlierVisibleContent = hasEarlierVisibleContent || isPrecedingVisible
        }
    }

}
