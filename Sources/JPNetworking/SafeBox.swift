import Foundation

// MARK: - SafeBox

@propertyWrapper
public struct SafeBox<T: LosslessStringConvertible & Codable & Sendable>: Codable, Sendable {
    public var wrappedValue: T?

    public init(wrappedValue: T? = nil) {
        self.wrappedValue = wrappedValue
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            wrappedValue = nil
            return
        }

        if let value = try? container.decode(T.self) {
            wrappedValue = value
            return
        }

        wrappedValue = Self.rescue(from: container)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        if let value = wrappedValue {
            try container.encode(value)
        } else {
            try container.encodeNil()
        }
    }

    private static func rescue(from container: any SingleValueDecodingContainer) -> T? {
        if T.self == Bool.self {
            if let str = try? container.decode(String.self) {
                let lower = str.lowercased()
                let result = lower == "true" || lower == "1" || lower == "yes"
                return result as? T
            }
            if let int = try? container.decode(Int.self) {
                return (int != 0) as? T
            }
            return nil
        }

        if let str = try? container.decode(String.self) {
            if T.self == Int.self, let dbl = Double(str) { return Int(dbl) as? T }
            return T(str)
        }
        if let int = try? container.decode(Int.self) {
            return T("\(int)")
        }
        if let double = try? container.decode(Double.self) {
            if T.self == Int.self { return Int(double) as? T }
            return T("\(double)")
        }
        return nil
    }
}

// MARK: - SafeArray

@propertyWrapper
public struct SafeArray<T: Decodable & Sendable>: Codable, Sendable where T: Encodable {
    public var wrappedValue: [T]

    public init(wrappedValue: [T] = []) {
        self.wrappedValue = wrappedValue
    }

    public init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var elements: [T] = []

        while !container.isAtEnd {
            if let value = try? container.decode(T.self) {
                elements.append(value)
            } else {
                _ = try? container.superDecoder()
            }
        }

        wrappedValue = elements
    }

    public func encode(to encoder: any Encoder) throws {
        try wrappedValue.encode(to: encoder)
    }
}

// MARK: - KeyedDecodingContainer

public extension KeyedDecodingContainer {
    func decode<T: LosslessStringConvertible & Codable & Sendable>(
        _ type: SafeBox<T>.Type,
        forKey key: Key
    ) throws -> SafeBox<T> {
        (try? decodeIfPresent(type, forKey: key)) ?? SafeBox(wrappedValue: nil)
    }

    func decode<T: Decodable & Sendable>(
        _ type: SafeArray<T>.Type,
        forKey key: Key
    ) throws -> SafeArray<T> where T: Encodable {
        (try? decodeIfPresent(type, forKey: key)) ?? SafeArray(wrappedValue: [])
    }
}
