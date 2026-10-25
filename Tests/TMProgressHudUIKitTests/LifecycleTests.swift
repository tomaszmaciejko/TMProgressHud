import Foundation
import Testing
import UIKit
@testable import TMProgressHudUIKit

@MainActor
private final class ManualTime {
    var date = Date(timeIntervalSince1970: 1_000)
    var timers: [Timer] = []
    var requestedIntervals: [TimeInterval] = []

    var environment: HUDTimingEnvironment {
        HUDTimingEnvironment(
            now: { self.date },
            schedule: { interval, target, action, info in
                let timer = Timer(
                    timeInterval: interval, target: target, selector: action, userInfo: info, repeats: false)
                self.timers.append(timer)
                self.requestedIntervals.append(interval)
                return timer
            }
        )
    }

    func invalidate() { for timer in timers { timer.invalidate() } }
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
        let timer = try #require(hud.graceTimer)
        hud.hide(animated: false)
        #expect(!timer.isValid)
        timer.fire()
        hud.handleGraceTimer()
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
        try #require(hud.graceTimer).fire()
        #expect(hud.alpha == 1)
        time.date = time.date.addingTimeInterval(2)
        hud.hide(animated: false)
        let minimumTimer = try #require(hud.minShowTimer)
        #expect(time.requestedIntervals.last == 3)
        #expect(hud.alpha == 1)
        minimumTimer.fire()
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
        let minimum = try #require(hud.minShowTimer)
        hud.hide(animated: true, afterDelay: 20)
        let delay = try #require(hud.hideDelayTimer)
        hud.show(animated: false)
        #expect(!minimum.isValid)
        #expect(!delay.isValid)
        hud.minShowTime = 0
        hud.hide(animated: false, afterDelay: 5)
        let replaced = try #require(hud.hideDelayTimer)
        hud.hide(animated: true, afterDelay: 10)
        #expect(!replaced.isValid)
        hud.hideDelayTimer?.fire()
        #expect(hud.hasFinished)
    }

    @Test func repeatedGraceCallsKeepOriginalOutstandingTimerBehavior() throws {
        let time = ManualTime()
        defer { time.invalidate() }
        let hud = TMProgressHud(frame: .zero)
        hud.timing = time.environment
        hud.graceTime = 10
        hud.show(animated: false)
        let first = try #require(hud.graceTimer)
        hud.show(animated: false)
        #expect(first.isValid)
        first.fire()
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
        time.date = time.date.addingTimeInterval(2)
        hud.hide(animated: false)
        #expect(hud.minShowTimer == nil)
        #expect(hud.alpha == 0)
        hud.hide(animated: false, afterDelay: -1)
        hud.handleHideTimer(Timer())
        #expect(hud.hasFinished)
    }

    @Test func productionSchedulerRegistersAndCanCancelGrace() throws {
        let hud = TMProgressHud(frame: .zero)
        hud.graceTime = 60
        hud.show(animated: false)
        let timer = try #require(hud.graceTimer)
        #expect(timer.isValid)
        hud.hide(animated: false)
        #expect(!timer.isValid)
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

    @Test func completionWithoutFinishedFlagPreservesReshownVisibility() {
        let hud = TMProgressHud(frame: .zero)
        hud.show(animated: false)
        hud.done()
        #expect(hud.alpha == 1)
        hud.hide(animated: true)
        #expect(hud.hasFinished)
    }
}
