// SPDX-License-Identifier: MIT
// Copyright 2026 Tomasz Maciejko and TMProgressHud contributors.
import Foundation

/// Formats a bounded spoken percentage without changing the caller's progress value.
enum HUDProgressAccessibility {
    static func value(for progress: Float, language: String?) -> String? {
        guard progress.isFinite else { return nil }
        let fraction: Float = progress > 0 ? min(progress, 1) : 0
        let locale = language.map { Locale(identifier: $0) } ?? .current
        return fraction.formatted(.percent.precision(.fractionLength(0)).locale(locale))
    }
}
