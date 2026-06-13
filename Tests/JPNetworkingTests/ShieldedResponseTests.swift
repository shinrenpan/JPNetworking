import Testing
import Foundation
@testable import JPNetworking

@Suite("ShieldedResponse")
struct ShieldedResponseTests {
    private struct Item: Decodable, Equatable {
        let id: Int
        let name: String
    }

    @Test("單層 decodePath 正確解碼")
    func singleLevelPath() throws {
        let json = #"{"data": {"id": 1, "name": "Joe"}}"#
        let item = try decodeShielded(Item.self, from: json, path: ["data"])
        #expect(item == Item(id: 1, name: "Joe"))
    }

    @Test("多層 decodePath 正確解碼")
    func multiLevelPath() throws {
        let json = #"{"data": {"list": {"id": 2, "name": "Jane"}}}"#
        let item = try decodeShielded(Item.self, from: json, path: ["data", "list"])
        #expect(item == Item(id: 2, name: "Jane"))
    }

    @Test("decodePath 為 nil，直接解碼根層")
    func nilPath() throws {
        let json = #"{"id": 3, "name": "Root"}"#
        let item = try decodeShielded(Item.self, from: json, path: nil)
        #expect(item == Item(id: 3, name: "Root"))
    }

    @Test("Array 型別正確解碼")
    func arrayType() throws {
        let json = #"{"data": [{"id": 1, "name": "A"}, {"id": 2, "name": "B"}]}"#
        let items = try decodeShielded([Item].self, from: json, path: ["data"])
        #expect(items.count == 2)
        #expect(items[0] == Item(id: 1, name: "A"))
    }

    @Test("路徑不存在時拋出錯誤")
    func invalidPath() {
        let json = #"{"data": {"id": 1, "name": "Joe"}}"#
        #expect(throws: (any Error).self) {
            _ = try decodeShielded(Item.self, from: json, path: ["wrong"])
        }
    }
}

private func decodeShielded<T: Decodable>(_ type: T.Type, from json: String, path: [String]?) throws -> T {
    let decoder = JSONDecoder()
    if let path {
        decoder.userInfo[.decodePath] = path
        return try decoder.decode(ShieldedResponse<T>.self, from: Data(json.utf8)).value
    }
    return try decoder.decode(T.self, from: Data(json.utf8))
}
