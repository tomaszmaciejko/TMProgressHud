// SPDX-License-Identifier: MIT
// Portions Copyright 2009-2020 Matej Bukovinski.
// Swift port Copyright 2026 Tomasz Maciejko and TMProgressHud contributors.
// Reference: 4a7c5f3e53cdea77c5dcb8578c2ee5acacdf6781. See THIRD_PARTY_NOTICES.md.
import UIKit

/// Owns bezel positioning, sizing and spacer padding constraints.
@MainActor
struct HUDBezelConstraints {
    let left: NSLayoutConstraint
    let centerX: NSLayoutConstraint
    let right: NSLayoutConstraint
    let top: NSLayoutConstraint
    let centerY: NSLayoutConstraint
    let bottom: NSLayoutConstraint
    let minimumWidth: NSLayoutConstraint
    let minimumHeight: NSLayoutConstraint
    let square: NSLayoutConstraint
    let outerLeft: NSLayoutConstraint
    let outerRight: NSLayoutConstraint
    let outerTop: NSLayoutConstraint
    let outerBottom: NSLayoutConstraint
    let topPadding: NSLayoutConstraint
    let bottomPadding: NSLayoutConstraint
    let paddingBalance: NSLayoutConstraint

    var positioning: [NSLayoutConstraint] { [left, centerX, right, top, centerY, bottom] }
    var sizing: [NSLayoutConstraint] { [minimumWidth, minimumHeight, square] }
    var outerEdges: [NSLayoutConstraint] { [outerLeft, outerRight, outerTop, outerBottom] }
    var padding: [NSLayoutConstraint] { [topPadding, bottomPadding, paddingBalance] }

    init(container: UIView, bezel: UIView, topSpacer: UIView, bottomSpacer: UIView) {
        left = bezel.leftAnchor.constraint(equalTo: container.leftAnchor)
        centerX = bezel.centerXAnchor.constraint(equalTo: container.centerXAnchor)
        right = bezel.rightAnchor.constraint(equalTo: container.rightAnchor)
        top = bezel.topAnchor.constraint(equalTo: container.topAnchor)
        centerY = bezel.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        bottom = bezel.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        minimumWidth = bezel.widthAnchor.constraint(greaterThanOrEqualToConstant: 0)
        minimumHeight = bezel.heightAnchor.constraint(greaterThanOrEqualToConstant: 0)
        square = bezel.heightAnchor.constraint(equalTo: bezel.widthAnchor)
        outerLeft = bezel.leftAnchor.constraint(greaterThanOrEqualTo: container.leftAnchor)
        outerRight = bezel.rightAnchor.constraint(lessThanOrEqualTo: container.rightAnchor)
        outerTop = bezel.topAnchor.constraint(greaterThanOrEqualTo: container.topAnchor)
        outerBottom = bezel.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor)
        topPadding = topSpacer.heightAnchor.constraint(greaterThanOrEqualToConstant: 0)
        bottomPadding = bottomSpacer.heightAnchor.constraint(greaterThanOrEqualToConstant: 0)
        paddingBalance = topSpacer.heightAnchor.constraint(equalTo: bottomSpacer.heightAnchor)
        for constraint in positioning { constraint.priority = HUDMetrics.contentPriority }
        for constraint in sizing { constraint.priority = HUDMetrics.sizePriority }
        for constraint in outerEdges { constraint.priority = HUDMetrics.sidePriority }
    }

    func update(_ configuration: HUDLayout.Configuration) {
        let layout = configuration.layout
        let insets = layout.hostInsets
        outerLeft.constant = insets.left
        outerRight.constant = -insets.right
        outerTop.constant = insets.top
        outerBottom.constant = -insets.bottom
        topPadding.constant = layout.contentInsets.top
        bottomPadding.constant = layout.contentInsets.bottom
        paddingBalance.constant = layout.contentInsets.top - layout.contentInsets.bottom
        updatePosition(layout.position, insets: insets)
        minimumWidth.constant = configuration.minimumSize.width
        minimumHeight.constant = configuration.minimumSize.height
        let hasMinimumSize = configuration.minimumSize != .zero
        minimumWidth.isActive = hasMinimumSize
        minimumHeight.isActive = hasMinimumSize
        square.isActive = configuration.isSquare
    }

    private func updatePosition(_ position: TMProgressHudPosition, insets: UIEdgeInsets) {
        left.constant = insets.left + position.offset.x
        centerX.constant = position.offset.x
        right.constant = -insets.right + position.offset.x
        top.constant = insets.top + position.offset.y
        centerY.constant = position.offset.y
        bottom.constant = -insets.bottom + position.offset.y
        left.isActive = position.horizontal == .left
        centerX.isActive = position.horizontal == .center
        right.isActive = position.horizontal == .right
        top.isActive = position.vertical == .top
        centerY.isActive = position.vertical == .center
        bottom.isActive = position.vertical == .bottom
    }
}
