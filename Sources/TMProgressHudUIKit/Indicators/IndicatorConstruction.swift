// SPDX-License-Identifier: MIT
// Copyright 2026 Tomasz Maciejko and TMProgressHud contributors.
import UIKit

/// Selects a typed view and preserves the resolved progress operation of a reused client view.
///
/// Exists only while building an indicator; the result never retains this construction value.
@MainActor
struct IndicatorConstruction<View: UIView> {
    let view: View
    private let reusedIndicator: Indicator?

    init(
        reusing previous: Indicator?, policy: IndicatorFactory.ReusePolicy,
        createView: () -> View
    ) {
        if let previous,
            previous.origin == .library || policy == .includingClientViews,
            let matchingView = previous.view as? View
        {
            view = matchingView
            reusedIndicator = previous
        } else {
            view = createView()
            reusedIndicator = nil
        }
    }

    func makeIndicator(
        libraryProgressUpdater: Indicator.ProgressUpdater?,
        colorUpdater: @escaping Indicator.ColorUpdater
    ) -> Indicator {
        if let reusedIndicator, reusedIndicator.origin == .client {
            // Copy the operation directly; wrapping the old indicator would retain a chain of adapters.
            return Indicator(
                view: view, origin: .client, progressUpdater: reusedIndicator.progressUpdater,
                colorUpdater: colorUpdater)
        }
        return Indicator(
            view: view, origin: .library, progressUpdater: libraryProgressUpdater, colorUpdater: colorUpdater)
    }
}
