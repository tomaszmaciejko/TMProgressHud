// SPDX-License-Identifier: MIT
// Portions Copyright 2009-2020 Matej Bukovinski.
// Swift port Copyright 2026 Tomasz Maciejko and TMProgressHud contributors.
// Reference: 4a7c5f3e53cdea77c5dcb8578c2ee5acacdf6781. See THIRD_PARTY_NOTICES.md.
import UIKit

/// Owns the HUD's layout constraints and updates them without touching client constraints.
@MainActor
final class HUDLayout {
    struct Configuration {
        let offset: CGPoint
        let margin: CGFloat
        let minimumSize: CGSize
        let isSquare: Bool
    }

    private struct Gap {
        let preceding: UIView
        let following: UIView
        let constraint: NSLayoutConstraint
    }

    private let topSpacer = UIView()
    private let bottomSpacer = UIView()
    private weak var installedContainer: UIView?
    private weak var installedBezel: UIView?
    private var arrangedViews: [UIView] = []
    private var fixedConstraints: [NSLayoutConstraint] = []
    private var centeringConstraints: [NSLayoutConstraint] = []
    private var minimumMarginConstraints: [NSLayoutConstraint] = []
    private var maximumMarginConstraints: [NSLayoutConstraint] = []
    private var minimumSizeConstraints: [NSLayoutConstraint] = []
    private var squareConstraints: [NSLayoutConstraint] = []
    private var gaps: [Gap] = []

    init() {
        for spacer in [topSpacer, bottomSpacer] {
            spacer.translatesAutoresizingMaskIntoConstraints = false
            spacer.isHidden = true
        }
    }

    func update(container: UIView, bezel: UIView, content: [UIView], configuration: Configuration) {
        let views = [topSpacer] + content + [bottomSpacer]
        let sameContent =
            arrangedViews.count == views.count
            && zip(arrangedViews, views).allSatisfy { $0.0 === $0.1 }
        if installedContainer !== container || installedBezel !== bezel || !sameContent {
            install(container: container, bezel: bezel, views: views)
        }
        updateParameters(configuration)
        updatePadding()
    }

    func updatePadding() {
        var hasEarlierVisibleContent = false
        for gap in gaps {
            let precedingVisible = !gap.preceding.isHidden && gap.preceding.intrinsicContentSize != .zero
            let followingVisible = !gap.following.isHidden && gap.following.intrinsicContentSize != .zero
            gap.constraint.constant =
                followingVisible && (precedingVisible || hasEarlierVisibleContent) ? HUDMetrics.padding : 0
            hasEarlierVisibleContent = hasEarlierVisibleContent || precedingVisible
        }
    }

    private func install(container: UIView, bezel: UIView, views: [UIView]) {
        NSLayoutConstraint.deactivate(fixedConstraints + minimumSizeConstraints + squareConstraints)
        fixedConstraints = []
        minimumMarginConstraints = []
        maximumMarginConstraints = []
        gaps = []
        installedContainer = container
        installedBezel = bezel
        arrangedViews = views
        bezel.addSubview(topSpacer)
        bezel.addSubview(bottomSpacer)
        configureBezel(container: container, bezel: bezel)
        configureContent(views, bezel: bezel)
        let spacerHeights = [
            topSpacer.heightAnchor.constraint(greaterThanOrEqualToConstant: 0),
            bottomSpacer.heightAnchor.constraint(greaterThanOrEqualToConstant: 0),
        ]
        minimumMarginConstraints += spacerHeights
        fixedConstraints += spacerHeights
        fixedConstraints.append(topSpacer.heightAnchor.constraint(equalTo: bottomSpacer.heightAnchor))
        minimumSizeConstraints = [
            bezel.widthAnchor.constraint(greaterThanOrEqualToConstant: 0),
            bezel.heightAnchor.constraint(greaterThanOrEqualToConstant: 0),
        ]
        squareConstraints = [bezel.heightAnchor.constraint(equalTo: bezel.widthAnchor)]
        for constraint in minimumSizeConstraints + squareConstraints { constraint.priority = HUDMetrics.sizePriority }
        NSLayoutConstraint.activate(fixedConstraints)
    }

    private func configureBezel(container: UIView, bezel: UIView) {
        centeringConstraints = [
            bezel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            bezel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ]
        for constraint in centeringConstraints { constraint.priority = HUDMetrics.contentPriority }
        minimumMarginConstraints = [
            bezel.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor),
            bezel.topAnchor.constraint(greaterThanOrEqualTo: container.topAnchor),
        ]
        maximumMarginConstraints = [
            bezel.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor),
            bezel.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor),
        ]
        for constraint in minimumMarginConstraints + maximumMarginConstraints {
            constraint.priority = HUDMetrics.sidePriority
        }
        fixedConstraints += centeringConstraints + minimumMarginConstraints + maximumMarginConstraints
    }

    private func configureContent(_ views: [UIView], bezel: UIView) {
        for view in views {
            let leading = view.leadingAnchor.constraint(greaterThanOrEqualTo: bezel.leadingAnchor)
            let trailing = view.trailingAnchor.constraint(lessThanOrEqualTo: bezel.trailingAnchor)
            minimumMarginConstraints.append(leading)
            maximumMarginConstraints.append(trailing)
            fixedConstraints += [view.centerXAnchor.constraint(equalTo: bezel.centerXAnchor), leading, trailing]
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

    private func updateParameters(_ configuration: Configuration) {
        for (constraint, value) in zip(centeringConstraints, [configuration.offset.x, configuration.offset.y]) {
            constraint.constant = value
        }
        for constraint in minimumMarginConstraints { constraint.constant = configuration.margin }
        for constraint in maximumMarginConstraints { constraint.constant = -configuration.margin }
        for (constraint, value) in zip(
            minimumSizeConstraints, [configuration.minimumSize.width, configuration.minimumSize.height]
        ) {
            constraint.constant = value
            constraint.isActive = configuration.minimumSize != .zero
        }
        for constraint in squareConstraints { constraint.isActive = configuration.isSquare }
    }
}
