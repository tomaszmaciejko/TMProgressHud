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
    /// Caller-provided content; the view is required.
    case custom(UIView)
    /// Labels and optional action without an indicator.
    case text

    var selection: (mode: TMProgressHudMode, customView: UIView?) {
        switch self {
        case .activity: (.indeterminate, nil)
        case .pie: (.determinate, nil)
        case .ring: (.annularDeterminate, nil)
        case .bar: (.determinateHorizontalBar, nil)
        case .custom(let view): (.customView, view)
        case .text: (.text, nil)
        }
    }
}
