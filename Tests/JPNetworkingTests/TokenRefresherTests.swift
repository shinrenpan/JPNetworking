import Testing
import Foundation
@testable import JPNetworking

@Suite("TokenRefresher")
struct TokenRefresherTests {
    @Test("單次呼叫正確執行 handler")
    func singleRefresh() async throws {
        let counter = Counter()
        let refresher = TokenRefresher {
            await counter.increment()
        }

        try await refresher.refresh()

        let count = await counter.value
        #expect(count == 1)
    }

    @Test("同時多個呼叫，handler 只執行一次")
    func concurrentRefreshesCallHandlerOnce() async throws {
        let counter = Counter()
        let refresher = TokenRefresher {
            try await Task.sleep(for: .milliseconds(50))
            await counter.increment()
        }

        await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<5 {
                group.addTask { try await refresher.refresh() }
            }
        }

        let count = await counter.value
        #expect(count == 1)
    }

    @Test("第一次 refresh 完成後，第二次再呼叫會再執行一次 handler")
    func sequentialRefreshesCallHandlerEachTime() async throws {
        let counter = Counter()
        let refresher = TokenRefresher {
            await counter.increment()
        }

        try await refresher.refresh()
        try await refresher.refresh()

        let count = await counter.value
        #expect(count == 2)
    }

    @Test("handler 拋出錯誤，所有等待者都收到錯誤")
    func handlerErrorPropagates() async throws {
        let refresher = TokenRefresher {
            throw APIError.unAuthorized
        }

        var errorCount = 0

        await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<3 {
                group.addTask {
                    do {
                        try await refresher.refresh()
                        return false
                    } catch {
                        return true
                    }
                }
            }

            for await didThrow in group where didThrow {
                errorCount += 1
            }
        }

        #expect(errorCount == 3)
    }
}

private actor Counter {
    private(set) var value = 0
    func increment() { value += 1 }
}
