public enum APIError: Error, Sendable {
    case unAuthorized
    case serverError(code: Int, message: String)
    case custom(message: String)
    case someError(any Error)
    case dataQualityError
}
