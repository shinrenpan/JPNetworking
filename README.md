# JPNetworking

**[English](README.md) | [中文](README.zh.md)**

A lightweight Swift Package for reusable networking across MVVMC projects.

## Requirements

- Swift 6.2+
- iOS 17+ / macOS 14+

## Installation

Add JPNetworking via Swift Package Manager:

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/shinrenpan/JPNetworking", from: "1.0.0")
]
```

Or add it directly in Xcode: **File → Add Package Dependencies**.

## Design Philosophy

JPNetworking has zero project-specific logic. Each project provides:

| Responsibility | Where |
|---|---|
| Token | `EndPoint.header` |
| Base URL | `EndPoint.baseURL` |
| Response validation | `EndPoint.validate()` |
| JSON decode path | `EndPoint.decodePath` |
| Token refresh logic | `TokenRefresher.init(handler:)` |

## Quick Start

### 1. Define your BaseResponse

```swift
struct BaseResponse: BaseResponseProtocol {
    let code: Int
    let message: String
    let data: Data? // raw JSON bytes — decoded later via decodePath
}
```

### 2. Implement EndPoint

```swift
extension EndPoint {
    var baseURL: String { "https://api.example.com" }
    var decodePath: [String]? { ["data"] }
    var headers: [String: String] {
        var h = ["Content-Type": "application/json"]
        if needToken { h["Authorization"] = "Bearer \(TokenManager.shared.token)" }
        return h
    }

    func validate(_ data: Data, _ response: HTTPURLResponse) throws -> Data {
        let base = try JSONDecoder().decode(BaseResponse.self, from: data)
        guard base.code == 0 else {
            throw APIError.serverError(code: base.code, message: base.message)
        }
        return data
    }
}
```

### 3. Define endpoints

```swift
enum UserEndPoint: EndPoint {
    case login(email: String, password: String)
    case profile(id: String)

    var path: String {
        switch self {
        case .login: "/auth/login"
        case .profile(let id): "/users/\(id)"
        }
    }

    var method: APIMethod {
        switch self {
        case .login: .post
        case .profile: .get
        }
    }

    var needToken: Bool {
        switch self {
        case .login: false
        case .profile: true
        }
    }

    var body: Data? {
        switch self {
        case .login(let email, let password):
            try? JSONEncoder().encode(["email": email, "password": password])
        default:
            nil
        }
    }
}
```

### 4. Make requests

```swift
let user: UserDTO = try await URLSession.shared.request(UserEndPoint.profile(id: "123"))
```

### 5. Set up TokenRefresher

```swift
let refresher = TokenRefresher {
    let newToken: TokenDTO = try await URLSession.shared.request(AuthEndPoint.refresh)
    TokenManager.shared.token = newToken.accessToken
}
```

Pass `refresher` into `URLSession.request(_:refresher:)` for endpoints that need 401 handling.

## Safe Decoding

### SafeBox

Handles type mismatches from unreliable backends. `wrappedValue` is `T?` — failed decoding surfaces as `nil` for `toDomain()` to handle.

```swift
struct UserDTO: Decodable {
    @SafeBox var age: Int?       // backend may send "30" instead of 30
    @SafeBox var name: String?   // backend may send null
}
```

### SafeArray

Skips corrupt elements instead of failing the entire array decode.

```swift
struct FeedDTO: Decodable {
    @SafeArray var items: [ItemDTO]  // one bad element won't break the list
}
```

## Error Handling

```swift
do {
    let result: UserDTO = try await URLSession.shared.request(endpoint)
} catch APIError.unAuthorized {
    // refresh token failed or no refresher provided
} catch APIError.serverError(let code, let message) {
    // backend returned a business error
} catch APIError.dataQualityError {
    // toDomain() returned nil — bad data from backend
} catch APIError.someError(let error) {
    // network or decoding error
}
```

## License

MIT © 2026 Shinren Pan
