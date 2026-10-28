import Foundation
import Testing
import UIKit
@testable import TMProgressHudUIKit

@MainActor
private final class CompletionDelegate: NSObject, TMProgressHudDelegate {
    var calls = 0
    func hudWasHidden(_ hud: TMProgressHud) { calls += 1 }
}

@Suite(.serialized)
@MainActor
struct CompletionLifecycleTests {
    @Test func completedCallbackDoesNotRetainTheHUD() {
        weak var reference: TMProgressHud?
        autoreleasepool {
            let hud = TMProgressHud(frame: .zero)
            reference = hud
            hud.completionBlock = { hud.label.text = "Done" }
            hud.show(animated: false)
            hud.hide(animated: false)
        }
        #expect(reference == nil)
        reference?.completionBlock = nil
    }

    @Test func callbackIsConsumedOnceAndCanInstallItsSuccessor() {
        let hud = TMProgressHud(frame: .zero)
        var events: [String] = []
        hud.completionBlock = {
            events.append("first")
            #expect(hud.completionBlock == nil)
            hud.completionBlock = { events.append("second") }
            hud.show(animated: false)
        }
        hud.show(animated: false)
        hud.hide(animated: false)
        hud.hide(animated: false)
        hud.show(animated: false)
        hud.hide(animated: false)
        #expect(events == ["first", "second"])
        #expect(hud.completionBlock == nil)
        hud.completionBlock = nil
    }

    @Test func requestCompletionSeesTheFinishedViewAndOnlyRunsOnce() {
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let hud = TMProgressHud.showAdded(to: host, animated: false)
        var events: [String] = []
        hud.completionBlock = { events.append("compatibility") }
        hud.hide(animated: false) { finished in
            #expect(finished === hud)
            #expect(finished.alpha == 0)
            #expect(finished.superview == nil)
            #expect(finished.completionBlock == nil)
            events.append("request")
        }
        hud.hide(animated: false) { _ in Issue.record("Repeated hide delivered a new completion") }
        #expect(events == ["request", "compatibility"])
    }

    @Test func supersededRequestDoesNotCompleteTheNextPresentation() throws {
        let time = ManualHUDTime()
        defer { time.invalidate() }
        let hud = TMProgressHud(frame: .zero)
        hud.setTimingEnvironment(time.environment)
        hud.minShowTime = 10
        var calls = 0
        hud.show(animated: false)
        hud.hide(animated: false) { _ in calls += 1 }
        let obsolete = try #require(time.actions.last)
        hud.show(animated: false)
        obsolete.fire()
        hud.minShowTime = 0
        hud.hide(animated: false)
        #expect(calls == 0)
    }

    @Test func firstMinimumHideKeepsItsCompletion() {
        let time = ManualHUDTime()
        defer { time.invalidate() }
        let hud = TMProgressHud(frame: .zero)
        hud.setTimingEnvironment(time.environment)
        hud.minShowTime = 10
        var calls: [String] = []
        hud.show(animated: false)
        hud.hide(animated: false) { _ in calls.append("first") }
        hud.hide(animated: false) { _ in calls.append("second") }
        time.actions.last?.fire()
        #expect(calls == ["first"])
    }

    @Test func pendingRequestDoesNotRetainTheHUD() {
        weak var reference: TMProgressHud?
        autoreleasepool {
            let hud = TMProgressHud(frame: .zero)
            hud.minShowTime = 60
            hud.show(animated: false)
            hud.hide(animated: false) { _ in Issue.record("Released HUD completed") }
            reference = hud
        }
        #expect(reference == nil)
    }

    @Test func requestCompletionMayPresentAndHideAgain() {
        let hud = TMProgressHud(frame: .zero)
        var calls: [String] = []
        hud.show(animated: false)
        hud.hide(animated: false) { finished in
            calls.append("first")
            finished.show(animated: false)
            finished.hide(animated: false) { _ in calls.append("second") }
        }
        #expect(calls == ["first", "second"])
    }

    @Test func changingDelegateInCompletionDoesNotRedirectThePreviousEvent() {
        let hud = TMProgressHud(frame: .zero)
        let first = CompletionDelegate()
        let next = CompletionDelegate()
        hud.delegate = first
        hud.completionBlock = { hud.delegate = next }
        hud.show(animated: false)
        hud.hide(animated: false)
        #expect(first.calls == 1)
        #expect(next.calls == 0)
        hud.completionBlock = nil
    }
}
