// SPDX-License-Identifier: MIT
// Copyright 2026 Tomasz Maciejko and TMProgressHud contributors.
import Foundation

/// An explicit choice between caller-driven and observed progress.
public enum TMProgressHudProgressSource: Sendable {
    /// Stops observation and sets an unnormalized value.
    case manual(Float)
    /// Observes a Foundation Progress while the HUD is presented in a window.
    case observed(Progress)
}

extension TMProgressHud {
    /// Selects the progress source; manual values cannot be overwritten by an earlier observation.
    ///
    /// The compatibility progress and progressObject properties remain available independently.
    public func setProgressSource(_ source: TMProgressHudProgressSource) {
        switch source {
        case .manual(let value):
            progressObject = nil
            progress = value
        case .observed(let source):
            progressObject = source
        }
    }
}
