import Testing
import UIKit
import TMProgressHudUIKit

@Suite(.serialized)
@MainActor
struct AccessibilityTests {
    @Test func defaultTypographyTracksTheContentSizeCategory() throws {
        let window = try makeHostedTestWindow()
        defer { window.isHidden = true }
        let host = try #require(window.rootViewController?.view)
        let hud = TMProgressHud.showAdded(to: host, animated: false)
        defer { hud.hide(animated: false) }
        hud.label.text = "Loading"
        hud.detailsLabel.text = "Fetching progress"
        hud.button.setTitle("Close", for: .normal)
        hud.button.addAction(UIAction { _ in }, for: .primaryActionTriggered)
        let labels = [hud.label, hud.detailsLabel, try #require(hud.button.titleLabel)]
        hud.traitOverrides.preferredContentSizeCategory = .large
        for label in labels { label.updateTraitsIfNeeded() }
        let originalSizes = labels.map { $0.font.pointSize }
        for label in labels { #expect(label.adjustsFontForContentSizeCategory) }
        hud.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
        host.layoutIfNeeded()
        for (label, original) in zip(labels, originalSizes) {
            label.updateTraitsIfNeeded()
            #expect(label.font.pointSize > original)
        }
        hud.traitOverrides.preferredContentSizeCategory = .large
        host.layoutIfNeeded()
        for (label, original) in zip(labels, originalSizes) {
            label.updateTraitsIfNeeded()
            #expect(label.font.pointSize == original)
        }
    }

    @Test func callerCanOptOutAndProvideAFixedFont() {
        let hud = TMProgressHud(frame: .zero)
        hud.label.adjustsFontForContentSizeCategory = false
        hud.label.font = .systemFont(ofSize: 23)
        hud.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
        hud.label.updateTraitsIfNeeded()
        #expect(hud.label.font.pointSize == 23)
    }
}
