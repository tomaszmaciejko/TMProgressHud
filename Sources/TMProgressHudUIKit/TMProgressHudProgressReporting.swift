// SPDX-License-Identifier: MIT
// Copyright 2026 Tomasz Maciejko and TMProgressHud contributors.

/// Adopt on a custom view to receive the HUD's unnormalized progress without Objective-C bridging.
@MainActor
public protocol TMProgressHudProgressReporting: AnyObject {
    /// The current progress, forwarded without clamping.
    var progress: Float { get set }
}
