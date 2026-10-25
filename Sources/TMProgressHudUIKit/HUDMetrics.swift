// SPDX-License-Identifier: MIT
// Portions Copyright 2009-2020 Matej Bukovinski.
// Swift port Copyright 2026 Tomasz Maciejko and TMProgressHud contributors.
// Reference: 4a7c5f3e53cdea77c5dcb8578c2ee5acacdf6781. See THIRD_PARTY_NOTICES.md.
import UIKit

// Values from the pinned reference implementation, expressed in points/seconds.
// Float promotion preserves the original C f-suffixed alpha literal exactly.
enum HUDMetrics {
    static let margin: CGFloat = 20
    static let padding: CGFloat = 4
    static let titleFontSize: CGFloat = 16
    static let detailFontSize: CGFloat = 12
    static let contentAlpha: CGFloat = CGFloat(Float(0.7))
    static let remainingAlpha: CGFloat = 0.1
    static let bezelRadius: CGFloat = 5
    static let contentPriority = UILayoutPriority(998)
    static let sidePriority = UILayoutPriority(999)
    static let sizePriority = UILayoutPriority(997)
    static let motionOffset: CGFloat = 10
    static let animationDuration: TimeInterval = 0.3
    static let reducedScale: CGFloat = 0.5
    static let enlargedScale: CGFloat = 1.5
}
