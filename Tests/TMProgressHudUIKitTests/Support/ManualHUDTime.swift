import Foundation
@testable import TMProgressHudUIKit

@MainActor
final class ManualHUDTime {
    private(set) var instant = ContinuousClock.now
    private(set) var actions: [ScheduledAction] = []
    private(set) var requestedIntervals: [TimeInterval] = []

    var environment: TimingEnvironment {
        TimingEnvironment(
            now: { self.instant },
            schedule: { interval, action in
                let scheduled = ScheduledAction(action: action)
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
