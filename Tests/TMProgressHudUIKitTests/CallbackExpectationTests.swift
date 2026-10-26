import Testing

@Suite(.timeLimit(.minutes(1)))
struct CallbackExpectationTests {
    @Test func callbackBeforeWaitingIsRemembered() async throws {
        let callback = CallbackExpectation()
        callback.signal()
        callback.signal()
        try await callback.wait()
    }

    @Test func cancellingAWaitDoesNotRequireTheCallback() async throws {
        let callback = CallbackExpectation()
        let entered = CallbackExpectation()
        let task = Task {
            entered.signal()
            try await callback.wait()
        }
        try await entered.wait()
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
        callback.signal()
    }

    @Test func alreadyCancelledTaskDoesNotWaitForCallback() async {
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            try await CallbackExpectation().wait()
        }
        await #expect(throws: CancellationError.self) { try await task.value }
    }
}
