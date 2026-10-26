import Foundation
import Testing
@testable import TMProgressHudUIKit

@Suite(.serialized, .timeLimit(.minutes(1)))
@MainActor
struct SchedulingTests {
    @Test func actionsAreOneShotAndCancellationIsIdempotent() {
        var calls = 0
        let pending = HUDScheduledAction { calls += 1 }
        #expect(pending.isPending)
        pending.fire()
        pending.fire()
        pending.cancel()
        #expect(!pending.isPending)
        #expect(calls == 1)
        let cancelled = HUDScheduledAction { calls += 1 }
        cancelled.cancel()
        cancelled.cancel()
        cancelled.fire()
        #expect(calls == 1)
    }

    @Test(arguments: [0.0, -1.0, -Double.infinity, Double.nan])
    func immediateActionsRunOnTheMainActor(interval: Double) async throws {
        var scheduled: HUDScheduledAction?
        var calls = 0
        let completed = CallbackExpectation()
        scheduled = HUDScheduledAction.scheduled(after: interval) {
            #expect(!Task.isCancelled)
            calls += 1
            completed.signal()
        }
        #expect(calls == 0)
        try await completed.wait()
        #expect(calls == 1)
        #expect(scheduled?.isPending == false)
        scheduled?.fire()
        #expect(calls == 1)
    }

    @Test func cancellationStopsQueuedDelivery() async {
        var calls = 0
        let pending = HUDScheduledAction.scheduled(after: 0) { calls += 1 }
        pending.cancel()
        await Task.yield()
        #expect(calls == 0)
        #expect(!pending.isPending)
    }

    @Test func droppingOwnerReleasesPendingAction() async {
        weak var reference: HUDScheduledAction?
        autoreleasepool {
            let pending = HUDScheduledAction.scheduled(after: 60) { Issue.record("Released action fired") }
            reference = pending
        }
        #expect(reference == nil)
        await Task.yield()
    }

    @Test(arguments: [1e15, Double.infinity, Double.greatestFiniteMagnitude])
    func longPositiveDelaysRemainCancellable(interval: Double) {
        let pending = HUDScheduledAction.scheduled(after: interval) { Issue.record("Unbounded delay fired") }
        #expect(pending.isPending)
        pending.cancel()
        #expect(!pending.isPending)
    }

    @Test func elapsedTimePreservesFractionalSeconds() {
        let start = ContinuousClock.now
        let environment = HUDTimingEnvironment(now: { start.advanced(by: .milliseconds(1250)) })
        #expect(environment.elapsed(since: start) == 1.25)
    }
}
