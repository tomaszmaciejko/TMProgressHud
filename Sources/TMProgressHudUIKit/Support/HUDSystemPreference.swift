// SPDX-License-Identifier: MIT
// Copyright 2026 Tomasz Maciejko and TMProgressHud contributors.
import Foundation

/// Reads one system preference and owns notification delivery to the main actor.
@MainActor
final class HUDSystemPreference {
    var value: Bool { read() }

    private let read: @MainActor () -> Bool
    private let onChange: @MainActor () -> Void
    private var observation: HUDSettingsObservation?

    init(
        center: NotificationCenter = .default, name: Notification.Name,
        read: @escaping @MainActor () -> Bool, onChange: @escaping @MainActor () -> Void
    ) {
        self.read = read
        self.onChange = onChange
        observation = HUDSettingsObservation(center: center, name: name) { [weak self] in self?.onChange() }
    }
}

/// Releases the Foundation token without accessing main-actor state from deinit.
private final class HUDSettingsObservation {
    private let center: NotificationCenter
    private let token: any NSObjectProtocol

    init(center: NotificationCenter, name: Notification.Name, onChange: @escaping @MainActor () -> Void) {
        self.center = center
        token = center.addObserver(forName: name, object: nil, queue: .main) { _ in
            Task { @MainActor in onChange() }
        }
    }

    deinit {
        center.removeObserver(token)
    }
}
