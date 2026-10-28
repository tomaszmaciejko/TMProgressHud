// SPDX-License-Identifier: MIT
// Portions Copyright 2009-2020 Matej Bukovinski.
// Swift port Copyright 2026 Tomasz Maciejko and TMProgressHud contributors.
// Reference: 4a7c5f3e53cdea77c5dcb8578c2ee5acacdf6781. See THIRD_PARTY_NOTICES.md.
import Foundation

/// A monotonic clock and typed scheduling boundary, replaceable in deterministic tests.
@MainActor
struct HUDTimingEnvironment {
    var now: () -> ContinuousClock.Instant = { .now }
    var schedule: (TimeInterval, @escaping @MainActor () -> Void) -> HUDScheduledAction = {
        HUDScheduledAction.scheduled(after: $0, action: $1)
    }

    func elapsed(since instant: ContinuousClock.Instant) -> TimeInterval {
        let duration = instant.duration(to: now()).components
        let attosecondsPerSecond = 1e18
        return TimeInterval(duration.seconds) + TimeInterval(duration.attoseconds) / attosecondsPerSecond
    }
}
