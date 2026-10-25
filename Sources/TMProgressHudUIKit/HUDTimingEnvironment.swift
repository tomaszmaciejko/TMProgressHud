// SPDX-License-Identifier: MIT
// Portions Copyright 2009-2020 Matej Bukovinski.
// Swift port Copyright 2026 Tomasz Maciejko and TMProgressHud contributors.
// Reference: 4a7c5f3e53cdea77c5dcb8578c2ee5acacdf6781. See THIRD_PARTY_NOTICES.md.
import Foundation

// Injected clock/scheduler preserve the reference's wall-time semantics in 1.0.
@MainActor
struct HUDTimingEnvironment {
    var now: () -> Date = { Date() }
    var schedule: (TimeInterval, Any, Selector, Any?) -> Timer = { interval, target, action, info in
        let timer = Timer(timeInterval: interval, target: target, selector: action, userInfo: info, repeats: false)
        RunLoop.current.add(timer, forMode: .common)
        return timer
    }
}
