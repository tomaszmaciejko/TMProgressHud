import Testing
import UIKit
import TMProgressHudUIKit

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
            (1, "100%"), (1.5, "100%"), (-0.5, "0%"),
            (.nan, nil), (.infinity, nil), (-.infinity, nil),
        ]
        for (progress, expected) in cases {
            hud.setProgressSource(.manual(progress))
            #expect(indicator.accessibilityValue == expected)
            if progress.isNaN { #expect(hud.progress.isNaN) } else { #expect(hud.progress == progress) }
        }
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
