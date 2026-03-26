import Foundation

extension URL {

    /// Generate ``Session`` URL from host and port number.
    ///
    /// All additional URLs and URL templates needed to implement a complete JMAP service are provided in the ``Session``.
    public static func jmapSession(host: String, port: Int? = nil, scheme: String = "https") throws -> Self {
        try jmap(host: host, port: port, scheme: scheme, path: "jmap/session")
    }

    static func jmap(host: String, port: Int? = nil, scheme: String = "https", path: String? = nil) throws -> Self {
        var components: URLComponents = URLComponents()
        components.scheme = scheme
        guard !host.isEmpty else {
            throw URLError(.cannotFindHost)
        }
        components.host = host
        components.port = port
        if let path, !path.isEmpty {
            components.path = path.hasPrefix("/") ? path : "/\(path)"
        }
        guard let url: Self = components.url else {
            throw URLError(.unsupportedURL)
        }
        return url
    }
}
