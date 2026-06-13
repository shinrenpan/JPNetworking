import Foundation

public extension URLSession {
    func request<T: Decodable & Sendable>(
        _ endpoint: some EndPoint,
        refresher: TokenRefresher? = nil
    ) async throws -> T {
        try await perform(endpoint, refresher: refresher, retriesLeft: endpoint.retryCount)
    }
}

private extension URLSession {
    func perform<T: Decodable & Sendable>(
        _ endpoint: some EndPoint,
        refresher: TokenRefresher?,
        retriesLeft: Int
    ) async throws -> T {
        let urlRequest = try endpoint.buildRequest()

        do {
            let (data, response) = try await self.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.custom(message: "Invalid response type")
            }

            if httpResponse.statusCode == 401 {
                guard let refresher else { throw APIError.unAuthorized }
                try await refresher.refresh()
                return try await perform(endpoint, refresher: refresher, retriesLeft: retriesLeft)
            }

            let validatedData = try endpoint.validate(data, httpResponse)
            return try decode(validatedData, decodePath: endpoint.decodePath)

        } catch let error as APIError {
            throw error
        } catch {
            guard retriesLeft > 0 else { throw APIError.someError(error) }
            return try await perform(endpoint, refresher: refresher, retriesLeft: retriesLeft - 1)
        }
    }

    func decode<T: Decodable>(_ data: Data, decodePath: [String]?) throws -> T {
        let decoder = JSONDecoder()

        if let path = decodePath, !path.isEmpty {
            decoder.userInfo[.decodePath] = path
            return try decoder.decode(ShieldedResponse<T>.self, from: data).value
        }

        return try decoder.decode(T.self, from: data)
    }
}
