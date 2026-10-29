// SPDX-License-Identifier: MIT
// Copyright 2026 Tomasz Maciejko and TMProgressHud contributors.
import UIKit

/// Owns the motion policy and observation of the system accessibility setting.
@MainActor
final class MotionSettings {
    var policy: TMProgressHudMotionPolicy = .system {
        didSet {
            if oldValue != policy { onChange() }
        }
    }

    var shouldReduceMotion: Bool { policy.reducesMotion(systemValue: readReduceMotion()) }

    private let readReduceMotion: @MainActor () -> Bool
    private var reduceMotionObservation: NotificationToken?
    private let onChange: @MainActor () -> Void

    init(
        center: NotificationCenter = .default,
        systemValue: @escaping @MainActor () -> Bool = { UIAccessibility.isReduceMotionEnabled },
        onChange: @escaping @MainActor () -> Void
    ) {
        self.onChange = onChange
        readReduceMotion = systemValue
        let token = center.addObserver(
            forName: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.onChange() }
        }
        reduceMotionObservation = NotificationToken(center: center, token: token)
    }
}
