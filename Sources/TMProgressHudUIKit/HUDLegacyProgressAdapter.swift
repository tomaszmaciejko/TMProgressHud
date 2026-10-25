// SPDX-License-Identifier: MIT
// Copyright 2026 Tomasz Maciejko and TMProgressHud contributors.
import UIKit

/// Compatibility for existing custom views exposing the Objective-C progress setter.
@MainActor
struct HUDLegacyProgressAdapter {
    private let view: UIView

    init?(view: UIView) {
        guard view.responds(to: NSSelectorFromString("setProgress:")) else { return nil }
        self.view = view
    }

    func updateProgress(_ progress: Float) { view.setValue(progress, forKey: "progress") }
}
