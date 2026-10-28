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

    typealias ProgressUpdater = @MainActor (Float) -> Void
    typealias ColorUpdater = (UIColor?, ColorPolicy) -> Void

    let view: UIView

    /// Tracks who supplied the view, even after compatibility setters change its mode.
    let origin: Origin
    /// Preserves the resolved operation when compatibility setters reuse a client view.
    let progressUpdater: ProgressUpdater?
    private let applyColor: ColorUpdater

    init(
        view: UIView, origin: Origin,
        progressUpdater: ProgressUpdater?, colorUpdater: @escaping ColorUpdater
    ) {
        self.view = view
        self.origin = origin
        self.progressUpdater = progressUpdater
        applyColor = colorUpdater
    }

    func updateProgress(_ progress: Float) {
        progressUpdater?(progress)
    }

    func updateColor(_ color: UIColor?, policy: ColorPolicy = .compatibility) {
        applyColor(color, policy)
    }
}
