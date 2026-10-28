// SPDX-License-Identifier: MIT
// Portions Copyright 2009-2020 Matej Bukovinski.
// Swift port Copyright 2026 Tomasz Maciejko and TMProgressHud contributors.
// Reference: 4a7c5f3e53cdea77c5dcb8578c2ee5acacdf6781. See THIRD_PARTY_NOTICES.md.
import UIKit

/// A complete installed constraint set, replaced as a unit when the hierarchy or arranged views change.
@MainActor
final class HUDLayoutInstallation {
    private weak var container: UIView?
    private weak var bezel: UIView?
    private let arrangedViews: [UIView]
    private let bezelConstraints: HUDBezelConstraints
    private var fixedConstraints: [NSLayoutConstraint] = []
    private var contentLeftConstraints: [NSLayoutConstraint] = []
    private var contentRightConstraints: [NSLayoutConstraint] = []
    private var contentCenterConstraints: [NSLayoutConstraint] = []
    private var gaps: [Gap] = []

    private struct Gap {
        let preceding: UIView
        let following: UIView
        let constraint: NSLayoutConstraint
    }

    init(container: UIView, bezel: UIView, views: [UIView], topSpacer: UIView, bottomSpacer: UIView) {
        self.container = container
        self.bezel = bezel
        arrangedViews = views
        bezel.addSubview(topSpacer)
        bezel.addSubview(bottomSpacer)
        bezelConstraints = HUDBezelConstraints(
            container: container, bezel: bezel, topSpacer: topSpacer, bottomSpacer: bottomSpacer)
        fixedConstraints = bezelConstraints.outerEdges + bezelConstraints.padding
        configureContent(views, bezel: bezel, topSpacer: topSpacer, bottomSpacer: bottomSpacer)
        NSLayoutConstraint.activate(fixedConstraints)
    }

    func matches(container: UIView, bezel: UIView, views: [UIView]) -> Bool {
        self.container === container && self.bezel === bezel
            && arrangedViews.count == views.count
            && zip(arrangedViews, views).allSatisfy { $0.0 === $0.1 }
    }

    func deactivate() {
        NSLayoutConstraint.deactivate(fixedConstraints + bezelConstraints.positioning + bezelConstraints.sizing)
    }

    func update(_ configuration: HUDLayout.Configuration) {
        bezelConstraints.update(configuration)
        updateContentInsets(configuration.layout.contentInsets)
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

    private func configureContent(_ views: [UIView], bezel: UIView, topSpacer: UIView, bottomSpacer: UIView) {
        for view in views {
            let left = view.leftAnchor.constraint(greaterThanOrEqualTo: bezel.leftAnchor)
            let right = view.rightAnchor.constraint(lessThanOrEqualTo: bezel.rightAnchor)
            let center = view.centerXAnchor.constraint(equalTo: bezel.centerXAnchor)
            contentLeftConstraints.append(left)
            contentRightConstraints.append(right)
            contentCenterConstraints.append(center)
            fixedConstraints += [center, left, right]
        }
        fixedConstraints += [
            topSpacer.topAnchor.constraint(equalTo: bezel.topAnchor),
            bottomSpacer.bottomAnchor.constraint(equalTo: bezel.bottomAnchor),
        ]
        for (preceding, following) in zip(views, views.dropFirst()) {
            let constraint = following.topAnchor.constraint(equalTo: preceding.bottomAnchor)
            fixedConstraints.append(constraint)
            gaps.append(Gap(preceding: preceding, following: following, constraint: constraint))
        }
    }

    private func updateContentInsets(_ insets: UIEdgeInsets) {
        for constraint in contentLeftConstraints { constraint.constant = insets.left }
        for constraint in contentRightConstraints { constraint.constant = -insets.right }
        for constraint in contentCenterConstraints { constraint.constant = (insets.left - insets.right) / 2 }
    }
}
