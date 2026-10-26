import Foundation
import Testing
import UIKit
@testable import TMProgressHudUIKit

@Suite(.serialized, .timeLimit(.minutes(1)))
@MainActor
struct LifecycleTests {
    @Test func shortWorkNeverBecomesVisible() throws {
        let time = ManualHUDTime()
        defer { time.invalidate() }
        let hud = TMProgressHud(frame: .zero)
        hud.setTimingEnvironment(time.environment)
        hud.graceTime = 10
        var callbacks = 0
        hud.completionBlock = { callbacks += 1 }
        hud.show(animated: false)
        #expect(hud.alpha == 0)
        let action = try #require(time.actions.last)
        hud.hide(animated: false)
        #expect(!action.isPending)
        action.fire()
        #expect(hud.alpha == 0)
        #expect(callbacks == 1)
    }

    @Test func graceAndMinimumDurationUseInjectedTime() throws {
        let time = ManualHUDTime()
        defer { time.invalidate() }
        let hud = TMProgressHud(frame: .zero)
        hud.setTimingEnvironment(time.environment)
        hud.graceTime = 10
        hud.minShowTime = 5
        hud.show(animated: false)
        try #require(time.actions.last).fire()
        #expect(hud.alpha == 1)
        time.advance(by: .seconds(2))
        hud.hide(animated: false)
        let minimumAction = try #require(time.actions.last)
        #expect(time.requestedIntervals.last == 3)
        #expect(hud.alpha == 1)
        minimumAction.fire()
        #expect(hud.alpha == 0)
    }

    @Test func showInvalidatesTrackedMinimumAndActualShowCancelsDelay() throws {
        let time = ManualHUDTime()
        defer { time.invalidate() }
        let hud = TMProgressHud(frame: .zero)
        hud.setTimingEnvironment(time.environment)
        hud.minShowTime = 10
        hud.show(animated: false)
        hud.hide(animated: false)
        let minimum = try #require(time.actions.last)
        hud.hide(animated: true, afterDelay: 20)
        let delay = try #require(time.actions.last)
        hud.show(animated: false)
        #expect(!minimum.isPending)
        #expect(!delay.isPending)
        hud.minShowTime = 0
        hud.hide(animated: false, afterDelay: 5)
        let replaced = try #require(time.actions.last)
        hud.hide(animated: true, afterDelay: 10)
        #expect(!replaced.isPending)
        time.actions.last?.fire()
        #expect(hud.hasHideRequest)
    }

    @Test func repeatedGraceCallsReplaceOutstandingAction() throws {
        let time = ManualHUDTime()
        defer { time.invalidate() }
        let hud = TMProgressHud(frame: .zero)
        hud.setTimingEnvironment(time.environment)
        hud.graceTime = 10
        hud.show(animated: false)
        let first = try #require(time.actions.last)
        hud.show(animated: false)
        #expect(!first.isPending)
        first.fire()
        #expect(hud.alpha == 0)
        time.actions.last?.fire()
        #expect(hud.alpha == 1)
        hud.hide(animated: false)
    }

    @Test func elapsedMinimumAndNegativeDelayRemainReferenceInputs() {
        let time = ManualHUDTime()
        defer { time.invalidate() }
        let hud = TMProgressHud(frame: .zero)
        hud.setTimingEnvironment(time.environment)
        hud.minShowTime = 1
        hud.graceTime = -1
        hud.show(animated: false)
        time.advance(by: .seconds(2))
        hud.hide(animated: false)
        #expect(time.requestedIntervals.isEmpty)
        #expect(hud.alpha == 0)
        hud.hide(animated: false, afterDelay: -1)
        time.actions.last?.fire()
        #expect(hud.hasHideRequest)
    }

    @Test func immediateShowCancelsPreviousGrace() throws {
        let time = ManualHUDTime()
        defer { time.invalidate() }
        let hud = TMProgressHud(frame: .zero)
        hud.setTimingEnvironment(time.environment)
        hud.graceTime = 10
        hud.show(animated: false)
        let oldGrace = try #require(time.actions.last)
        hud.graceTime = 0
        hud.minShowTime = 10
        hud.show(animated: false)
        time.advance(by: .seconds(2))
        oldGrace.fire()
        hud.hide(animated: false)
        #expect(time.requestedIntervals.last == 8)
    }

    @Test func immediateHideCancelsPendingMinimum() throws {
        let time = ManualHUDTime()
        defer { time.invalidate() }
        let hud = TMProgressHud(frame: .zero)
        hud.setTimingEnvironment(time.environment)
        hud.minShowTime = 10
        var calls = 0
        hud.completionBlock = { calls += 1 }
        hud.show(animated: false)
        hud.hide(animated: false)
        let oldMinimum = try #require(time.actions.last)
        hud.minShowTime = 0
        hud.hide(animated: false)
        oldMinimum.fire()
        #expect(calls == 1)
    }

    @Test func repeatedMinimumRequestsCannotHideNextPresentation() throws {
        let time = ManualHUDTime()
        defer { time.invalidate() }
        let hud = TMProgressHud(frame: .zero)
        hud.setTimingEnvironment(time.environment)
        hud.minShowTime = 10
        var callbacks = 0
        hud.completionBlock = { callbacks += 1 }
        hud.show(animated: false)
        hud.hide(animated: false)
        let obsolete = try #require(time.actions.last)
        hud.hide(animated: false)
        hud.show(animated: false)
        obsolete.fire()
        #expect(hud.alpha == 1)
        #expect(callbacks == 0)
        #expect(hud.bezelView.alpha == 1)
        hud.minShowTime = 0
        hud.hide(animated: false)
    }

    @Test func productionDelayedHideDeliversCompletion() async {
        let hud = TMProgressHud(frame: .zero)
        hud.show(animated: false)
        await withCheckedContinuation { continuation in
            hud.completionBlock = { continuation.resume() }
            hud.hide(animated: false, afterDelay: 0)
        }
        #expect(hud.alpha == 0)
        hud.completionBlock = nil
    }

    @Test func animationVariantsCompleteAndHide() async {
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        for type in [TMProgressHudAnimation.fade, .zoom, .zoomIn, .zoomOut] {
            let hud = TMProgressHud(view: host)
            host.addSubview(hud)
            hud.animationType = type
            hud.show(animated: true)
            #expect(hud.alpha == 1)
            await withCheckedContinuation { continuation in
                hud.completionBlock = { continuation.resume() }
                hud.hide(animated: true)
            }
            #expect(hud.alpha == 0)
            hud.completionBlock = nil
            hud.removeFromSuperview()
        }
    }

    @Test func animatedHideRemovesHUDFromHostBeforeCompletion() async {
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let hud = TMProgressHud.showAdded(to: host, animated: false)
        #expect(hud.superview === host)
        await withCheckedContinuation { continuation in
            hud.completionBlock = { [weak hud] in
                #expect(hud?.superview == nil)
                #expect(hud?.alpha == 0)
                continuation.resume()
            }
            hud.hide(animated: true)
        }
        #expect(!host.subviews.contains { $0 === hud })
        hud.completionBlock = nil
    }

    @Test func pendingGraceDoesNotRetainReleasedHUD() async {
        weak var reference: TMProgressHud?
        autoreleasepool {
            let hud = TMProgressHud(frame: .zero)
            hud.graceTime = 60
            hud.show(animated: false)
            reference = hud
        }
        #expect(reference == nil)
        await Task.yield()
    }
}
