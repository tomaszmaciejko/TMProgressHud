// SPDX-License-Identifier: MIT
// Copyright 2026 Tomasz Maciejko and TMProgressHud contributors.
import UIKit

/// One source of layout values, with projections for the compatibility properties.
struct HUDLayoutPreferences: Equatable {
    enum Position: Equatable {
        case legacy(CGPoint)
        case configured(TMProgressHudPosition)
    }

    var position: Position = .legacy(.zero)
    var contentInsets = TMProgressHudLayout.defaultInsets
    var hostInsets = TMProgressHudLayout.defaultInsets

    var compatibilityOffset: CGPoint {
        switch position {
        case .legacy(let offset): return offset
        case .configured(let value):
            let x: CGFloat =
                switch value.horizontal {
                case .left: -TMProgressMaxOffset
                case .center: value.offset.x
                case .right: TMProgressMaxOffset
                }
            let y: CGFloat =
                switch value.vertical {
                case .top: -TMProgressMaxOffset
                case .center: value.offset.y
                case .bottom: TMProgressMaxOffset
                }
            return CGPoint(x: x, y: y)
        }
    }

    var compatibilityMargin: CGFloat { contentInsets.top }

    func resolved(offset: CGPoint, margin: CGFloat) -> TMProgressHudLayout {
        let selected: TMProgressHudPosition
        if offset != compatibilityOffset {
            selected = Self.legacyPosition(offset)
        } else {
            switch position {
            case .legacy(let value): selected = Self.legacyPosition(value)
            case .configured(let value): selected = value
            }
        }
        let uniform = Self.uniformInsets(margin)
        return TMProgressHudLayout(
            position: selected,
            contentInsets: margin == compatibilityMargin ? contentInsets : uniform,
            hostInsets: margin == compatibilityMargin ? hostInsets : uniform)
    }

    static func uniformInsets(_ margin: CGFloat) -> UIEdgeInsets {
        UIEdgeInsets(top: margin, left: margin, bottom: margin, right: margin)
    }

    private static func legacyPosition(_ offset: CGPoint) -> TMProgressHudPosition {
        var position = TMProgressHudPosition(offset: offset)
        if offset.x <= -TMProgressMaxOffset {
            position.horizontal = .left
            position.offset.x = 0
        } else if offset.x >= TMProgressMaxOffset {
            position.horizontal = .right
            position.offset.x = 0
        }
        if offset.y <= -TMProgressMaxOffset {
            position.vertical = .top
            position.offset.y = 0
        } else if offset.y >= TMProgressMaxOffset {
            position.vertical = .bottom
            position.offset.y = 0
        }
        return position
    }
}
