# JPNetworking

A lightweight Swift Package for reusable networking across MVVMC projects.

- Swift 6.2, iOS 17+, macOS 14+

## Goal

- Zero project-specific dependencies in the package itself
- Each project provides: BaseResponse, token source, base URL via EndPoint
- Drop-in for any MVVMC project

---

## Package Components

| File | Responsibility |
|------|---------------|
| `EndPoint.swift` | Protocol definition — path, method, headers, validate, decodePath, retry, timeout |
| `URLSession+EndPoint.swift` | Core request execution + 401 intercept + retry logic |
| `TokenRefresher.swift` | Actor — serializes refresh token calls, prevents race condition |
| `APIError.swift` | Shared error enum |
| `APIMethod.swift` | HTTP method enum |
| `SafeBox.swift` | `SafeBox` + `SafeArray` property wrappers for safe decoding |
| `ShieldedResponse.swift` | Generic wrapper for decoding via decodePath |
| `BaseResponseProtocol.swift` | Marker protocol that each project's BaseResponse must conform to |

---

## Design Decisions

### Token Injection

Token lives in `EndPoint.header`, not in the package. EndPoint default implementation reads token from project's own source:

```swift
extension EndPoint {
    var needToken: Bool { true }
    // Each project implements header with their own token source
}
```

Login/register endpoints override `needToken: false`.

### Validation

Each project implements `validate(_ data: Data, _ response: HTTPURLResponse) throws -> Data` on their EndPoint. This handles backend differences:

- **HTTP status code backends**: check `response.statusCode`
- **Custom code backends**: decode wrapper, check `wrapper.code`

Both throw `APIError.serverError(code:message:)` — ViewModel sees no difference.

The package provides a default validate that checks HTTP 200–299. Projects with custom code backends override it.

### decodePath

Dynamic JSON path injection via `decoder.userInfo[.decodePath]`. Package default is `nil` (decode from root). Each project sets its own default via extension:

```swift
// In project
extension EndPoint {
    var decodePath: [String]? { ["data"] }
}
```

Override per endpoint if needed:

```swift
var decodePath: [String]? { ["data", "list"] }
```

### SafeBox / SafeArray

`SafeBox<T?>` wraps primitives that conform to `LosslessStringConvertible`. Handles type mismatch (e.g. backend sends `"42"` for an Int field) via type rescue. On failure, wrappedValue is `nil`.

`SafeArray<T>` wraps arrays. Corrupt elements are skipped; the array continues decoding.

**Why `T?` and not `T` with defaultValue:**

Bad data surfaces as `nil` → `toDomain()` returns `nil` → `APIError.dataQualityError`. This keeps data quality errors visible to the ViewModel rather than silently substituting wrong values.

### Refresh Token (Race Condition Safe)

`TokenRefresher` actor ensures only one refresh call is in-flight at a time. Concurrent 401s wait on the same Task:

```swift
// api1 + api2 both get 401
// api1 → triggers refresh
// api2 → waits for api1's refresh Task
// both retry with new token
```

`TokenRefresher` requires the project to inject the actual refresh logic (closure).

### Retry

EndPoint declares `var retryCount: Int { 0 }`. URLSession extension retries on transient errors only (not 401, not validation errors).

### APIError Cases

```swift
enum APIError {
    case unAuthorized
    case serverError(code: Int, message: String)
    case custom(message: String)
    case someError(any Error)
    case dataQualityError  // toDomain() returned nil
}
```

Generic enough for all projects. Backend-specific mapping happens in EndPoint.validate.

---

## What Each Project Must Provide

1. `BaseResponse` conforming to `BaseResponseProtocol` — matches their backend contract
2. `EndPoint.header` — inject token from project's UserManager/KeychainManager
3. `EndPoint.baseURL` — staging vs production
4. `EndPoint.decodePath` default — e.g. `{ ["data"] }` via extension
5. Refresh token closure injected into `TokenRefresher`

---

## Reference

- Draco app APIManager: `/Users/joe/Documents/Company/Draco/app/draco-app-iOS/DracoApp/Sources/Managers/API/`
- Blog posts: SafeBox/SafeArray, BaseResponseProtocol/ShieldedResponse, decodePath dynamic injection
- BadBackendDemo: `/Users/joe/Documents/github/BadBackendDemo`
- MVVMC architecture: `/Users/joe/Documents/github/MVVMC/CLAUDE.md`
