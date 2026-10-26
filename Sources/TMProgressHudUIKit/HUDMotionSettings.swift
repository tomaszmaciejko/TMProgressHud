// SPDX-License-Identifier: MIT
// Copyright 2026 Tomasz Maciejko and TMProgressHud contributors.
import UIKit

/// Owns the motion policy and observation of the system accessibility setting.
@MainActor
final class HUDMotionSettings {
    var policy: TMProgressHudMotionPolicy = .system {
        didSet {
            if oldValue != policy { onChange() }
        }
    }

    var shouldReduceMotion: Bool { policy.reducesMotion(systemValue: systemValue()) }

    private let systemValue: @MainActor () -> Bool
    private let onChange: @MainActor () -> Void
    private var observation: HUDMotionObservation?

    init(
        center: NotificationCenter = .default,
        systemValue: @escaping @MainActor () -> Bool = { UIAccessibility.isReduceMotionEnabled },
        onChange: @escaping @MainActor () -> Void
    ) {
        self.systemValue = systemValue
        self.onChange = onChange
        observation = HUDMotionObservation(center: center) { [weak self] in self?.onChange() }
    }
}

/// Releases the Foundation observer token without accessing main-actor state from deinit.
private final class HUDMotionObservation {
    private let center: NotificationCenter
    private let token: any NSObjectProtocol

    init(center: NotificationCenter, onChange: @escaping @MainActor () -> Void) {
        self.center = center
        token = center.addObserver(
            forName: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil, queue: .main
        ) { _ in
            Task { @MainActor in onChange() }
        }
    }

    deinit {
        center.removeObserver(token)
    }
}
