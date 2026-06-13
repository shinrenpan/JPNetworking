import Foundation

public struct MultipartBuilder: Sendable {
    public let boundary: String
    private var body: Data

    public init(boundary: String = UUID().uuidString) {
        self.boundary = boundary
        self.body = Data()
    }

    public var contentType: String {
        "multipart/form-data; boundary=\(boundary)"
    }

    public mutating func addField(name: String, value: String) {
        var part = "--\(boundary)\r\n"
        part += "Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n"
        part += "\(value)\r\n"
        body.append(Data(part.utf8))
    }

    public mutating func addFile(name: String, filename: String, mimeType: String, data: Data) {
        var header = "--\(boundary)\r\n"
        header += "Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n"
        header += "Content-Type: \(mimeType)\r\n\r\n"
        body.append(Data(header.utf8))
        body.append(data)
        body.append(Data("\r\n".utf8))
    }

    public func build() -> Data {
        var result = body
        result.append(Data("--\(boundary)--\r\n".utf8))
        return result
    }
}
