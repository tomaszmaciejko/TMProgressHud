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

    @MainActor
    private struct BezelConstraints {
        let centerX: NSLayoutConstraint
        let centerY: NSLayoutConstraint
        let minimumWidth: NSLayoutConstraint
        let minimumHeight: NSLayoutConstraint
        let square: NSLayoutConstraint

        var centering: [NSLayoutConstraint] { [centerX, centerY] }
        var sizing: [NSLayoutConstraint] { [minimumWidth, minimumHeight, square] }

        init(container: UIView, bezel: UIView) {
            centerX = bezel.centerXAnchor.constraint(equalTo: container.centerXAnchor)
            centerY = bezel.centerYAnchor.constraint(equalTo: container.centerYAnchor)
            minimumWidth = bezel.widthAnchor.constraint(greaterThanOrEqualToConstant: 0)
            minimumHeight = bezel.heightAnchor.constraint(greaterThanOrEqualToConstant: 0)
            square = bezel.heightAnchor.constraint(equalTo: bezel.widthAnchor)
            for constraint in centering { constraint.priority = HUDMetrics.contentPriority }
            for constraint in sizing { constraint.priority = HUDMetrics.sizePriority }
        }
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
    private var bezelConstraints: BezelConstraints?
    private var minimumMarginConstraints: [NSLayoutConstraint] = []
    private var maximumMarginConstraints: [NSLayoutConstraint] = []
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
        let constraints: BezelConstraints
        if installedContainer === container, installedBezel === bezel, sameContent, let existing = bezelConstraints {
            constraints = existing
        } else {
            constraints = install(container: container, bezel: bezel, views: views)
        }
        updateParameters(configuration, bezel: constraints)
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

    private func install(container: UIView, bezel: UIView, views: [UIView]) -> BezelConstraints {
        NSLayoutConstraint.deactivate(fixedConstraints + (bezelConstraints?.sizing ?? []))
        fixedConstraints = []
        minimumMarginConstraints = []
        maximumMarginConstraints = []
        gaps = []
        installedContainer = container
        installedBezel = bezel
        arrangedViews = views
        bezel.addSubview(topSpacer)
        bezel.addSubview(bottomSpacer)
        let constraints = configureBezel(container: container, bezel: bezel)
        configureContent(views, bezel: bezel)
        let spacerHeights = [
            topSpacer.heightAnchor.constraint(greaterThanOrEqualToConstant: 0),
            bottomSpacer.heightAnchor.constraint(greaterThanOrEqualToConstant: 0),
        ]
        minimumMarginConstraints += spacerHeights
        fixedConstraints += spacerHeights
        fixedConstraints.append(topSpacer.heightAnchor.constraint(equalTo: bottomSpacer.heightAnchor))
        NSLayoutConstraint.activate(fixedConstraints)
        bezelConstraints = constraints
        return constraints
    }

    private func configureBezel(container: UIView, bezel: UIView) -> BezelConstraints {
        let constraints = BezelConstraints(container: container, bezel: bezel)
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
        fixedConstraints += constraints.centering + minimumMarginConstraints + maximumMarginConstraints
        return constraints
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

    private func updateParameters(_ configuration: Configuration, bezel: BezelConstraints) {
        bezel.centerX.constant = configuration.offset.x
        bezel.centerY.constant = configuration.offset.y
        for constraint in minimumMarginConstraints {
            constraint.constant = configuration.margin
        }
        for constraint in maximumMarginConstraints {
            constraint.constant = -configuration.margin
        }
        bezel.minimumWidth.constant = configuration.minimumSize.width
        bezel.minimumHeight.constant = configuration.minimumSize.height
        let hasMinimumSize = configuration.minimumSize != .zero
        bezel.minimumWidth.isActive = hasMinimumSize
        bezel.minimumHeight.isActive = hasMinimumSize
        bezel.square.isActive = configuration.isSquare
    }
}
