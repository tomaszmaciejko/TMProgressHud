// SPDX-License-Identifier: MIT
// Portions Copyright 2009-2020 Matej Bukovinski.
// Swift port Copyright 2026 Tomasz Maciejko and TMProgressHud contributors.
// Reference: 4a7c5f3e53cdea77c5dcb8578c2ee5acacdf6781. See THIRD_PARTY_NOTICES.md.
import UIKit

extension TMProgressHud {
    func rebuildConstraints() {
        removeConstraints(constraints)
        topSpacer.removeConstraints(topSpacer.constraints)
        bottomSpacer.removeConstraints(bottomSpacer.constraints)
        bezelView.removeConstraints(bezelConstraints)
        bezelConstraints = []
        constrainBezelToHost()
        constrainMinimumSize()
        if isSquare {
            let square = bezelView.heightAnchor.constraint(equalTo: bezelView.widthAnchor)
            square.priority = HUDMetrics.sizePriority
            bezelConstraints.append(square)
        }
        topSpacer.addConstraint(topSpacer.heightAnchor.constraint(greaterThanOrEqualToConstant: margin))
        bottomSpacer.addConstraint(bottomSpacer.heightAnchor.constraint(greaterThanOrEqualToConstant: margin))
        bezelConstraints.append(topSpacer.heightAnchor.constraint(equalTo: bottomSpacer.heightAnchor))
        var content = [topSpacer, label, detailsLabel, button, bottomSpacer]
        if let indicator { content.insert(indicator, at: 1) }
        constrainContent(content)
        bezelView.addConstraints(bezelConstraints)
        updatePaddingConstraints()
    }

    private func constrainBezelToHost() {
        let centering = [
            bezelView.centerXAnchor.constraint(equalTo: centerXAnchor, constant: offset.x),
            bezelView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: offset.y),
        ]
        for constraint in centering { constraint.priority = HUDMetrics.contentPriority }
        addConstraints(centering)
        let sides = [
            bezelView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: margin),
            bezelView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -margin),
            bezelView.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: margin),
            bezelView.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -margin),
        ]
        for constraint in sides { constraint.priority = HUDMetrics.sidePriority }
        addConstraints(sides)
    }

    private func constrainMinimumSize() {
        guard minSize != .zero else { return }
        let sizing = [
            bezelView.widthAnchor.constraint(greaterThanOrEqualToConstant: minSize.width),
            bezelView.heightAnchor.constraint(greaterThanOrEqualToConstant: minSize.height),
        ]
        for constraint in sizing { constraint.priority = HUDMetrics.sizePriority }
        bezelConstraints += sizing
    }

    private func constrainContent(_ content: [UIView]) {
        paddingConstraints = []
        for (index, view) in content.enumerated() {
            bezelConstraints += [
                view.centerXAnchor.constraint(equalTo: bezelView.centerXAnchor),
                view.leadingAnchor.constraint(greaterThanOrEqualTo: bezelView.leadingAnchor, constant: margin),
                view.trailingAnchor.constraint(lessThanOrEqualTo: bezelView.trailingAnchor, constant: -margin),
            ]
            if index == 0 {
                bezelConstraints.append(view.topAnchor.constraint(equalTo: bezelView.topAnchor))
            } else if index == content.count - 1 {
                bezelConstraints.append(view.bottomAnchor.constraint(equalTo: bezelView.bottomAnchor))
            }
            if index > 0 {
                let padding = view.topAnchor.constraint(equalTo: content[index - 1].bottomAnchor)
                bezelConstraints.append(padding)
                paddingConstraints.append(padding)
            }
        }
    }

    func updatePaddingConstraints() {
        var hasVisibleAncestors = false
        for padding in paddingConstraints {
            guard let first = padding.firstItem as? UIView, let second = padding.secondItem as? UIView else { continue }
            let firstVisible = !first.isHidden && first.intrinsicContentSize != .zero
            let secondVisible = !second.isHidden && second.intrinsicContentSize != .zero
            padding.constant = firstVisible && (secondVisible || hasVisibleAncestors) ? HUDMetrics.padding : 0
            hasVisibleAncestors = hasVisibleAncestors || secondVisible
        }
    }
}
