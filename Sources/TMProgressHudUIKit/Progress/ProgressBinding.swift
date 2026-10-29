// SPDX-License-Identifier: MIT
// Portions Copyright 2009-2020 Matej Bukovinski.
// Swift port Copyright 2026 Tomasz Maciejko and TMProgressHud contributors.
// Reference: 4a7c5f3e53cdea77c5dcb8578c2ee5acacdf6781. See THIRD_PARTY_NOTICES.md.
import Foundation

/// Observes progress only while active, delivering current values on the main actor.
@MainActor
final class ProgressBinding {
    private(set) var source: Progress?
    private var isActive = false
    private var observation: NSKeyValueObservation?
    private var updatesTask: Task<Void, Never>?
    private var generation = UUID()
    private let onProgress: @MainActor (Float) -> Void

    init(onProgress: @escaping @MainActor (Float) -> Void) {
        self.onProgress = onProgress
    }
    deinit {
        updatesTask?.cancel()
    }

    func replace(with source: Progress?) {
        guard self.source !== source else { return }
        self.source = source
        observeCurrentSource()
    }

    func start() {
        guard !isActive else { return }
        isActive = true
        observeCurrentSource()
    }

    func stop() {
        guard isActive else { return }
        isActive = false
        stopObserving()
    }

    private func stopObserving() {
        generation = UUID()
        observation?.invalidate()
        observation = nil
        updatesTask?.cancel()
        updatesTask = nil
    }

    private func observeCurrentSource() {
        stopObserving()
        guard isActive, let source else { return }
        let current = generation
        // Signals coalesce while the actor is busy; the consumer reads the latest value.
        let (stream, continuation) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        observation = source.observe(\.fractionCompleted, options: [.new]) { _, _ in
            continuation.yield()
        }
        updatesTask = Task { [weak self] in
            for await _ in stream {
                // Do not hold the binding across an awaiting iteration.
                self?.refresh(generation: current)
            }
        }
        refresh(generation: current)
    }

    private func refresh(generation current: UUID) {
        guard isActive, generation == current, let source else { return }
        onProgress(Float(source.fractionCompleted))
    }
}
