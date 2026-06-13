import Foundation

extension CodingUserInfoKey {
    static let decodePath = CodingUserInfoKey(rawValue: "jp.networking.decodePath")!
}

struct AnyCodingKey: CodingKey {
    let stringValue: String
    var intValue: Int?

    init(_ string: String) { stringValue = string }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) {
        self.intValue = intValue
        self.stringValue = "\(intValue)"
    }
}

public struct ShieldedResponse<T: Decodable>: Decodable {
    public let value: T

    public init(from decoder: any Decoder) throws {
        guard let path = decoder.userInfo[.decodePath] as? [String] else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "decodePath in decoder.userInfo must be [String]"
            ))
        }

        do {
            let target = try Self.navigate(to: path, from: decoder)
            value = try T(from: target)
        } catch NavigationSignal.pathValueIsNull {
            throw DecodingError.valueNotFound(
                T.self,
                .init(codingPath: decoder.codingPath, debugDescription: "Value at path is null")
            )
        }
    }

    private static func navigate(to keys: [String], from decoder: any Decoder) throws -> any Decoder {
        var current = decoder
        for key in keys {
            let container = try current.container(keyedBy: AnyCodingKey.self)
            let codingKey = AnyCodingKey(key)
            guard container.contains(codingKey) else {
                throw DecodingError.keyNotFound(
                    codingKey,
                    .init(codingPath: current.codingPath, debugDescription: "Missing path key: \(key)")
                )
            }
            if try container.decodeNil(forKey: codingKey) {
                throw NavigationSignal.pathValueIsNull
            }
            current = try container.superDecoder(forKey: codingKey)
        }
        return current
    }
}

private enum NavigationSignal: Error {
    case pathValueIsNull
}
