import Foundation

public enum MIMEError: Error, CustomStringConvertible, Equatable {
    case boundaryLength(Int)
    case boundaryNotASCII
    case characterSetNotFound
    case contentDispositionNotFound
    case contentTypeNotFound
    case contentTypeNotMultipart
    case contentTypeNotPossible(ContentType)
    case dataNotDecoded(Data, encoding: String.Encoding? = nil)
    case dataNotFound
    case dataNotQuotedPrintable
    case dateNotDecoded(String)
    case headerNotDecoded(String)

    // MARK: CustomStringConvertible
    public var description: String {
        switch self {
        case .boundaryLength(let length): "Multipart data boundary length \(length) outside of bounds \(Boundary.bounds)"
        case .boundaryNotASCII: "Multipart data boundary not ASCII"
        case .characterSetNotFound: "Character set not found"
        case .contentDispositionNotFound: "Content disposition not found"
        case .contentTypeNotFound: "Content type not found"
        case .contentTypeNotMultipart: "Content type not multipart"
        case .contentTypeNotPossible(let contentType): "Content type not possible: \(contentType)"
        case .dataNotDecoded(let data, _): "Multipart data not decoded: \(String(data: data, encoding: .ascii) ?? "�")"
        case .dataNotFound: "Multipart data not found"
        case .dataNotQuotedPrintable: "Data not quoted-printable"
        case .dateNotDecoded(let string): "Date not decoded: \(string)"
        case .headerNotDecoded(let string): "Header not decoded: \(string)"
        }
    }
}
