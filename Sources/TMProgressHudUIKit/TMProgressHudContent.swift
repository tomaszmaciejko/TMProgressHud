// SPDX-License-Identifier: MIT
// Copyright 2026 Tomasz Maciejko and TMProgressHud contributors.
import UIKit

/// A complete content selection, applied with TMProgressHud.setContent(_:).
@MainActor
public enum TMProgressHudContent {
    /// An animating activity indicator.
    case activity
    /// A circular pie progress indicator.
    case pie
    /// A circular ring progress indicator.
    case ring
    /// A horizontal progress bar.
    case bar
    /// Custom content with typed progress support; Objective-C setter guessing is disabled.
    case custom(UIView)
    /// Custom content that also opts into the legacy numeric Objective-C progress setter.
    case legacyCustom(UIView)
    /// Labels and optional action without an indicator.
    case text

    struct Selection {
        var mode: TMProgressHudMode
        var customView: UIView?
        var allowsLegacyProgress = true
    }

    var selection: Selection {
        switch self {
        case .activity: .init(mode: .indeterminate, customView: nil)
        case .pie: .init(mode: .determinate, customView: nil)
        case .ring: .init(mode: .annularDeterminate, customView: nil)
        case .bar: .init(mode: .determinateHorizontalBar, customView: nil)
        case .custom(let view): .init(mode: .customView, customView: view, allowsLegacyProgress: false)
        case .legacyCustom(let view): .init(mode: .customView, customView: view)
        case .text: .init(mode: .text, customView: nil)
        }
    }
}
