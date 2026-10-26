// SPDX-License-Identifier: MIT
// Portions Copyright 2009-2020 Matej Bukovinski.
// Swift port Copyright 2026 Tomasz Maciejko and TMProgressHud contributors.
// Reference: 4a7c5f3e53cdea77c5dcb8578c2ee5acacdf6781. See THIRD_PARTY_NOTICES.md.
import Foundation

/// Receives HUD lifecycle callbacks on the main actor.
@MainActor
@objc(TMProgressHudDelegate) public protocol TMProgressHudDelegate: NSObjectProtocol {
    /// Called once after a presentation finishes hiding, following its completion block.
    @objc optional func hudWasHidden(_ hud: TMProgressHud)
}
