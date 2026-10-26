// SPDX-License-Identifier: MIT
// Copyright 2026 Tomasz Maciejko and TMProgressHud contributors.
import UIKit

/// Physical alignment within the host bounds, with a rightward/downward offset in points.
///
/// Left and right do not mirror with the interface language.
public struct TMProgressHudPosition: Sendable, Equatable {
    /// Horizontal alignment in the host coordinate system.
    public enum Horizontal: Sendable {
        /// Aligns with the host's left inset.
        case left
        /// Aligns with the host center.
        case center
        /// Aligns with the host's right inset.
        case right
    }

    /// Vertical alignment in the host coordinate system.
    public enum Vertical: Sendable {
        /// Aligns with the host's top inset.
        case top
        /// Aligns with the host center.
        case center
        /// Aligns with the host's bottom inset.
        case bottom
    }

    /// The horizontal anchor, initially centered.
    public var horizontal: Horizontal
    /// The vertical anchor, initially centered.
    public var vertical: Vertical
    /// A physical offset from the selected anchors, constrained by host insets.
    public var offset: CGPoint

    /// Creates a physical position; positive offsets move right and down.
    public init(horizontal: Horizontal = .center, vertical: Vertical = .center, offset: CGPoint = .zero) {
        self.horizontal = horizontal
        self.vertical = vertical
        self.offset = offset
    }
}
