// SPDX-License-Identifier: MIT
// Copyright 2026 Tomasz Maciejko and TMProgressHud contributors.

/// Bounds a display fraction to 0...1, mapping nonfinite values to zero without changing the caller's progress.
func boundedProgressFraction(_ value: Float) -> Float {
    guard value.isFinite, value > 0 else { return 0 }
    return min(value, 1)
}
