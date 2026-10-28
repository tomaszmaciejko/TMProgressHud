// SPDX-License-Identifier: MIT
// Copyright 2026 Tomasz Maciejko and TMProgressHud contributors.

/// Bounds display fractions without changing the caller's stored progress.
enum HUDProgressValue {
    static func boundedFraction(_ value: Float) -> Float {
        guard value.isFinite, value > 0 else { return 0 }
        return min(value, 1)
    }
}
