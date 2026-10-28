import Testing
import UIKit
@testable import TMProgressHudUIKit

@Suite(.serialized)
@MainActor
struct ContentColorTests {
    @Test func circleColorsFollowEachApplicationPolicyAndAppearance() throws {
        let adaptive = UIColor { traits in
            if traits.userInterfaceStyle == .dark { return UIColor.blue.withAlphaComponent(0.8) }
            return UIColor.red.withAlphaComponent(0.4)
        }
        let expectedTrackOpacity: CGFloat = 0.1
        let alphaTolerance: CGFloat = 0.000_001
        for content in [TMProgressHudContent.outlinedCircle, .ring] {
            let hud = TMProgressHud(frame: .zero)
            hud.setContent(content)
            let circle = try #require(hud.indicator as? TMRoundProgressView)
            for usesExplicitColor in [false, true, false] {
                if usesExplicitColor {
                    hud.applyContentColor(adaptive)
                } else {
                    hud.contentColor = .clear
                    hud.contentColor = adaptive
                }
                #expect(hud.indicator === circle)
                for style in [UIUserInterfaceStyle.light, .dark] {
                    let traits = UITraitCollection(userInterfaceStyle: style)
                    let source = adaptive.resolvedColor(with: traits)
                    let progress = circle.progressTintColor.resolvedColor(with: traits)
                    let track = circle.backgroundTintColor.resolvedColor(with: traits)
                    let expectedAlpha =
                        usesExplicitColor ? source.cgColor.alpha * expectedTrackOpacity : expectedTrackOpacity
                    #expect(progress == source)
                    #expect(track.withAlphaComponent(1) == source.withAlphaComponent(1))
                    #expect(abs(track.cgColor.alpha - expectedAlpha) < alphaTolerance)
                }
            }
        }
    }

    @Test func disabledBulkColorPreservesCustomStylesAndUIKitDefault() {
        let hud = TMProgressHud(frame: .zero)
        hud.contentColor = nil
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.color = .purple
        hud.setContent(.custom(spinner))
        #expect(spinner.color == .purple)

        let circle = TMRoundProgressView()
        circle.progressTintColor = .blue
        circle.backgroundTintColor = .green
        hud.setContent(.custom(circle))
        #expect(circle.progressTintColor == .blue)
        #expect(circle.backgroundTintColor == .green)

        let bar = TMBarProgressView()
        bar.progressColor = .orange
        bar.lineColor = .yellow
        hud.setContent(.custom(bar))
        #expect(bar.progressColor == .orange)
        #expect(bar.lineColor == .yellow)

        spinner.color = nil
        let systemColor = spinner.color
        hud.setContent(.custom(spinner))
        #expect(spinner.color == systemColor)
    }

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

    @Test func compatibilityRingTrackKeepsItsFixedOpacityForTransparentAndDynamicColors() throws {
        let hud = TMProgressHud(frame: .zero)
        hud.setContent(.ring)
        let ring = try #require(hud.indicator as? TMRoundProgressView)
        let adaptive = UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor.white.withAlphaComponent(0.5) : .black
        }
        let expectedTrackOpacity: CGFloat = 0.1
        for color in [UIColor.clear, UIColor.red.withAlphaComponent(0.5), adaptive] {
            hud.contentColor = color
            #expect(ring.progressTintColor == color)
            for style in [UIUserInterfaceStyle.light, .dark] {
                let traits = UITraitCollection(userInterfaceStyle: style)
                #expect(ring.backgroundTintColor.resolvedColor(with: traits).cgColor.alpha == expectedTrackOpacity)
            }
        }
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
