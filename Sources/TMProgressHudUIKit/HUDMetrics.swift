// SPDX-License-Identifier: MIT
// Portions Copyright 2009-2020 Matej Bukovinski.
// Swift port Copyright 2026 Tomasz Maciejko and TMProgressHud contributors.
// Reference: 4a7c5f3e53cdea77c5dcb8578c2ee5acacdf6781. See THIRD_PARTY_NOTICES.md.
import UIKit

// Shared layout, appearance and presentation defaults.
enum HUDMetrics {
    static let margin: CGFloat = 20
    static let padding: CGFloat = 4
    static let titleFontSize: CGFloat = 16
    static let detailFontSize: CGFloat = 12
    static let contentAlpha: CGFloat = 0.7
    static let remainingAlpha: CGFloat = 0.1
    static let bezelRadius: CGFloat = 5
    // Outer margins win over centering; optional size preferences yield first in a small host.
    static let contentPriority = UILayoutPriority(998)
    static let sidePriority = UILayoutPriority(999)
    static let sizePriority = UILayoutPriority(997)
    static let motionOffset: CGFloat = 10
    // Perceived duration in seconds; the spring may settle after this interval.
    static let animationPerceivedDuration: TimeInterval = 0.3
    static let reducedScale: CGFloat = 0.5
    static let enlargedScale: CGFloat = 1.5
}
