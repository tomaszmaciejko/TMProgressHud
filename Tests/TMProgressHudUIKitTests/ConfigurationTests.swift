import Testing
import UIKit
@testable import TMProgressHudUIKit

@Suite(.serialized)
@MainActor
struct ConfigurationTests {
    @Test(arguments: [0, 1, 2, 3, 4, 5])
    func modeChangesPreserveDirectContentCustomization(rawValue: Int) throws {
        let hud = TMProgressHud(frame: .zero)
        hud.mode = .text
        hud.contentColor = .red
        hud.label.text = "Loading"
        hud.label.font = .systemFont(ofSize: 23)
        hud.label.textColor = .blue
        hud.detailsLabel.textColor = .green
        hud.button.setTitleColor(.yellow, for: .normal)
        hud.customView = UIView()
        hud.mode = try #require(TMProgressHudMode(rawValue: rawValue))
        #expect(hud.label.textColor == .blue)
        #expect(hud.detailsLabel.textColor == .green)
        #expect(hud.button.titleColor(for: .normal) == .yellow)
        #expect(hud.label.text == "Loading")
        #expect(hud.label.font.pointSize == 23)
    }

    @Test func reusedIndicatorPreservesDirectColors() throws {
        let hud = TMProgressHud(frame: .zero)
        hud.mode = .determinate
        let round = try #require(hud.indicator as? TMRoundProgressView)
        round.progressTintColor = .blue
        round.backgroundTintColor = .yellow
        hud.mode = .annularDeterminate
        #expect(hud.indicator === round)
        #expect(round.progressTintColor == .blue)
        #expect(round.backgroundTintColor == .yellow)
    }
    @Test func bulkColorChangesAreExplicitAndNewIndicatorsInherit() throws {
        let hud = TMProgressHud(frame: .zero)
        hud.contentColor = .red
        hud.label.textColor = .blue
        hud.mode = .determinateHorizontalBar
        let bar = try #require(hud.indicator as? TMBarProgressView)
        #expect(hud.label.textColor == .blue)
        #expect(bar.lineColor == .red)
        hud.contentColor = .red
        #expect(hud.label.textColor == .blue)
        hud.contentColor = .orange
        #expect(hud.label.textColor == .orange)
        #expect(hud.detailsLabel.textColor == .orange)
        #expect(hud.button.titleColor(for: .normal) == .orange)
        #expect(bar.lineColor == .orange)
    }

    @Test func nilPreservesColorsAndClearExplicitlyMakesThemTransparent() throws {
        let hud = TMProgressHud(frame: .zero)
        hud.contentColor = .red
        hud.contentColor = nil
        #expect(hud.label.textColor == .red)
        hud.label.textColor = .blue
        hud.mode = .determinateHorizontalBar
        let bar = try #require(hud.indicator as? TMBarProgressView)
        #expect(hud.label.textColor == .blue)
        #expect(bar.lineColor == .white)
        hud.contentColor = .clear
        #expect(hud.label.textColor == .clear)
        #expect(hud.button.titleColor(for: .normal) == .clear)
        #expect(bar.lineColor == .clear)
    }

    @Test func textAndLayoutReadTheActualViews() {
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let hud = TMProgressHud.showAdded(to: host, animated: false)
        defer { hud.hide(animated: false) }
        let label = hud.label
        label.text = "First"
        hud.mode = .text
        label.text = "Second"
        label.font = .systemFont(ofSize: 23)
        host.layoutIfNeeded()
        #expect(hud.label === label)
        #expect(hud.label.text == "Second")
        #expect(hud.label.font.pointSize == 23)
        #expect(hud.label.frame.width > 0)
    }

    @Test func backgroundNilClearsTintAndKeepsBlur() throws {
        let background = TMBackgroundView()
        let effect = try #require(background.subviews.compactMap { $0 as? UIVisualEffectView }.first)
        background.color = .red
        background.color = nil
        #expect(background.backgroundColor == nil)
        #expect(effect.superview === background)
        #expect(background.style == .blur)
    }

    @Test func containerAppearanceRemainsAboveBulkIndicatorColor() throws {
        let proxy = UIActivityIndicatorView.appearance(whenContainedInInstancesOf: [TMProgressHud.self])
        let previous = proxy.color
        proxy.color = .green
        defer { proxy.color = previous }
        let window = try makeHostedTestWindow()
        defer { window.isHidden = true }
        let host = try #require(window.rootViewController?.view)
        let hud = TMProgressHud.showAdded(to: host, animated: false)
        defer { hud.hide(animated: false) }
        hud.contentColor = .red
        host.layoutIfNeeded()
        let spinner = try #require(hud.indicator as? UIActivityIndicatorView)
        #expect(spinner.color == .green)
        #expect(hud.label.textColor == .red)
        hud.contentColor = .orange
        #expect(spinner.color == .green)
        #expect(hud.label.textColor == .orange)
    }
}
