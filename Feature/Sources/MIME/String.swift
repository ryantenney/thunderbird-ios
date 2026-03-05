import Foundation

extension String {

    /// Line is defined as a sequence of octets separated by a [CRLF](https://developer.mozilla.org/en-US/docs/Glossary/CRLF)
    /// Described in [RFC 2045](https://www.rfc-editor.org/rfc/rfc2045#section-2.10)
    public static var crlf: Self { "\r\n" }

    /// ASCII-compatible UUID string separator
    public static var separator: Self { "-" }

    /// ASCII representation, if `String` is ASCII
    public var ascii: Self? {
        guard let data: Data = data(using: .ascii) else {
            return nil
        }
        return Self(data: data, encoding: .ascii)
    }

    /// Capitalization case formats
    public enum Case: CaseIterable {
        case sentence, title
    }

    /// Overload capitalization with alternate case options
    public func capitalized(_ `case`: Case) -> Self {
        switch `case` {
        case .sentence: "\(prefix(1).capitalized)\(dropFirst())"
        case .title: capitalized
        }
    }

    /// Break email header value string into parameter keys and values.
    public var parameters: [Self: Self] {
        var parameters: [Self: Self] = [:]
        for parameter in components(separatedBy: ";") {
            guard let index: String.Index = parameter.firstIndex(of: "=") else {
                continue
            }
            let key: String = "\(parameter.prefix(upTo: index))".lowercased().trimmed()
            let value: String = "\(parameter.trimmed().dropFirst(key.count + 1))".removing(.quotes).trimmed()
            parameters[key] = value
        }
        return parameters
    }

    /// Decode any [RFC 2047](https://www.rfc-editor.org/rfc/rfc2047)-encoded email header string
    public func headerDecoded() throws -> Self {
        var string: Self = trimmed()
        guard string.hasPrefix("=?"), string.hasSuffix("?=") else {
            return self  // String not header-encoded; skip decoding
        }
        let components: [Self] = Array(string.components(separatedBy: "?").dropLast().dropFirst())
        guard components.count > 2 else {
            throw MIMEError.headerNotDecoded(string)
        }
        let encoding: Encoding = try Encoding(components[0])
        let contentTransferEncoding: ContentTransferEncoding = try ContentTransferEncoding(components[1])
        string = components.dropFirst(2).joined(separator: "?")
        switch contentTransferEncoding {
        case .base64:
            return try Self(base64: string, encoding: encoding)
        case .quotedPrintable:
            return try Self(quotedPrintable: string, encoding: encoding)
        default:
            throw MIMEError.headerNotDecoded(string)
        }
    }

    /// Encode any string as a UTF-8, base64 email header.
    /// Described in [RFC 2047](https://www.rfc-editor.org/rfc/rfc2047)
    public func headerEncoded() throws -> Self {
        if let data: Data = data(using: .ascii),
            let string: Self = Self(data: data, encoding: .ascii)
        {
            return string  // Already plain ASCII
        }
        guard let data: Data = data(using: .utf8) else {
            throw MIMEError.dataNotFound
        }
        return [
            "=",
            "UTF-8",
            "B",
            data.base64EncodedString(),
            "="
        ].joined(separator: "?")
    }

    /// Decode quoted-printable data to given `String.Encoding`.
    public init(quotedPrintable data: Data, encoding: Encoding = .utf8) throws {
        guard let string: String = String(data: data, encoding: encoding) else {
            throw MIMEError.dataNotDecoded(data, encoding: encoding)
        }
        self = try Self(quotedPrintable: string, encoding: encoding)
    }

    /// Decode quoted-printable string to given `String.Encoding`.
    public init(quotedPrintable string: Self, encoding: Encoding = .utf8) throws {
        let string: String =
            string
            .replacingOccurrences(of: "=\r\n", with: "")  // Remove quoted-printable line-limit wrapping
            .replacingOccurrences(of: "=\n", with: "")
        self = try string.decodingQuotedPrintable(to: encoding)
    }

    /// Decode base64 data to given `String.Encoding`.
    public init(base64 data: Data, encoding: Encoding = .utf8) throws {
        guard let string: String = String(data: data, encoding: .utf8) else {
            throw MIMEError.dataNotDecoded(data, encoding: encoding)
        }
        self = try string.decodingBase64(to: encoding)
    }

    /// Decode base64 string to given `String.Encoding`.
    public init(base64 string: Self, encoding: Encoding = .utf8) throws {
        self = try string.decodingBase64(to: encoding)
    }

    // Decoding method adapted from https://stackoverflow.com/questions/32184783
    func decodingQuotedPrintable(to encoding: Encoding = .utf8) throws -> Self {
        var string: Self = ""
        var index: Index = startIndex
        while let range = range(of: "=", range: index..<endIndex) {
            string.append(contentsOf: self[index..<range.lowerBound])
            index = range.lowerBound  // Advance index

            // Decode sequence of one or more encoded characters
            var data: Data = Data()
            repeat {
                let code: Substring = self[index...].dropFirst().prefix(2)  // Copy decodable character
                guard code.count > 1, let byte: UInt8 = UInt8(code, radix: 16) else {  // Invalid or incomplete hex code
                    throw MIMEError.dataNotQuotedPrintable
                }
                data.append(byte)
                index = self.index(index, offsetBy: 3)
            } while index != endIndex && self[index] == "="
            guard let decodedString: String = String(data: data, encoding: encoding) else {
                throw MIMEError.dataNotDecoded(data, encoding: encoding)
            }
            string.append(contentsOf: decodedString)
        }
        string.append(contentsOf: self[index..<endIndex])
        return string
    }

    func decodingBase64(to encoding: Encoding = .utf8) throws -> Self {
        guard let data: Data = Data(base64Encoded: self),
            let string: Self = Self(data: data, encoding: encoding)
        else {
            throw MIMEError.headerNotDecoded(self)
        }
        return string
    }

    func removing(_ characters: [Character]) -> Self {
        var string: Self = "\(self)"
        for character in characters {
            string = string.replacingOccurrences(of: "\(character)", with: "")
        }
        return string
    }

    func trimmed() -> Self {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public var crlf: String { .crlf }

extension [Character] {
    static var quotes: Self { ["\"", "'"] }
}

extension ContentTransferEncoding {
    init(_ string: String) throws {
        switch string.trimmed().uppercased() {
        case "B":
            self = .base64
        case "Q":
            self = .quotedPrintable
        default:
            throw MIMEError.headerNotDecoded(string)
        }
    }
}

extension String.Encoding {

    // TODO: Use `String.Encoding.init(ianaName:)` instead, once available in 26.4 SDK
    // https://developer.apple.com/documentation/swift/string/encoding/init(iananame:)
    init(_ string: String) throws {
        switch string.trimmed().uppercased() {
        case "US-ASCII":
            self = .ascii
        case "ISO-8859-1":
            self = .isoLatin1
        case "ISO-8859-2":
            self = .isoLatin2
        case "UTF-8":
            self = .utf8
        default:
            throw MIMEError.headerNotDecoded(string)
        }
    }
}
