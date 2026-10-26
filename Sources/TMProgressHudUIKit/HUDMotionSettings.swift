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

    var shouldReduceMotion: Bool { policy.reducesMotion(systemValue: preference.value) }

    private let preference: HUDSystemPreference
    private let onChange: @MainActor () -> Void

    init(
        center: NotificationCenter = .default,
        systemValue: @escaping @MainActor () -> Bool = { UIAccessibility.isReduceMotionEnabled },
        onChange: @escaping @MainActor () -> Void
    ) {
        self.onChange = onChange
        preference = HUDSystemPreference(
            center: center, name: UIAccessibility.reduceMotionStatusDidChangeNotification,
            read: systemValue, onChange: onChange)
    }
}
