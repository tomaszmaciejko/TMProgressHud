import Testing
import UIKit
import TMProgressHudUIKit

@MainActor
private final class ScenarioProgressView: UIView, TMProgressHudProgressReporting {
    var progress: Float = 0
    override var intrinsicContentSize: CGSize { CGSize(width: 28, height: 28) }
}

@MainActor
private final class ScenarioCallbacks {
    var hideCount = 0
}

@Suite(.serialized, .timeLimit(.minutes(1)))
@MainActor
struct ConsumerScenarioTests {
    @Test(
        arguments: [
            TMProgressHudMode.indeterminate, .determinate, .annularDeterminate,
            .determinateHorizontalBar, .customView, .text,
        ],
        [
            TMProgressHudMode.indeterminate, .determinate, .annularDeterminate,
            .determinateHorizontalBar, .customView, .text,
        ])
    func everyContentTransitionKeepsTheOperationState(from: TMProgressHudMode, to: TMProgressHudMode) throws {
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 400, height: 600))
        let hud = TMProgressHud.showAdded(to: host, animated: false)
        defer { hud.hide(animated: false) }
        let custom = ScenarioProgressView()
        hud.label.text = "Downloading"
        hud.label.textColor = .orange
        hud.detailsLabel.text = "File 2 of 3"
        hud.button.setTitle("Cancel", for: .normal)
        hud.button.addAction(UIAction { _ in }, for: .primaryActionTriggered)
        hud.setProgressSource(.manual(0.625))
        hud.setContent(selection(for: from, custom: custom))
        host.layoutIfNeeded()
        hud.setContent(selection(for: to, custom: custom))
        host.layoutIfNeeded()
        #expect(hud.mode == to)
        #expect(hud.progress == 0.625)
        #expect(hud.label.text == "Downloading")
        #expect(hud.label.textColor == UIColor.orange)
        #expect(hud.detailsLabel.text == "File 2 of 3")
        #expect(hud.button.currentTitle == "Cancel")
        #expect(hud.alpha == 1)
        #expect(hud.bezelView.transform == .identity)
        let indicators = hud.bezelView.subviews.filter {
            $0 is UIActivityIndicatorView || $0 is TMRoundProgressView || $0 is TMBarProgressView || $0 === custom
        }
        #expect(indicators.count == (to == .text ? 0 : 1))
        if to == .text { return }
        let indicator = try #require(indicators.first)
        switch to {
        case .indeterminate:
            let spinner = try #require(indicator as? UIActivityIndicatorView)
            #expect(spinner.isAnimating)
        case .determinate, .annularDeterminate:
            let round = try #require(indicator as? TMRoundProgressView)
            #expect(round.isAnnular == (to == .annularDeterminate))
            #expect(round.progress == 0.625)
        case .determinateHorizontalBar:
            let bar = try #require(indicator as? TMBarProgressView)
            #expect(bar.progress == 0.625)
        case .customView:
            #expect(indicator === custom)
            #expect(custom.progress == 0.625)
        case .text: Issue.record("Text content must have no indicator.")
        }
    }

    @Test func cancelActionCancelsTheOperationAndCompletesDismissalOnce() throws {
        let window = try makeHostedTestWindow()
        defer { window.isHidden = true }
        let host = try #require(window.rootViewController?.view)
        let operation = Progress(totalUnitCount: 100)
        operation.completedUnitCount = 30
        let hud = TMProgressHud.showAdded(to: host, animated: false)
        let callbacks = ScenarioCallbacks()
        hud.setContent(.ring)
        hud.setProgressSource(.observed(operation))
        hud.label.text = "Downloading"
        hud.button.setTitle("Cancel", for: .normal)
        hud.button.addAction(
            UIAction { [weak hud] _ in
                operation.cancel()
                hud?.hide(animated: false) { _ in callbacks.hideCount += 1 }
            }, for: .primaryActionTriggered)
        window.layoutIfNeeded()
        #expect(hud.progress == 0.3)
        #expect(!operation.isCancelled)
        hud.button.sendActions(for: .primaryActionTriggered)
        #expect(operation.isCancelled)
        #expect(hud.superview == nil)
        #expect(hud.alpha == 0)
        #expect(callbacks.hideCount == 1)
        hud.button.sendActions(for: .primaryActionTriggered)
        hud.hide(animated: false) { _ in callbacks.hideCount += 1 }
        #expect(callbacks.hideCount == 1)
    }

    @Test func interactionCanBeBlockedOrPassedThroughAndReturnsAfterDismissal() throws {
        let window = try makeHostedTestWindow()
        defer { window.isHidden = true }
        let host = try #require(window.rootViewController?.view)
        let underlying = UIButton(frame: host.bounds)
        host.addSubview(underlying)
        let hud = TMProgressHud.showAdded(to: host, animated: false)
        defer { hud.hide(animated: false) }
        window.layoutIfNeeded()
        let point = CGPoint(x: 5, y: 5)
        let blocked = try #require(host.hitTest(point, with: nil))
        #expect(blocked === hud || blocked.isDescendant(of: hud))
        hud.isUserInteractionEnabled = false
        let passedThrough = try #require(host.hitTest(point, with: nil))
        #expect(passedThrough === underlying || passedThrough.isDescendant(of: underlying))
        hud.isUserInteractionEnabled = true
        hud.hide(animated: false)
        let restored = try #require(host.hitTest(point, with: nil))
        #expect(restored === underlying || restored.isDescendant(of: underlying))
    }

    @Test(
        arguments: [TMProgressHudAnimation.fade, .zoom, .zoomIn, .zoomOut],
        [TMProgressHudMotionPolicy.full, .reduced])
    func completedAnimatedDismissalCanBeReusedWithNormalGeometry(
        animation: TMProgressHudAnimation, motion: TMProgressHudMotionPolicy
    ) async throws {
        let window = try makeHostedTestWindow()
        defer { window.isHidden = true }
        let host = try #require(window.rootViewController?.view)
        let hud = TMProgressHud(view: host)
        host.addSubview(hud)
        defer { hud.hide(animated: false); hud.removeFromSuperview() }
        hud.setContent(.ring)
        hud.setProgressSource(.manual(0.625))
        hud.setLayout(.init(position: .init(vertical: .bottom)))
        hud.label.text = "Downloading"
        hud.motionPolicy = motion
        hud.animationType = animation
        hud.show(animated: false)
        window.layoutIfNeeded()
        let originalBounds = hud.bezelView.bounds
        let originalCenter = hud.bezelView.center
        let completed = CallbackExpectation()
        hud.hide(animated: true) { _ in completed.signal() }
        try await completed.wait()
        #expect(hud.alpha == 0)
        hud.show(animated: false)
        window.layoutIfNeeded()
        #expect(hud.alpha == 1)
        #expect(hud.bezelView.alpha == 1)
        #expect(hud.bezelView.transform == .identity)
        #expect(hud.bezelView.bounds == originalBounds)
        #expect(hud.bezelView.center == originalCenter)
        #expect(hud.progress == 0.625)
    }

    private func selection(for mode: TMProgressHudMode, custom: UIView) -> TMProgressHudContent {
        switch mode {
        case .indeterminate: .activity
        case .determinate: .pie
        case .annularDeterminate: .ring
        case .determinateHorizontalBar: .bar
        case .customView: .custom(custom)
        case .text: .text
        }
    }
}
