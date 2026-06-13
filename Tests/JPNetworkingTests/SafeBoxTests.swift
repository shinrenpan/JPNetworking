import Testing
import Foundation
@testable import JPNetworking

@Suite("SafeBox")
struct SafeBoxTests {
    private struct Model: Codable {
        @SafeBox var intValue: Int?
        @SafeBox var stringValue: String?
        @SafeBox var doubleValue: Double?
        @SafeBox var boolValue: Bool?
    }

    @Test("後端傳正確型別，正確解碼")
    func correctType() throws {
        let json = #"{"intValue": 42}"#
        let model = try decode(Model.self, from: json)
        #expect(model.intValue == 42)
    }

    @Test("後端傳 String，正確轉成 Int")
    func intFromString() throws {
        let json = #"{"intValue": "42"}"#
        let model = try decode(Model.self, from: json)
        #expect(model.intValue == 42)
    }

    @Test("後端傳 Double，截斷成 Int")
    func intFromDouble() throws {
        let json = #"{"intValue": 3.9}"#
        let model = try decode(Model.self, from: json)
        #expect(model.intValue == 3)
    }

    @Test("後端傳浮點字串，截斷成 Int")
    func intFromDoubleString() throws {
        let json = #"{"intValue": "3.9"}"#
        let model = try decode(Model.self, from: json)
        #expect(model.intValue == 3)
    }

    @Test("後端傳 Int，正確轉成 String")
    func stringFromInt() throws {
        let json = #"{"stringValue": 123}"#
        let model = try decode(Model.self, from: json)
        #expect(model.stringValue == "123")
    }

    @Test("後端傳 String，正確轉成 Double")
    func doubleFromString() throws {
        let json = #"{"doubleValue": "3.14"}"#
        let model = try decode(Model.self, from: json)
        #expect(model.doubleValue == 3.14)
    }

    @Test("後端傳 Int，正確轉成 Double")
    func doubleFromInt() throws {
        let json = #"{"doubleValue": 2}"#
        let model = try decode(Model.self, from: json)
        #expect(model.doubleValue == 2.0)
    }

    @Test("後端傳 \"true\"，正確轉成 Bool true")
    func boolFromStringTrue() throws {
        let json = #"{"boolValue": "true"}"#
        let model = try decode(Model.self, from: json)
        #expect(model.boolValue == true)
    }

    @Test("後端傳 \"1\"，正確轉成 Bool true")
    func boolFromStringOne() throws {
        let json = #"{"boolValue": "1"}"#
        let model = try decode(Model.self, from: json)
        #expect(model.boolValue == true)
    }

    @Test("後端傳 \"yes\"，正確轉成 Bool true")
    func boolFromStringYes() throws {
        let json = #"{"boolValue": "yes"}"#
        let model = try decode(Model.self, from: json)
        #expect(model.boolValue == true)
    }

    @Test("後端傳數字 1，正確轉成 Bool true")
    func boolFromIntOne() throws {
        let json = #"{"boolValue": 1}"#
        let model = try decode(Model.self, from: json)
        #expect(model.boolValue == true)
    }

    @Test("後端傳數字 0，正確轉成 Bool false")
    func boolFromIntZero() throws {
        let json = #"{"boolValue": 0}"#
        let model = try decode(Model.self, from: json)
        #expect(model.boolValue == false)
    }

    @Test("後端傳 null，wrappedValue 為 nil")
    func nullBecomesNil() throws {
        let json = #"{"intValue": null}"#
        let model = try decode(Model.self, from: json)
        #expect(model.intValue == nil)
    }

    @Test("欄位缺失，wrappedValue 為 nil")
    func missingFieldBecomesNil() throws {
        let json = #"{}"#
        let model = try decode(Model.self, from: json)
        #expect(model.intValue == nil)
        #expect(model.stringValue == nil)
        #expect(model.doubleValue == nil)
    }

    @Test("後端傳無法轉換的值，wrappedValue 為 nil（浮出錯誤供 toDomain 處理）")
    func invalidValueBecomesNil() throws {
        let json = #"{"intValue": "abc"}"#
        let model = try decode(Model.self, from: json)
        #expect(model.intValue == nil)
    }
}

@Suite("SafeArray")
struct SafeArrayTests {
    private struct Model: Codable {
        @SafeArray var items: [Int]
    }

    @Test("正常陣列正確解碼")
    func normalArray() throws {
        let json = #"{"items": [1, 2, 3]}"#
        let model = try decode(Model.self, from: json)
        #expect(model.items == [1, 2, 3])
    }

    @Test("欄位缺失，wrappedValue 為空陣列")
    func missingFieldBecomesEmpty() throws {
        let json = #"{}"#
        let model = try decode(Model.self, from: json)
        #expect(model.items.isEmpty)
    }

    @Test("陣列中有壞資料，跳過該元素繼續解碼")
    func corruptedElementIsSkipped() throws {
        let json = #"{"items": [1, "bad", 3]}"#
        let model = try decode(Model.self, from: json)
        #expect(model.items == [1, 3])
    }

    @Test("陣列中有 null，跳過繼續解碼")
    func nullElementIsSkipped() throws {
        let json = #"{"items": [1, null, 3]}"#
        let model = try decode(Model.self, from: json)
        #expect(model.items == [1, 3])
    }
}

private func decode<T: Decodable>(_ type: T.Type, from json: String) throws -> T {
    try JSONDecoder().decode(type, from: Data(json.utf8))
}
