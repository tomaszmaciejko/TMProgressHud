import Foundation
@testable import TMProgressHudUIKit

@MainActor
final class ManualHUDTime {
    private(set) var instant = ContinuousClock.now
    private(set) var actions: [HUDScheduledAction] = []
    private(set) var requestedIntervals: [TimeInterval] = []

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

    func advance(by duration: Duration) {
        instant = instant.advanced(by: duration)
    }

    func invalidate() {
        for action in actions {
            action.cancel()
        }
    }
}
