import Foundation

// MARK: - NetworkLogEvent

public enum NetworkLogEvent: Sendable {
    case request(URLRequest)
    case response(data: Data, response: HTTPURLResponse)
    case error(any Error)
}

// MARK: - Associated Object Keys

private nonisolated(unsafe) var tokenRefresherKey: UInt8 = 0
private nonisolated(unsafe) var networkLoggerKey: UInt8 = 0

// MARK: - LoggerBox

private final class LoggerBox: @unchecked Sendable {
    let handler: @Sendable (NetworkLogEvent) -> Void
    init(_ handler: @escaping @Sendable (NetworkLogEvent) -> Void) {
        self.handler = handler
    }
}

// MARK: - URLSession Extensions

public extension URLSession {
    var tokenRefresher: TokenRefresher? {
        get { objc_getAssociatedObject(self, &tokenRefresherKey) as? TokenRefresher }
        set { objc_setAssociatedObject(self, &tokenRefresherKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    var networkLogger: (@Sendable (NetworkLogEvent) -> Void)? {
        get { (objc_getAssociatedObject(self, &networkLoggerKey) as? LoggerBox)?.handler }
        set {
            let box = newValue.map { LoggerBox($0) }
            objc_setAssociatedObject(self, &networkLoggerKey, box, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

// MARK: - Request

public extension URLSession {
    func request<T: Decodable & Sendable>(
        _ endpoint: some EndPoint,
        refresher: TokenRefresher? = nil
    ) async throws -> T {
        let activeRefresher = refresher ?? tokenRefresher
        return try await perform(endpoint, refresher: activeRefresher, retriesLeft: endpoint.retryCount)
    }
}

// MARK: - Private

private extension URLSession {
    func perform<T: Decodable & Sendable>(
        _ endpoint: some EndPoint,
        refresher: TokenRefresher?,
        retriesLeft: Int,
        refreshAttemptsLeft: Int = 1
    ) async throws -> T {
        let urlRequest = try endpoint.buildRequest()
        networkLogger?(.request(urlRequest))

        let data: Data
        let httpResponse: HTTPURLResponse

        do {
            let (rawData, response) = try await self.data(for: urlRequest)
            guard let httpRes = response as? HTTPURLResponse else {
                throw APIError.custom(message: "Invalid response type")
            }
            data = rawData
            httpResponse = httpRes
        } catch let error as APIError {
            networkLogger?(.error(error))
            throw error
        } catch {
            networkLogger?(.error(error))
            guard retriesLeft > 0 else { throw APIError.someError(error) }
            return try await perform(endpoint, refresher: refresher, retriesLeft: retriesLeft - 1, refreshAttemptsLeft: refreshAttemptsLeft)
        }

        networkLogger?(.response(data: data, response: httpResponse))

        if httpResponse.statusCode == 401 {
            guard let refresher, refreshAttemptsLeft > 0 else { throw APIError.unAuthorized }
            try await refresher.refresh()
            return try await perform(endpoint, refresher: refresher, retriesLeft: retriesLeft, refreshAttemptsLeft: refreshAttemptsLeft - 1)
        }

        do {
            let validatedData = try endpoint.validate(data, httpResponse)
            return try decode(validatedData, decodePath: endpoint.decodePath)
        } catch let error as APIError {
            networkLogger?(.error(error))
            throw error
        } catch {
            networkLogger?(.error(error))
            throw APIError.someError(error)
        }
    }

    func decode<T: Decodable>(_ data: Data, decodePath: [String]?) throws -> T {
        if data.isEmpty {
            if let empty = EmptyResponse() as? T { return empty }
            throw APIError.custom(message: "Unexpected empty response")
        }

        let decoder = JSONDecoder()

        if let path = decodePath, !path.isEmpty {
            decoder.userInfo[.decodePath] = path
            return try decoder.decode(ShieldedResponse<T>.self, from: data).value
        }

        return try decoder.decode(T.self, from: data)
    }
}
