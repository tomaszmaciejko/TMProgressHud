// SPDX-License-Identifier: MIT
// Portions Copyright 2009-2020 Matej Bukovinski.
// Swift port Copyright 2026 Tomasz Maciejko and TMProgressHud contributors.
// Reference: 4a7c5f3e53cdea77c5dcb8578c2ee5acacdf6781. See THIRD_PARTY_NOTICES.md.
import Foundation

/// A one-shot main-actor action whose owner can cancel it before delivery.
@MainActor
final class HUDScheduledAction {
    private var action: (@MainActor () -> Void)?
    private var task: Task<Void, Never>?

    var isPending: Bool { action != nil }

    init(action: @escaping @MainActor () -> Void) { self.action = action }

    deinit { task?.cancel() }

    static func scheduled(after interval: TimeInterval, action: @escaping @MainActor () -> Void) -> HUDScheduledAction {
        let scheduled = HUDScheduledAction(action: action)
        // Unrepresentable positive delays stay pending until cancelled.
        guard interval < Double(Int64.max) || interval.isNaN else { return scheduled }
        let delay = interval > 0 ? interval : 0
        // Measure the delay from this request, even if the main actor is busy.
        let deadline = ContinuousClock.now.advanced(by: .seconds(delay))
        scheduled.task = Task { [weak scheduled] in
            do {
                try await Task.sleep(until: deadline, clock: .continuous)
            } catch {
                // ContinuousClock.sleep only fails when this task is cancelled.
                return
            }
            scheduled?.fire()
        }
        return scheduled
    }

    func cancel() {
        action = nil
        task?.cancel()
        task = nil
    }

    func fire() {
        let action = action
        let completedTask = task
        self.action = nil
        task = nil
        action?()
        completedTask?.cancel()
    }
}
