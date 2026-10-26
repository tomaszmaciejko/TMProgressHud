import Testing
import UIKit
@testable import TMProgressHudUIKit

@Suite(.serialized)
@MainActor
struct ContentColorTests {
    @Test func defaultsOnlyAffectNewIndicatorsAndExplicitApplicationCanBeRepeated() throws {
        let hud = TMProgressHud(frame: .zero)
        hud.label.textColor = .yellow
        let spinner = try #require(hud.indicator as? UIActivityIndicatorView)
        let original = spinner.color
        hud.defaultIndicatorColor = .blue
        #expect(hud.label.textColor == .yellow)
        #expect(spinner.color == original)
        hud.applyContentColor(.red)
        #expect(hud.label.textColor == .red)
        #expect(spinner.color == .red)
        #expect(hud.defaultIndicatorColor == .blue)
        hud.label.textColor = .yellow
        hud.applyContentColor(.red)
        #expect(hud.label.textColor == .red)
        hud.setContent(.bar)
        #expect(try #require(hud.indicator as? TMBarProgressView).progressColor == .blue)
        #expect(hud.label.textColor == .red)
        hud.applyContentColor(.green)
        #expect(try #require(hud.indicator as? TMBarProgressView).lineColor == .green)
    }

    @Test func explicitColorOverridesProxyAndPreservesCustomTintBehavior() throws {
        let proxy = UIActivityIndicatorView.appearance(whenContainedInInstancesOf: [TMProgressHud.self])
        let previous = proxy.color
        proxy.color = .green
        defer { proxy.color = previous }
        let hud = TMProgressHud(frame: .zero)
        hud.contentColor = .blue
        let spinner = try #require(hud.indicator as? UIActivityIndicatorView)
        #expect(spinner.color == .green)
        hud.applyContentColor(.red)
        #expect(spinner.color == .red)
        let custom = UIView()
        hud.setContent(.custom(custom))
        hud.applyContentColor(.orange)
        #expect(custom.tintColor == .orange)
        #expect(hud.defaultIndicatorColor == .blue)
    }

    @Test func explicitRingColorPreservesTransparencyAndDynamicAlpha() throws {
        let hud = TMProgressHud(frame: .zero)
        hud.setContent(.ring)
        let ring = try #require(hud.indicator as? TMRoundProgressView)
        hud.applyContentColor(.clear)
        #expect(ring.progressTintColor.cgColor.alpha == 0)
        #expect(ring.backgroundTintColor.resolvedColor(with: .current).cgColor.alpha == 0)
        let adaptive = UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor.white.withAlphaComponent(0.5) : .black
        }
        hud.applyContentColor(adaptive)
        let light = UITraitCollection(userInterfaceStyle: .light)
        let dark = UITraitCollection(userInterfaceStyle: .dark)
        #expect(ring.backgroundTintColor.resolvedColor(with: light).cgColor.alpha == 0.1)
        #expect(ring.backgroundTintColor.resolvedColor(with: dark).cgColor.alpha == 0.05)
    }
}
