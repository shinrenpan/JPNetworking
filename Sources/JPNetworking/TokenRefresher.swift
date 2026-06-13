public actor TokenRefresher {
    private var refreshTask: Task<Void, any Error>?
    private let handler: @Sendable () async throws -> Void

    public init(handler: @Sendable @escaping () async throws -> Void) {
        self.handler = handler
    }

    public func refresh() async throws {
        if let task = refreshTask {
            try await task.value
            return
        }

        let task = Task { try await handler() }
        refreshTask = task

        defer { refreshTask = nil }

        try await task.value
    }
}
