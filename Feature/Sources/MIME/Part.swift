import Foundation

/// MIME part described in [RFC 2045](https://www.rfc-editor.org/rfc/rfc2045#section-2.5)
public struct Part: CustomStringConvertible, RawRepresentable, Sendable {

    /// Instruct mail client to display decoded body part inline, in message, or link as an attachment. Optionally include file name and other metadata for source file.
    public let contentDisposition: ContentDisposition?
    public let contentTransferEncoding: ContentTransferEncoding?
    public let contentType: ContentType

    /// The actual part content, encoded as an ASCII string using the transfer encoding specified in the part header; typically base64 or quoted-printable
    public let data: Data

    public var headers: [String: String] {
        var headers: [String: String] = [:]
        if let contentDisposition {
            headers["Content-Disposition"] = contentDisposition.description
        }
        if let contentTransferEncoding {
            headers["Content-Transfer-Encoding"] = contentTransferEncoding.description
        }
        headers["Content-Type"] = contentType.description
        return headers
    }

    /// Multipart data decoded into parts
    public var parts: [Self] {
        get throws {
            switch contentType {
            case .multipart(_, let boundary):
                guard
                    let parts: [String] = String(data: data, encoding: .ascii)?
                        .components(separatedBy: "--\(boundary)")
                        .dropFirst().dropLast(),
                    !parts.isEmpty
                else {
                    throw MIMEError.dataNotDecoded(data, encoding: .ascii)
                }
                return try parts.map { try Self($0.trimmed()) }
            default:
                throw MIMEError.contentTypeNotMultipart
            }
        }
    }

    /// Encode multiple data parts  into a single part.
    public init(parts: [Self], contentType: ContentType = .multipart(.mixed)) throws {
        switch contentType {
        case .multipart(_, let boundary):
            let data: Data = try parts.data(using: boundary)
            self.init(data: data, contentType: contentType)
        default:
            throw MIMEError.contentTypeNotPossible(contentType)
        }
    }

    /// Read headers and decode body part from raw ASCII blob.
    public init(_ description: String) throws {
        let description: String =
            description
            .replacingOccurrences(of: crlf, with: "\n")
            .replacingOccurrences(of: "\n\t", with: "")
        let components: [String] = description.components(separatedBy: "\n")
        guard let index: Int = components.firstIndex(of: "") else {
            throw MIMEError.dataNotFound
        }
        var contentDisposition: ContentDisposition?
        var contentTransferEncoding: ContentTransferEncoding?
        var contentType: ContentType?
        for component in components[0..<index] {
            let header: [String] = component.components(separatedBy: ": ").map { $0.trimmed() }
            guard header.count == 2 else { continue }
            switch header[0].lowercased() {  // MIME headers are case-sensitive, but no harm in fuzzy matching
            case "content-disposition":
                contentDisposition = ContentDisposition(rawValue: header[1])
            case "content-transfer-encoding":
                contentTransferEncoding = ContentTransferEncoding(rawValue: header[1])
            case "content-type":
                contentType = ContentType(rawValue: header[1])
            default:
                continue
            }
        }
        guard let data: Data = components.dropFirst(index).joined(separator: "\n").trimmed().data(using: .ascii), let contentType else {
            throw MIMEError.dataNotDecoded(description.data(using: .ascii) ?? Data(), encoding: .ascii)
        }
        self.init(
            data: data,
            contentDisposition: contentDisposition,
            contentTransferEncoding: contentTransferEncoding,
            contentType: contentType
        )
    }

    /// Read headers and decode body from raw ASCII data.
    public init(_ description: Data) throws {
        guard let description: String = String(data: description, encoding: .ascii) else {
            throw MIMEError.dataNotDecoded(description, encoding: .ascii)
        }
        try self.init(description)
    }

    public init(
        data: Data,
        contentDisposition: ContentDisposition? = nil,
        contentTransferEncoding: ContentTransferEncoding? = nil,
        contentType: ContentType
    ) {
        self.contentDisposition = contentDisposition
        self.contentTransferEncoding = contentTransferEncoding
        self.contentType = contentType
        self.data = data
    }

    // MARK: CustomStringConvertible
    public var description: String { String(data: rawValue, encoding: .ascii)! }

    // MARK: RawRepresentable
    public var rawValue: Data {
        var data: Data = Data()
        for key in headers.keys.sorted() {
            data.append("\(key): \(headers[key]!)\(crlf)".data(using: .ascii)!)
        }
        data.append(crlf.data(using: .ascii)!)
        data.append(self.data + crlf.data(using: .ascii)!)
        data.append(crlf.data(using: .ascii)!)
        return data
    }

    public init?(rawValue: Data) {
        try? self.init(rawValue)
    }
}

extension [Part] {
    func data(using boundary: Boundary) throws -> Data {
        guard !isEmpty else {
            throw MIMEError.dataNotFound
        }
        var data: Data = Data()
        data.append(crlf.data(using: .ascii)!)
        for part in self {
            data.append("--\(boundary)\(crlf)".data(using: .ascii)!)
            data.append(part.rawValue)
            data.append(crlf.data(using: .ascii)!)
        }
        data.append("--\(boundary)--\(crlf)".data(using: .ascii)!)
        return data
    }
}
