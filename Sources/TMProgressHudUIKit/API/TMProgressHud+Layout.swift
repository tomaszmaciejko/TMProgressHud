// SPDX-License-Identifier: MIT
// Copyright 2026 Tomasz Maciejko and TMProgressHud contributors.
import UIKit

extension TMProgressHud {
    var layoutContentViews: [UIView] {
        var views = [label, detailsLabel, button]
        if let indicator { views.insert(indicator, at: 0) }
        return views
    }

    /// The effective position and insets, including compatibility getter overrides.
    public var layoutConfiguration: TMProgressHudLayout {
        layoutPreferences.resolved(offset: offset, margin: margin)
    }

    /// Selects position and independent inner/outer spacing as one operation.
    ///
    /// Minimum size and square preference remain independent. Compatibility KVO notifications
    /// are delivered after the completed selection; offset projects edge anchors to legacy extremes,
    /// while margin reads the top content inset.
    public func setLayout(_ layout: TMProgressHudLayout) {
        let preferences = HUDLayoutPreferences(
            position: .configured(layout.position), contentInsets: layout.contentInsets, hostInsets: layout.hostInsets)
        guard layoutPreferences != preferences else { return }
        var changedKeys: [String] = []
        if layoutPreferences.compatibilityOffset != preferences.compatibilityOffset {
            changedKeys.append(#keyPath(TMProgressHud.offset))
        }
        if layoutPreferences.compatibilityMargin != preferences.compatibilityMargin {
            changedKeys.append(#keyPath(TMProgressHud.margin))
        }
        for key in changedKeys { willChangeValue(forKey: key) }
        layoutPreferences = preferences
        setNeedsUpdateConstraints()
        for key in changedKeys.reversed() { didChangeValue(forKey: key) }
    }
}
