// SPDX-License-Identifier: MIT
// Copyright 2026 Tomasz Maciejko and TMProgressHud contributors.

/// Controls whether a configured blur background uses an opaque accessibility fallback.
public enum TMProgressHudBlurPolicy: Sendable {
    /// Follows the system Reduce Transparency setting.
    case system
    /// Uses the opaque fallback for blur backgrounds.
    case opaque
    /// Keeps the configured material and tint; UIKit still controls its own material behavior.
    case configured

    func usesOpaqueBackground(systemValue: Bool) -> Bool {
        switch self {
        case .system: systemValue
        case .opaque: true
        case .configured: false
        }
    }
}
