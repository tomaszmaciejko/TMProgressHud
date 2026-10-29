// SPDX-License-Identifier: MIT
// Copyright 2026 Tomasz Maciejko and TMProgressHud contributors.
import Foundation

// Whole-percent formatting must not round incomplete progress to 100%.
private let maximumIncompleteDisplayFraction: Float = 0.99

/// Formats a localized whole percentage, returning nil for nonfinite progress.
///
/// Finite values are bounded to 0...1 and rounded to the nearest whole percent.
/// Results stay below 100% until progress reaches 1. The caller supplies the formatting locale.
func formattedAccessibilityPercentage(for progress: Float, locale: Locale) -> String? {
    guard progress.isFinite else { return nil }
    let fraction = boundedProgressFraction(progress)
    let displayFraction = progress < 1 ? min(fraction, maximumIncompleteDisplayFraction) : fraction
    let percentageFormat: FloatingPointFormatStyle<Float>.Percent = .percent
        .precision(.fractionLength(0))
        .locale(locale)
    return displayFraction.formatted(percentageFormat)
}

/// Resolves an accessibility language identifier, using the supplied fallback when nil or blank.
///
/// Surrounding whitespace is removed; Foundation interprets nonempty identifiers.
func accessibilityLocale(for languageIdentifier: String?, fallback: Locale) -> Locale {
    guard let languageIdentifier else { return fallback }
    let identifier = languageIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !identifier.isEmpty else { return fallback }
    return Locale(identifier: identifier)
}
