// SPDX-License-Identifier: MIT
// Portions Copyright 2009-2020 Matej Bukovinski.
// Swift port Copyright 2026 Tomasz Maciejko and TMProgressHud contributors.
// Reference: 4a7c5f3e53cdea77c5dcb8578c2ee5acacdf6781. See THIRD_PARTY_NOTICES.md.
import Foundation

/// Observes one progress source and delivers its current value on the main actor.
@MainActor
final class ProgressBinding {
    private var source: Progress?
    private var observation: NSKeyValueObservation?
    private var updatesTask: Task<Void, Never>?
    private var observationID = UUID()
    private let onProgress: @MainActor (Float) -> Void

    init(onProgress: @escaping @MainActor (Float) -> Void) {
        self.onProgress = onProgress
    }

    deinit {
        updatesTask?.cancel()
    }

    /// Replaces the observed source; nil cancels observation and releases the previous source.
    ///
    /// Binding the same instance again is a no-op. A new source delivers its current value synchronously.
    /// Later changes are delivered asynchronously, coalescing pending signals into one current-value read.
    /// The callback may rebind or unbind this object, including during the initial delivery.
    func bind(to source: Progress?) {
        guard self.source !== source else { return }
        cancelObservation()
        self.source = source
        guard let source else { return }
        let currentObservationID = observationID
        let (stream, continuation) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        observation = source.observe(\.fractionCompleted, options: []) { _, _ in
            continuation.yield()
        }
        updatesTask = Task { [weak self] in
            for await _ in stream {
                // Keep the binding weak across the next suspended iteration.
                self?.deliverCurrentProgress(for: currentObservationID)
            }
        }
        deliverCurrentProgress(for: currentObservationID)
    }

    /// Invalidates queued delivery before canceling the KVO token and its consuming task.
    private func cancelObservation() {
        observationID = UUID()
        observation?.invalidate()
        observation = nil
        updatesTask?.cancel()
        updatesTask = nil
    }

    private func deliverCurrentProgress(for expectedObservationID: UUID) {
        guard observationID == expectedObservationID, let source else { return }
        onProgress(Float(source.fractionCompleted))
    }
}
