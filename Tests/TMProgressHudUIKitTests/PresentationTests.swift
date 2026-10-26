import Foundation
import Testing
@testable import TMProgressHudUIKit

@MainActor
private final class PresentationSpy: HUDPresentationHost {
    var graceTime: TimeInterval = 0
    var minShowTime: TimeInterval = 0
    var shows: [Bool] = []
    var hides: [Bool] = []
    var completions: [@MainActor () -> Void] = []
    var finished = 0
    var onFinish: (@MainActor () -> Void)?

    func showPresentation(animated: Bool) { shows.append(animated) }
    func hidePresentation(animated: Bool, completion: @escaping @MainActor () -> Void) {
        hides.append(animated)
        completions.append(completion)
    }
    func finishPresentation() {
        finished += 1
        onFinish?()
    }
}

@Suite(.serialized)
@MainActor
struct PresentationTests {
    @Test func immediateTransitionsDeliverOneCompletion() throws {
        let host = PresentationSpy()
        let presentation = HUDPresentation(host: host)
        #expect(presentation.phase == .idle)
        #expect(!presentation.hasHideRequest)
        presentation.show(animated: false)
        #expect(presentation.phase == .visible)
        presentation.hide(animated: false)
        #expect(presentation.phase == .hiding)
        #expect(presentation.hasHideRequest)
        let completion = try #require(host.completions.first)
        completion()
        completion()
        presentation.hide(animated: true)
        presentation.hide(animated: true, afterDelay: 10)
        #expect(presentation.phase == .hidden)
        #expect(host.finished == 1)
        #expect(host.hides == [false])
    }

    @Test func graceAndMinimumUseExplicitPhases() throws {
        let host = PresentationSpy()
        let time = ManualHUDTime()
        defer { time.invalidate() }
        let presentation = HUDPresentation(host: host)
        presentation.timing = time.environment
        host.graceTime = 3
        host.minShowTime = 5
        presentation.show(animated: true)
        #expect(presentation.phase == .waitingForGrace)
        #expect(!presentation.hasHideRequest)
        time.actions.last?.fire()
        #expect(host.shows == [true])
        time.instant = time.instant.advanced(by: .seconds(2))
        presentation.hide(animated: false)
        #expect(presentation.phase == .waitingForMinimum)
        #expect(presentation.hasHideRequest)
        #expect(time.requestedIntervals.last == 3)
        time.actions.last?.fire()
        #expect(presentation.phase == .hiding)
        let completion = try #require(host.completions.first)
        completion()
        #expect(host.finished == 1)
    }

    @Test func obsoleteAnimationCannotFinishNewPresentation() throws {
        let host = PresentationSpy()
        let presentation = HUDPresentation(host: host)
        presentation.show(animated: true)
        presentation.hide(animated: true)
        let oldCompletion = try #require(host.completions.first)
        host.graceTime = 10
        presentation.show(animated: false)
        oldCompletion()
        #expect(presentation.phase == .visible)
        #expect(!presentation.hasHideRequest)
        #expect(host.finished == 0)
        presentation.hide(animated: false)
        let currentCompletion = try #require(host.completions.last)
        currentCompletion()
        #expect(host.finished == 1)
        #expect(host.hides == [true, false])
    }

    @Test func visiblePresentationDoesNotReapplyGrace() {
        let host = PresentationSpy()
        let time = ManualHUDTime()
        defer { time.invalidate() }
        let presentation = HUDPresentation(host: host)
        presentation.timing = time.environment
        host.graceTime = 5
        presentation.show(animated: true)
        time.actions.last?.fire()
        presentation.show(animated: false)
        #expect(presentation.phase == .visible)
        #expect(time.requestedIntervals == [5])
        #expect(host.shows == [true, false])
    }

    @Test func delayedHideIsReplacedAndNewShowCancelsIt() throws {
        let host = PresentationSpy()
        let time = ManualHUDTime()
        defer { time.invalidate() }
        let presentation = HUDPresentation(host: host)
        presentation.timing = time.environment
        presentation.hide(animated: false, afterDelay: 5)
        let beforeShow = try #require(time.actions.last)
        presentation.show(animated: false)
        beforeShow.fire()
        #expect(host.hides.isEmpty)
        presentation.hide(animated: true, afterDelay: 1)
        let replaced = try #require(time.actions.last)
        presentation.hide(animated: false, afterDelay: 2)
        replaced.fire()
        #expect(host.hides.isEmpty)
        time.actions.last?.fire()
        #expect(host.hides == [false])
        presentation.hide(animated: true, afterDelay: 3)
        #expect(time.requestedIntervals == [5, 1, 2])
    }

    @Test(arguments: [false, true])
    func hidingBeforeVisibilityDoesNotAnimate(withGrace: Bool) throws {
        let host = PresentationSpy()
        let time = ManualHUDTime()
        defer { time.invalidate() }
        let presentation = HUDPresentation(host: host)
        presentation.timing = time.environment
        if withGrace {
            host.graceTime = 10
            presentation.show(animated: true)
        }
        presentation.hide(animated: true)
        #expect(host.hides == [false])
        let completion = try #require(host.completions.first)
        completion()
        time.actions.last?.fire()
        #expect(host.shows.isEmpty)
        #expect(presentation.phase == .hidden)
    }

    @Test func completionCanReentrantlyStartNextPresentation() throws {
        let host = PresentationSpy()
        let presentation = HUDPresentation(host: host)
        host.onFinish = { presentation.show(animated: false) }
        presentation.show(animated: false)
        presentation.hide(animated: false)
        let oldCompletion = try #require(host.completions.first)
        oldCompletion()
        oldCompletion()
        #expect(host.finished == 1)
        #expect(presentation.phase == .visible)
        #expect(!presentation.hasHideRequest)
        host.onFinish = nil
    }

    @Test func presentationAndHostReleaseWithPendingWork() {
        let time = ManualHUDTime()
        defer { time.invalidate() }
        weak var hostReference: PresentationSpy?
        weak var presentationReference: HUDPresentation?
        autoreleasepool {
            let host = PresentationSpy()
            let presentation = HUDPresentation(host: host)
            presentation.timing = time.environment
            host.graceTime = 60
            presentation.show(animated: true)
            hostReference = host
            presentationReference = presentation
        }
        #expect(hostReference == nil)
        #expect(presentationReference == nil)
        time.actions.last?.fire()
    }

    @Test func minimumAndDelayedHideReadCurrentConfiguration() throws {
        let host = PresentationSpy()
        let time = ManualHUDTime()
        defer { time.invalidate() }
        let presentation = HUDPresentation(host: host)
        presentation.timing = time.environment
        presentation.show(animated: false)
        presentation.hide(animated: true, afterDelay: 5)
        host.minShowTime = 10
        time.instant = time.instant.advanced(by: .seconds(3))
        time.actions.last?.fire()
        #expect(presentation.phase == .waitingForMinimum)
        #expect(time.requestedIntervals.last == 7)
        let oldMinimum = try #require(time.actions.last)
        host.minShowTime = 0
        presentation.hide(animated: false)
        oldMinimum.fire()
        #expect(host.hides == [false])
    }
}
