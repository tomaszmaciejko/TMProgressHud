import MBProgressHUDReference
import Testing
import UIKit
@testable import TMProgressHudUIKit

@MainActor
private final class CustomProgressView: UIView {
    @objc dynamic var progress: Float = 0
    override var intrinsicContentSize: CGSize { CGSize(width: 37, height: 37) }
}

@MainActor
private final class CallbackSpy: NSObject, TMProgressHudDelegate {
    var events: [String] = []
    func hudWasHidden(_ hud: TMProgressHud) { events.append("delegate") }
}

@MainActor
private final class HUDSubclass: TMProgressHud {}

@Suite(.serialized)
@MainActor
struct HUDBehaviorTests {
    @Test func initialStateAndHostHelpers() {
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let hud = TMProgressHud(view: host)
        let original = MBProgressHUD(view: host)
        #expect(hud.frame == original.frame)
        #expect(hud.margin == original.margin)
        #expect(hud.contentColor == original.contentColor)
        #expect(hud.alpha == original.alpha)
        #expect(hud.superview == nil)
        #expect(hud.label.font == original.label.font)
        #expect(hud.detailsLabel.font == original.detailsLabel.font)
        #expect(hud.detailsLabel.numberOfLines == 0)
        #expect(!TMProgressHud.hide(for: host, animated: false))
        host.addSubview(UIView())
        let first = TMProgressHud.showAdded(to: host, animated: false)
        let last: HUDSubclass = HUDSubclass.showAdded(to: host, animated: false)
        #expect(TMProgressHud.forView(host) === last)
        #expect(TMProgressHud.hide(for: host, animated: false))
        #expect(last.superview == nil)
        #expect(TMProgressHud.forView(host) === first)
        first.hide(animated: false)
        #expect(TMProgressHud.forView(host) == nil)
        let nested = UIView()
        host.addSubview(nested)
        nested.addSubview(hud)
        #expect(TMProgressHud.forView(host) == nil)
        hud.hide(animated: false)
        hud.removeFromSuperview()
    }

    @Test func modeChangesPreserveRingQuirkAndCustomDispatch() throws {
        let hud = TMProgressHud(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        hud.mode = .indeterminate
        hud.mode = .determinate
        hud.progress = 0.25
        let round = try #require(hud.indicator as? TMRoundProgressView)
        #expect(round.progress == 0.25)
        hud.mode = .annularDeterminate
        #expect(round.isAnnular)
        hud.mode = .determinate
        #expect(hud.indicator === round)
        #expect(round.isAnnular)
        hud.mode = .determinateHorizontalBar
        #expect((hud.indicator as? TMBarProgressView)?.progress == 0.25)
        let custom = CustomProgressView()
        hud.customView = custom
        hud.mode = .customView
        #expect(custom.progress == 0.25)
        hud.progress = 0.75
        #expect(custom.progress == 0.75)
        hud.customView = custom
        hud.customView = nil
        #expect(hud.indicator == nil)
        hud.customView = custom
        hud.mode = .text
        #expect(custom.superview == nil)
        hud.mode = .indeterminate
        #expect((hud.indicator as? UIActivityIndicatorView)?.isAnimating == true)
    }

    @Test func contentColorsRespectIndependentCustomization() {
        let hud = TMProgressHud(frame: .zero)
        hud.contentColor = .red
        #expect(hud.label.textColor == .red)
        #expect((hud.indicator as? UIActivityIndicatorView)?.color == .red)
        hud.contentColor = .red
        hud.contentColor = nil
        #expect(hud.label.textColor == .red)
        hud.mode = .determinate
        hud.contentColor = .blue
        #expect((hud.indicator as? TMRoundProgressView)?.progressTintColor == .blue)
        hud.mode = .determinateHorizontalBar
        #expect((hud.indicator as? TMBarProgressView)?.lineColor == .blue)
        hud.customView = UIView()
        hud.mode = .customView
        #expect(hud.customView?.tintColor == .blue)
    }

    @Test func containerAppearancePreservesReferencePrecedence() throws {
        let proxy = UIActivityIndicatorView.appearance(whenContainedInInstancesOf: [TMProgressHud.self])
        let referenceProxy = UIActivityIndicatorView.appearance(whenContainedInInstancesOf: [MBProgressHUD.self])
        let previous = proxy.color
        let previousReference = referenceProxy.color
        proxy.color = .green
        referenceProxy.color = .green
        defer {
            proxy.color = previous
            referenceProxy.color = previousReference
        }
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let hud = TMProgressHud.showAdded(to: host, animated: false)
        let original = MBProgressHUD.showAdded(to: host, animated: false)
        hud.contentColor = .red
        original.contentColor = .red
        let spinner = try #require(hud.indicator as? UIActivityIndicatorView)
        let referenceSpinner = try #require(
            original.bezelView.subviews.compactMap { $0 as? UIActivityIndicatorView }.first)
        #expect(proxy.color == .green)
        #expect(referenceProxy.color == .green)
        #expect(spinner.color == referenceSpinner.color)
        #expect(spinner.color != .red)
        hud.hide(animated: false)
        original.hide(animated: false)
    }

    @Test func repeatedHideRetainsCallbackOrdering() {
        let hud = TMProgressHud(frame: .zero)
        let spy = CallbackSpy()
        hud.delegate = spy
        hud.completionBlock = { spy.events.append("completion") }
        hud.show(animated: false)
        hud.hide(animated: false)
        hud.hide(animated: false)
        #expect(spy.events == ["completion", "delegate", "completion", "delegate"])
        hud.completionBlock = nil
        hud.delegate = nil
        hud.hide(animated: false)
    }

    @Test func frameLayoutAndMotionFollowReference() {
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let hud = TMProgressHud.showAdded(to: host, animated: false)
        hud.label.text = "Loading"
        hud.detailsLabel.text = "More details"
        hud.offset = CGPoint(x: 10, y: -10)
        hud.margin = 24
        hud.minSize = CGSize(width: 140, height: 140)
        hud.isSquare = true
        host.layoutIfNeeded()
        #expect(hud.bezelView.bounds.width >= 140)
        #expect(hud.bezelView.bounds.width == hud.bezelView.bounds.height)
        hud.layoutSubviews()
        let unchangedOffset = hud.offset
        hud.offset = unchangedOffset
        let unchangedMargin = hud.margin
        hud.margin = unchangedMargin
        let unchangedMinsize = hud.minSize
        hud.minSize = unchangedMinsize
        let unchangedIssquare = hud.isSquare
        hud.isSquare = unchangedIssquare
        hud.areDefaultMotionEffectsEnabled = true
        #expect(hud.bezelView.motionEffects.count == 1)
        hud.show(animated: false)
        #expect(hud.bezelView.motionEffects.isEmpty)
        hud.areDefaultMotionEffectsEnabled = false
        hud.areDefaultMotionEffectsEnabled = false
        NotificationCenter.default.post(name: TMProgressHud.orientationNotification, object: nil)
        #expect(hud.frame == host.bounds)
        hud.hide(animated: false)
        NotificationCenter.default.post(name: TMProgressHud.orientationNotification, object: nil)
    }

    @Test func foundationProgressCanBeReplacedAndDetached() {
        let hud = TMProgressHud(frame: .zero)
        let progress = Progress(totalUnitCount: 100)
        progress.completedUnitCount = 25
        hud.progressObject = progress
        #expect(hud.progressDisplayLink != nil)
        hud.updateProgressFromProgressObject()
        #expect(hud.progress == 0.25)
        hud.progressObject = progress
        hud.show(animated: false)
        hud.hide(animated: false)
        #expect(hud.progressDisplayLink == nil)
        hud.progressObject = nil
        hud.updateProgressFromProgressObject()
        let unchangedProgress = hud.progress
        hud.progress = unchangedProgress
    }
}
