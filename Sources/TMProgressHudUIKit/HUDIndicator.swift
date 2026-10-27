// SPDX-License-Identifier: MIT
// Copyright 2026 Tomasz Maciejko and TMProgressHud contributors.
import UIKit

/// A ready-to-use indicator view with its progress and color operations.
@MainActor
struct HUDIndicator {
    enum Origin {
        case library
        case client
    }

    enum ColorPolicy {
        /// Preserves appearance precedence and the historical fixed track opacity.
        case compatibility
        case explicit
    }

    typealias ProgressUpdater = (Float) -> Void
    typealias ColorUpdater = (UIColor?, ColorPolicy) -> Void

    let view: UIView

    /// Tracks who supplied the view, even after compatibility setters change its mode.
    let origin: Origin
    private let applyProgress: ProgressUpdater?
    private let applyColor: ColorUpdater

    init(
        view: UIView, origin: Origin,
        progressUpdater: ProgressUpdater?, colorUpdater: @escaping ColorUpdater
    ) {
        self.view = view
        self.origin = origin
        applyProgress = progressUpdater
        applyColor = colorUpdater
    }

    func updateProgress(_ progress: Float) {
        applyProgress?(progress)
    }

    func updateColor(_ color: UIColor?, policy: ColorPolicy = .compatibility) {
        applyColor(color, policy)
    }
}
