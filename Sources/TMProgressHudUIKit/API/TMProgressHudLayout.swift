// SPDX-License-Identifier: MIT
// Copyright 2026 Tomasz Maciejko and TMProgressHud contributors.
import UIKit

private let defaultMargin: CGFloat = 20

/// Independent position, inner content padding and minimum outer spacing in points.
///
/// Insets use physical edges. The host bounds remain the reference area; safe areas are not applied implicitly.
public struct TMProgressHudLayout: Sendable, Equatable {
    /// The default 20-point spacing on every edge.
    public static let defaultInsets = UIEdgeInsets(
        top: defaultMargin, left: defaultMargin, bottom: defaultMargin,
        right: defaultMargin)

    /// The bezel alignment and offset.
    public var position: TMProgressHudPosition
    /// Padding between content and the bezel edges.
    public var contentInsets: UIEdgeInsets
    /// Minimum spacing between the bezel and host edges.
    public var hostInsets: UIEdgeInsets

    /// Creates a layout with centered content and independent 20-point inner and outer spacing.
    public init(
        position: TMProgressHudPosition = .init(),
        contentInsets: UIEdgeInsets = Self.defaultInsets, hostInsets: UIEdgeInsets = Self.defaultInsets
    ) {
        self.position = position
        self.contentInsets = contentInsets
        self.hostInsets = hostInsets
    }
}
