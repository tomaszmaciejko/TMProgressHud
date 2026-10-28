// SPDX-License-Identifier: MIT
// Portions Copyright 2009-2020 Matej Bukovinski.
// Swift port Copyright 2026 Tomasz Maciejko and TMProgressHud contributors.
// Reference: 4a7c5f3e53cdea77c5dcb8578c2ee5acacdf6781. See THIRD_PARTY_NOTICES.md.
import CoreGraphics

/// The indicator or content displayed by a HUD.
@objc public enum TMProgressHudMode: Int, Sendable {
    /// An indeterminate activity indicator.
    case indeterminate
    /// A circular pie-style progress indicator.
    case determinate
    /// A horizontal progress bar.
    case determinateHorizontalBar
    /// A ring-style progress indicator.
    case annularDeterminate
    /// The caller's custom view.
    case customView
    /// Labels and optional action without an indicator.
    case text
}

/// The appearance and dismissal transition.
@objc public enum TMProgressHudAnimation: Int, Sendable {
    /// Changes opacity only.
    case fade
    /// Zooms in on appearance and out on dismissal.
    case zoom
    /// Starts enlarged on appearance and shrinks on dismissal.
    case zoomOut
    /// Starts reduced on appearance and enlarges on dismissal.
    case zoomIn
}

/// A solid background or a visual-effect background.
@objc public enum TMProgressHudBackgroundStyle: Int, Sendable {
    /// A solid color.
    case solidColor
    /// A system blur effect.
    case blur
}

/// A completion invoked on the main actor when a presentation finishes hiding.
public typealias TMProgressHudCompletionBlock = @MainActor () -> Void

/// A signed offset sentinel that positions the bezel against the host's margin constraints.
public let TMProgressMaxOffset: CGFloat = 1_000_000
