import Foundation
import Testing
import UIKit
@testable import TMProgressHudUIKit

@MainActor
private final class AccessibleRoundOverride: TMRoundProgressView {
    override var progress: Float {
        get { 0.75 }
        set { super.progress = newValue }
    }
}

@Suite(.serialized)
@MainActor
struct ProgressAccessibilityTests {
    @Test(arguments: [false, true])
    func indicatorsExposeLocalizedBoundedProgress(useBar: Bool) throws {
        let hud = TMProgressHud(frame: .zero)
        hud.setContent(useBar ? .bar : .ring)
        let indicator = try #require(
            hud.bezelView.subviews.first {
                $0 is TMRoundProgressView || $0 is TMBarProgressView
            })
        #expect(indicator.isAccessibilityElement)
        #expect(indicator.accessibilityTraits.contains(.updatesFrequently))
        #expect(indicator.accessibilityValue != nil)
        indicator.accessibilityLanguage = "en-US"
        let cases: [(Float, String?)] = [
            (0, "0%"), (-0.0, "0%"), (0.25, "25%"), (0.5, "50%"),
            (0.124, "12%"), (0.126, "13%"), (0.994, "99%"),
            (0.996, "99%"), (Float(1).nextDown, "99%"),
            (1, "100%"), (Float(1).nextUp, "100%"),
            (1.5, "100%"), (.greatestFiniteMagnitude, "100%"), (-0.5, "0%"),
            (.nan, nil), (.infinity, nil), (-.infinity, nil),
        ]
        for (progress, expected) in cases {
            hud.setProgressSource(.manual(progress))
            #expect(indicator.accessibilityValue == expected)
            if progress.isNaN { #expect(hud.progress.isNaN) } else { #expect(hud.progress == progress) }
        }
    }

    @Test(
        arguments: [false, true],
        [
            ("en-US", "50%"), ("pl-PL", "50%"),
            ("fr-FR", "50\u{00A0}%"), ("ar-EG", "٥٠٪\u{061C}"),
        ])
    func percentagesFollowTheSelectedLanguage(useBar: Bool, localization: (identifier: String, expected: String))
        throws
    {
        let hud = TMProgressHud(frame: .zero)
        hud.setContent(useBar ? .bar : .ring)
        let indicator = try #require(
            hud.bezelView.subviews.first {
                $0 is TMRoundProgressView || $0 is TMBarProgressView
            })
        hud.setProgressSource(.manual(0.5))
        indicator.accessibilityLanguage = localization.identifier
        #expect(indicator.accessibilityValue == localization.expected)
        indicator.accessibilityLanguage = "en-US"
        #expect(indicator.accessibilityValue == "50%")
    }

    @Test(arguments: [false, true])
    func missingOrBlankLanguageUsesTheCurrentLocale(useBar: Bool) throws {
        let hud = TMProgressHud(frame: .zero)
        hud.setContent(useBar ? .bar : .ring)
        let indicator = try #require(
            hud.bezelView.subviews.first {
                $0 is TMRoundProgressView || $0 is TMBarProgressView
            })
        hud.setProgressSource(.manual(0.5))
        indicator.accessibilityLanguage = nil
        let defaultValue = try #require(indicator.accessibilityValue)
        for language in ["", " \n\t"] {
            indicator.accessibilityLanguage = language
            #expect(indicator.accessibilityValue == defaultValue)
        }
    }

    @Test(arguments: [
        ("en-US", "99%", "100%"), ("fr-FR", "99\u{00A0}%", "100\u{00A0}%"),
        ("ar-EG", "٩٩٪\u{061C}", "١٠٠٪\u{061C}"),
    ])
    func explicitLocalesReserveOneHundredPercentForCompletion(
        localization: (identifier: String, incomplete: String, complete: String)
    ) {
        let locale = Locale(identifier: localization.identifier)
        for progress: Float in [0.996, Float(1).nextDown] {
            #expect(formattedAccessibilityPercentage(for: progress, locale: locale) == localization.incomplete)
        }
        for progress: Float in [1, Float(1).nextUp, .greatestFiniteMagnitude] {
            #expect(formattedAccessibilityPercentage(for: progress, locale: locale) == localization.complete)
        }
        for progress: Float in [.nan, .infinity, -.infinity] {
            #expect(formattedAccessibilityPercentage(for: progress, locale: locale) == nil)
        }
    }

    @Test(arguments: [nil, "", " \n\t"] as [String?])
    func languageSelectionUsesTheExplicitFallback(language: String?) {
        let fallback = Locale(identifier: "fr-FR")
        #expect(accessibilityLocale(for: language, fallback: fallback) == fallback)
    }

    @Test(arguments: ["en-US", "pl_PL", "fr-FR", "ar-EG"])
    func languageSelectionTrimsSurroundingWhitespace(language: String) {
        let locale = accessibilityLocale(for: " \t" + language + "\n", fallback: Locale(identifier: "fr-FR"))
        #expect(locale == Locale(identifier: language))
    }

    @Test func applicationAccessibilityOverridesRemainAvailable() {
        let round = TMRoundProgressView()
        let bar = TMBarProgressView()
        round.progress = 0.5
        bar.progress = 0.5
        for view in [round, bar] as [UIView] {
            view.accessibilityLanguage = "en-US"
            view.accessibilityLabel = "Downloaded data"
            view.accessibilityValue = "Complete"
            #expect(view.accessibilityValue == "Complete")
            view.accessibilityValue = nil
            #expect(view.accessibilityValue == "50%")
            #expect(view.accessibilityLabel == "Downloaded data")
            view.isAccessibilityElement = false
            #expect(!view.isAccessibilityElement)
        }
    }

    @Test func accessibilityReadsTheOverriddenProgressGetter() {
        let view = AccessibleRoundOverride()
        view.accessibilityLanguage = "en-US"
        view.progress = 0.25
        #expect(view.accessibilityValue == "75%")
    }

    @Test func callerOwnedCustomContentKeepsItsSemantics() {
        let hud = TMProgressHud(frame: .zero)
        let custom = UIView()
        custom.isAccessibilityElement = true
        custom.accessibilityLabel = "Upload"
        custom.accessibilityValue = "Waiting"
        custom.accessibilityTraits = .staticText
        hud.setContent(.custom(custom))
        hud.setProgressSource(.manual(0.5))
        #expect(custom.accessibilityLabel == "Upload")
        #expect(custom.accessibilityValue == "Waiting")
        #expect(custom.accessibilityTraits == .staticText)
    }
}
