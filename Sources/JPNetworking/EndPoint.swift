import Foundation

public protocol EndPoint: Sendable {
    var baseURL: String { get }
    var path: String { get }
    var method: APIMethod { get }
    var headers: [String: String] { get }
    var body: Data? { get }
    var needToken: Bool { get }
    var retryCount: Int { get }
    var timeout: TimeInterval { get }
    var decodePath: [String]? { get }

    func validate(_ data: Data, _ response: HTTPURLResponse) throws -> Data
}

public extension EndPoint {
    var body: Data? { nil }
    var needToken: Bool { true }
    var retryCount: Int { 0 }
    var timeout: TimeInterval { 30 }
    var decodePath: [String]? { nil }
}

extension EndPoint {
    func buildRequest() throws -> URLRequest {
        guard let url = URL(string: baseURL + path) else {
            throw APIError.custom(message: "Invalid URL: \(baseURL + path)")
        }
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = method.rawValue
        request.httpBody = body
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        return request
    }
}
