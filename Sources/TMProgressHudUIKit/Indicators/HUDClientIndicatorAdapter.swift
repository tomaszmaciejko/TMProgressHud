// SPDX-License-Identifier: MIT
// Copyright 2026 Tomasz Maciejko and TMProgressHud contributors.
import UIKit

/// Adapts client views, resolving progress and coloring independently.
@MainActor
enum HUDClientIndicatorAdapter {
    static func make(
        for view: UIView, updateProgress: HUDIndicator.ProgressUpdater?
    ) -> HUDIndicator {
        let resolvedProgressUpdater: HUDIndicator.ProgressUpdater?
        if let updateProgress {
            resolvedProgressUpdater = updateProgress
        } else {
            resolvedProgressUpdater = progressUpdater(for: view)
        }
        return HUDIndicator(
            view: view, origin: .client,
            progressUpdater: resolvedProgressUpdater, colorUpdater: colorUpdater(for: view))
    }

    private static func progressUpdater(for view: UIView) -> HUDIndicator.ProgressUpdater? {
        // A subclass may explicitly declare a progress contract different from its native superclass.
        switch view {
        case let reportingView as any TMProgressHudProgressReporting:
            return { reportingView.progress = $0 }
        case let circle as TMRoundProgressView:
            return { circle.progress = $0 }
        case let bar as TMBarProgressView:
            return { bar.progress = $0 }
        case let nativeProgressView as UIProgressView:
            return { nativeProgressView.progress = $0 }
        default:
            return nil
        }
    }

    private static func colorUpdater(for view: UIView) -> HUDIndicator.ColorUpdater {
        switch view {
        case let circle as TMRoundProgressView:
            return HUDIndicatorColoring.circularUpdater(for: circle)
        case let bar as TMBarProgressView:
            return HUDIndicatorColoring.barUpdater(for: bar)
        case let spinner as UIActivityIndicatorView:
            return HUDIndicatorColoring.activityUpdater(for: spinner)
        default:
            return HUDIndicatorColoring.tintUpdater(for: view)
        }
    }
}
