import Testing

/// A buffered, one-shot callback signal whose wait responds to task cancellation.
struct CallbackExpectation: Sendable {
    private let stream: AsyncStream<Void>
    private let continuation: AsyncStream<Void>.Continuation

    init() {
        (stream, continuation) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(1))
    }

    func signal() {
        continuation.yield()
        continuation.finish()
    }

    func wait() async throws {
        try Task.checkCancellation()
        var iterator = stream.makeAsyncIterator()
        let event: Void? = await iterator.next()
        try Task.checkCancellation()
        try #require(event != nil)
    }
}
