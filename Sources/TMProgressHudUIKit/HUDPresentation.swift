// SPDX-License-Identifier: MIT
// Portions Copyright 2009-2020 Matej Bukovinski.
// Swift port Copyright 2026 Tomasz Maciejko and TMProgressHud contributors.
// Reference: 4a7c5f3e53cdea77c5dcb8578c2ee5acacdf6781. See THIRD_PARTY_NOTICES.md.
import Foundation

/// The UI effects and live timing settings needed by a presentation.
@MainActor
protocol HUDPresentationHost: AnyObject {
    var graceTime: TimeInterval { get }
    var minShowTime: TimeInterval { get }
    func showPresentation(animated: Bool)
    func hidePresentation(animated: Bool, completion: @escaping @MainActor () -> Void)
    func finishPresentation()
}

/// Owns one presentation's phases, scheduled work and completion delivery.
@MainActor
final class HUDPresentation {
    enum Phase {
        case idle, waitingForGrace, visible, waitingForMinimum, hiding, hidden
    }

    private(set) var phase: Phase = .idle
    var timing = HUDTimingEnvironment()
    private weak var host: (any HUDPresentationHost)?
    private var generation = UUID()
    private var shownAt: ContinuousClock.Instant?
    private var graceAction: HUDScheduledAction? { didSet { oldValue?.cancel() } }
    private var minimumAction: HUDScheduledAction? { didSet { oldValue?.cancel() } }
    private var delayedHideAction: HUDScheduledAction? { didSet { oldValue?.cancel() } }

    var isShowingContent: Bool { phase == .visible || phase == .waitingForMinimum }

    var hasFinished: Bool {
        switch phase {
        case .waitingForMinimum, .hiding, .hidden: true
        case .idle, .waitingForGrace, .visible: false
        }
    }

    init(host: any HUDPresentationHost) { self.host = host }

    func show(animated: Bool) {
        let wasPresented = phase == .visible || phase == .waitingForMinimum || phase == .hiding
        generation = UUID()
        cancelScheduledActions()
        shownAt = nil
        phase = .waitingForGrace
        let current = generation
        let grace = host?.graceTime ?? 0
        if grace > 0 && !wasPresented {
            graceAction = timing.schedule(grace) { [weak self] in
                self?.reveal(animated: animated, generation: current)
            }
        } else {
            reveal(animated: animated, generation: current)
        }
    }

    func hide(animated: Bool) {
        guard phase != .hidden && phase != .hiding else { return }
        graceAction = nil
        minimumAction = nil
        delayedHideAction = nil
        let current = generation
        let minimum = host?.minShowTime ?? 0
        if minimum > 0, let shownAt {
            let elapsed = timing.elapsed(since: shownAt)
            if elapsed < minimum {
                phase = .waitingForMinimum
                minimumAction = timing.schedule(minimum - elapsed) { [weak self] in
                    self?.beginHide(animated: animated, generation: current)
                }
                return
            }
        }
        beginHide(animated: animated, generation: current)
    }

    func hide(animated: Bool, afterDelay delay: TimeInterval) {
        guard phase != .hidden && phase != .hiding else { return }
        let current = generation
        delayedHideAction = timing.schedule(delay) { [weak self] in
            guard let self, self.generation == current else { return }
            self.hide(animated: animated)
        }
    }

    private func reveal(animated: Bool, generation current: UUID) {
        guard current == generation && phase == .waitingForGrace else { return }
        graceAction = nil
        shownAt = timing.now()
        phase = .visible
        host?.showPresentation(animated: animated)
    }

    private func beginHide(animated: Bool, generation current: UUID) {
        guard current == generation else { return }
        let wasVisible = shownAt != nil
        cancelScheduledActions()
        shownAt = nil
        phase = .hiding
        host?.hidePresentation(animated: animated && wasVisible) { [weak self] in
            self?.finish(generation: current)
        }
    }

    private func finish(generation current: UUID) {
        guard current == generation && phase == .hiding else { return }
        phase = .hidden
        host?.finishPresentation()
    }

    private func cancelScheduledActions() {
        graceAction = nil
        minimumAction = nil
        delayedHideAction = nil
    }
}
