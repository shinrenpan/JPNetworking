# JPNetworking

**[English](README.md) | [中文](README.zh.md)**

輕量的 Swift Package，供 MVVMC 專案共用網路層。

## 系統需求

- Swift 6.2+
- iOS 17+ / macOS 14+

## 安裝

透過 Swift Package Manager 加入：

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/shinrenpan/JPNetworking", from: "1.0.0")
]
```

或在 Xcode 中：**File → Add Package Dependencies**。

## 設計理念

Package 本身不含任何專案邏輯，由各專案注入：

| 責任 | 位置 |
|---|---|
| Token | `EndPoint.header` |
| Base URL | `EndPoint.baseURL` |
| 回應驗證 | `EndPoint.validate()` |
| JSON 解碼路徑 | `EndPoint.decodePath` |
| Token 刷新邏輯 | `TokenRefresher.init(handler:)` |

## 快速開始

### 1. 定義 BaseResponse

```swift
struct BaseResponse: BaseResponseProtocol {
    let code: Int
    let message: String
}
```

### 2. 實作 EndPoint 預設值

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

### 3. 定義 Endpoint

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

### 4. 發送請求

```swift
let user: UserDTO = try await URLSession.shared.request(UserEndPoint.profile(id: "123"))
```

### 5. 設定 TokenRefresher

```swift
let refresher = TokenRefresher {
    let newToken: TokenDTO = try await URLSession.shared.request(AuthEndPoint.refresh)
    TokenManager.shared.token = newToken.accessToken
}
```

需要 401 自動刷新的請求，將 `refresher` 傳入 `URLSession.request(_:refresher:)`。

## 安全解碼

### SafeBox

處理後端型別不一致的問題。`wrappedValue` 為 `T?`，解碼失敗時回傳 `nil`，由 `toDomain()` 決定如何處理。

```swift
struct UserDTO: Decodable {
    @SafeBox var age: Int?       // 後端可能回傳 "30" 而不是 30
    @SafeBox var name: String?   // 後端可能回傳 null
}
```

### SafeArray

陣列中的壞資料會被跳過，不影響其餘元素。

```swift
struct FeedDTO: Decodable {
    @SafeArray var items: [ItemDTO]  // 單一壞元素不會讓整個陣列失敗
}
```

## 錯誤處理

```swift
do {
    let result: UserDTO = try await URLSession.shared.request(endpoint)
} catch APIError.unAuthorized {
    // refresh token 失敗，或未提供 refresher
} catch APIError.serverError(let code, let message) {
    // 後端回傳業務錯誤
} catch APIError.dataQualityError {
    // toDomain() 回傳 nil，後端資料品質問題
} catch APIError.someError(let error) {
    // 網路或解碼錯誤
}
```

## 授權

MIT © 2026 Shinren Pan
