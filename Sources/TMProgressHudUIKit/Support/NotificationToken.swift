// SPDX-License-Identifier: MIT
// Copyright 2026 Tomasz Maciejko and TMProgressHud contributors.
import Foundation

/// Removes one block-based registration on release, including from a nonisolated deinit.
///
/// Registration, preference reads and main-actor delivery remain with the consumer.
final class NotificationToken {
    private let center: NotificationCenter
    private let token: any NSObjectProtocol

    /// Takes ownership of an existing registration; does not register or deliver notifications.
    init(center: NotificationCenter, token: any NSObjectProtocol) {
        self.center = center
        self.token = token
    }

    deinit {
        center.removeObserver(token)
    }
}
