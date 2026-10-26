// SPDX-License-Identifier: MIT
// Copyright 2026 Tomasz Maciejko and TMProgressHud contributors.

/// Controls future transitions and the HUD-owned tilt effects.
public enum TMProgressHudMotionPolicy: Sendable {
    /// Follows the system Reduce Motion setting.
    case system
    /// Uses fading transitions and suppresses HUD-owned tilt effects.
    case reduced
    /// Allows the selected transitions and requested tilt effects regardless of the system setting.
    case full

    func reducesMotion(systemValue: Bool) -> Bool {
        switch self {
        case .system: systemValue
        case .reduced: true
        case .full: false
        }
    }
}
