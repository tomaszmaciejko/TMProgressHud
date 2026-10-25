import Foundation
@testable import TMProgressHudUIKit

@MainActor
final class ManualHUDTime {
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
