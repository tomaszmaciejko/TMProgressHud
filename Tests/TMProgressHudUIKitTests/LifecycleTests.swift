import Foundation
import Testing
import UIKit
@testable import TMProgressHudUIKit

@MainActor
private final class ManualTime {
    var instant = ContinuousClock.now
    var actions: [HUDScheduledAction] = []
    var requestedIntervals: [TimeInterval] = []

    var environment: HUDTimingEnvironment {
        HUDTimingEnvironment(
            now: { self.instant },
            schedule: { interval, action in
                let scheduled = HUDScheduledAction(action: action)
                self.actions.append(scheduled)
                self.requestedIntervals.append(interval)
                return scheduled
            }
        )
    }

    func invalidate() { for action in actions { action.cancel() } }
}

@Suite(.serialized)
@MainActor
struct LifecycleTests {
    @Test func shortWorkNeverBecomesVisible() throws {
        let time = ManualTime()
        defer { time.invalidate() }
        let hud = TMProgressHud(frame: .zero)
        hud.timing = time.environment
        hud.graceTime = 10
        var callbacks = 0
        hud.completionBlock = { callbacks += 1 }
        hud.show(animated: false)
        #expect(hud.alpha == 0)
        let action = try #require(hud.graceAction)
        hud.hide(animated: false)
        #expect(!action.isPending)
        action.fire()
        hud.handleGraceAction()
        #expect(hud.alpha == 0)
        #expect(callbacks == 1)
    }

    @Test func graceAndMinimumDurationUseInjectedTime() throws {
        let time = ManualTime()
        defer { time.invalidate() }
        let hud = TMProgressHud(frame: .zero)
        hud.timing = time.environment
        hud.graceTime = 10
        hud.minShowTime = 5
        hud.show(animated: false)
        try #require(hud.graceAction).fire()
        #expect(hud.alpha == 1)
        time.instant = time.instant.advanced(by: .seconds(2))
        hud.hide(animated: false)
        let minimumAction = try #require(hud.minimumShowAction)
        #expect(time.requestedIntervals.last == 3)
        #expect(hud.alpha == 1)
        minimumAction.fire()
        #expect(hud.alpha == 0)
    }

    @Test func showInvalidatesTrackedMinimumAndActualShowCancelsDelay() throws {
        let time = ManualTime()
        defer { time.invalidate() }
        let hud = TMProgressHud(frame: .zero)
        hud.timing = time.environment
        hud.minShowTime = 10
        hud.show(animated: false)
        hud.hide(animated: false)
        let minimum = try #require(hud.minimumShowAction)
        hud.hide(animated: true, afterDelay: 20)
        let delay = try #require(hud.delayedHideAction)
        hud.show(animated: false)
        #expect(!minimum.isPending)
        #expect(!delay.isPending)
        hud.minShowTime = 0
        hud.hide(animated: false, afterDelay: 5)
        let replaced = try #require(hud.delayedHideAction)
        hud.hide(animated: true, afterDelay: 10)
        #expect(!replaced.isPending)
        hud.delayedHideAction?.fire()
        #expect(hud.hasFinished)
        #expect(hud.useAnimation)
    }

    @Test func repeatedGraceCallsReplaceOutstandingAction() throws {
        let time = ManualTime()
        defer { time.invalidate() }
        let hud = TMProgressHud(frame: .zero)
        hud.timing = time.environment
        hud.graceTime = 10
        hud.show(animated: false)
        let first = try #require(hud.graceAction)
        hud.show(animated: false)
        #expect(!first.isPending)
        first.fire()
        #expect(hud.alpha == 0)
        hud.graceAction?.fire()
        #expect(hud.alpha == 1)
        hud.hide(animated: false)
    }

    @Test func elapsedMinimumAndNegativeDelayRemainReferenceInputs() {
        let time = ManualTime()
        defer { time.invalidate() }
        let hud = TMProgressHud(frame: .zero)
        hud.timing = time.environment
        hud.minShowTime = 1
        hud.graceTime = -1
        hud.show(animated: false)
        time.instant = time.instant.advanced(by: .seconds(2))
        hud.hide(animated: false)
        #expect(hud.minimumShowAction == nil)
        #expect(hud.alpha == 0)
        hud.hide(animated: false, afterDelay: -1)
        hud.delayedHideAction?.fire()
        #expect(hud.hasFinished)
    }

    @Test func immediateShowCancelsPreviousGrace() throws {
        let time = ManualTime()
        defer { time.invalidate() }
        let hud = TMProgressHud(frame: .zero)
        hud.timing = time.environment
        hud.graceTime = 10
        hud.show(animated: false)
        let oldGrace = try #require(hud.graceAction)
        hud.graceTime = 0
        hud.minShowTime = 10
        hud.show(animated: false)
        time.instant = time.instant.advanced(by: .seconds(2))
        oldGrace.fire()
        hud.hide(animated: false)
        #expect(time.requestedIntervals.last == 8)
    }

    @Test func immediateHideCancelsPendingMinimum() throws {
        let time = ManualTime()
        defer { time.invalidate() }
        let hud = TMProgressHud(frame: .zero)
        hud.timing = time.environment
        hud.minShowTime = 10
        var calls = 0
        hud.completionBlock = { calls += 1 }
        hud.show(animated: false)
        hud.hide(animated: false)
        let oldMinimum = try #require(hud.minimumShowAction)
        hud.minShowTime = 0
        hud.hide(animated: false)
        oldMinimum.fire()
        #expect(calls == 1)
    }

    @Test func repeatedMinimumRequestsCannotHideNextPresentation() throws {
        let time = ManualTime()
        defer { time.invalidate() }
        let hud = TMProgressHud(frame: .zero)
        hud.timing = time.environment
        hud.minShowTime = 10
        var callbacks = 0
        hud.completionBlock = { callbacks += 1 }
        hud.show(animated: false)
        hud.hide(animated: false)
        let obsolete = try #require(hud.minimumShowAction)
        hud.hide(animated: false)
        hud.show(animated: false)
        obsolete.fire()
        #expect(hud.alpha == 1)
        #expect(callbacks == 0)
        #expect(hud.bezelView.alpha == 1)
        hud.minShowTime = 0
        hud.hide(animated: false)
    }

    @Test func productionSchedulerRegistersAndCanCancelGrace() throws {
        let hud = TMProgressHud(frame: .zero)
        hud.graceTime = 60
        hud.show(animated: false)
        let action = try #require(hud.graceAction)
        #expect(action.isPending)
        hud.hide(animated: false)
        #expect(!action.isPending)
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

    @Test func completionWithoutFinishedFlagPreservesReshownVisibility() {
        let hud = TMProgressHud(frame: .zero)
        hud.show(animated: false)
        hud.done()
        #expect(hud.alpha == 1)
        hud.hide(animated: true)
        #expect(hud.hasFinished)
    }
}
