// SPDX-License-Identifier: MIT
// Copyright 2026 Tomasz Maciejko and TMProgressHud contributors.
import UIKit

/// An indicator selection, applied with TMProgressHud.setContent(_:).
@MainActor
public enum TMProgressHudContent {
    /// An animating activity indicator.
    case activity
    /// A circular outline with a progress arc.
    case outlinedCircle
    /// A circular ring progress indicator.
    case ring
    /// A horizontal progress bar.
    case bar
    /// Custom content with an optional main-actor function receiving raw progress synchronously.
    ///
    /// The function takes precedence over TMProgressHudProgressReporting and recognized native indicators.
    /// Without a function, those typed contracts are used. The HUD retains the view and function;
    /// capture an owner weakly if it also owns the HUD. Selecting a function always reapplies current progress.
    case custom(UIView, updateProgress: (@MainActor (Float) -> Void)? = nil)
    /// Labels and optional action without an indicator.
    case text

    struct Selection {
        var mode: TMProgressHudMode
        var customView: UIView?
        var updateProgress: (@MainActor (Float) -> Void)?
    }

    init?(mode: TMProgressHudMode, customView: UIView?, updateProgress: (@MainActor (Float) -> Void)?) {
        switch mode {
        case .indeterminate: self = .activity
        case .determinate: self = .outlinedCircle
        case .annularDeterminate: self = .ring
        case .determinateHorizontalBar: self = .bar
        case .text: self = .text
        case .customView:
            guard let customView else { return nil }
            self = .custom(customView, updateProgress: updateProgress)
        }
    }

    var selection: Selection {
        switch self {
        case .activity: .init(mode: .indeterminate, customView: nil)
        case .outlinedCircle: .init(mode: .determinate, customView: nil)
        case .ring: .init(mode: .annularDeterminate, customView: nil)
        case .bar: .init(mode: .determinateHorizontalBar, customView: nil)
        case .custom(let view, let updateProgress):
            .init(mode: .customView, customView: view, updateProgress: updateProgress)
        case .text: .init(mode: .text, customView: nil)
        }
    }
}
