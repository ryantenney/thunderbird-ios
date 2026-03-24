import Foundation
import OSLog

private let logger = Logger(subsystem: "net.thunderbird", category: "JMAP.HTTP")

extension URLSession {

    /// Post methods to JMAP service.
    /// - Parameter methods: One or more ``Method``s for JMAP service to perform
    /// - Parameter url: API endpoint URL from ``Session``
    /// - Parameter authorization: ``Authorization`` credentials or token for request header
    /// - Returns: ``MethodResponse``
    public func jmapAPI(_ methods: [any Method], url: URL, authorization: Authorization) async throws -> [any MethodResponse] {
        let methodNames = methods.map { type(of: $0).name }.joined(separator: ", ")
        logger.debug("API request: \(url) methods=[\(methodNames)]")
        let response: (Data, URLResponse)
        do {
            response = try await data(for: try .jmapAPI(methods, url: url, authorization: authorization))
        } catch {
            logger.error("API request failed: \(url) error=\(error)")
            throw error
        }
        if let httpResponse = response.1 as? HTTPURLResponse {
            logger.debug("API response: \(url) status=\(httpResponse.statusCode) bytes=\(response.0.count)")
        }
        let data: Data = response.0
        let object: Any = try JSONSerialization.jsonObject(with: data)

        // Unwrap and map responses from "envelope" array
        guard let object: [String: Any] = object as? [String: Any],
            let responses: [[Any]] = object["methodResponses"] as? [[Any]], !responses.isEmpty
        else {
            throw URLError(.cannotDecodeContentData)
        }
        return try responses.map { response in

            // Parse each raw response into return response types
            guard response.count == 3,
                let name: String = response[0] as? String, name.contains("/"),
                let object: [String: Any] = response[1] as? [String: Any],
                let id: UUID = UUID(uuidString: response[2] as? String ?? "")
            else {
                throw URLError(.cannotDecodeContentData)
            }
            switch name.components(separatedBy: "/").last {
            case "get":

                // Map generic parts of [get response.](https://jmap.io/spec-core.html#get)
                guard let notFound: [String] = object["notFound"] as? [String],
                    let list: [Any] = object["list"] as? [Any]
                else {
                    throw URLError(.cannotDecodeContentData)
                }

                // Re-encode as `Decodable` data; now synthesized `Codable` conformance can be used for decoding models.
                let data: Data = try JSONSerialization.data(withJSONObject: list)
                return MethodGetResponse(name, data: data, notFound: notFound, id: id)
            case "query":

                // Map generic parts of [query response.](https://jmap.io/spec-core.html#query)
                guard let ids: [String] = object["ids"] as? [String],
                    let position: Int = object["position"] as? Int,
                    let total: Int = object["total"] as? Int
                else {
                    throw URLError(.cannotDecodeContentData)
                }
                return MethodQueryResponse(name, ids: ids, position: position, total: total, id: id)
            case "set":

                // Map generic parts of [set response.](https://jmap.io/spec-core.html#set)
                func mapErrorValues(for key: String) -> [String: SetError] {
                    (object[key] as? [String: Any] ?? [:])
                        .mapValues { SetError($0) ?? .notFound }
                }

                let created: [String: Any] = object["created"] as? [String: Any] ?? [:]
                let updated: [String] = (object["updated"] as? [String: Any] ?? [:]).keys.map { "\($0)" }
                let destroyed: [String] = object["destroyed"] as? [String] ?? []
                return MethodSetResponse(
                    name,
                    created: created,
                    updated: updated,
                    destroyed: destroyed,
                    notCreated: mapErrorValues(for: "notCreated"),
                    notUpdated: mapErrorValues(for: "notUpdated"),
                    notDestroyed: mapErrorValues(for: "notDestroyed"),
                    id: id
                )
            case "echo":
                guard object["hello"] as? Bool != nil else {
                    throw URLError(.cannotDecodeContentData)
                }
                return MethodEchoResponse(name, id: id)
            default:
                throw URLError(.cannotDecodeContentData)
            }
        }
    }

    /// Get JMAP session object from a service provider.
    /// - Parameter server: ``Server`` configuration for JMAP service provider
    /// - Returns: ``Session`` object containing available account(s), capabilities and service URLs
    public func jmapSession(server: Server) async throws -> Session {
        try await jmapSession(host: server.host, port: server.port, authorization: server.authorization ?? .empty)
    }

    /// Get JMAP session object from a service provider.
    /// - Parameter host: Host name of the JMAP service provider; e.g., `api.fastmail.com`
    /// - Parameter authorization: ``Authorization`` credentials or token for request header
    /// - Returns: ``Session`` object containing available account(s), capabilities and service URLs
    public func jmapSession(host: String, port: Int? = nil, authorization: Authorization) async throws -> Session {
        let url = try URL.jmapSession(host: host, port: port)
        logger.debug("Session request: \(url) auth=\(authorization.label) empty=\(authorization.isEmpty)")
        let response: (Data, URLResponse)
        do {
            response = try await data(for: try .jmapSession(host: host, port: port, authorization: authorization))
        } catch {
            logger.error("Session request failed: \(url) error=\(error)")
            throw error
        }
        let statusCode = (response.1 as? HTTPURLResponse)?.statusCode
        logger.debug("Session response: \(url) status=\(statusCode ?? -1) bytes=\(response.0.count)")
        switch statusCode {
        case 401:
            logger.error("Session auth rejected (401): \(url)")
            throw URLError(.userAuthenticationRequired)
        default:
            do {
                let session: Session = try JSONDecoder().decode(Session.self, from: response.0)
                return session
            } catch {
                logger.error("Session decode failed: \(error) body=\(String(data: response.0.prefix(500), encoding: .utf8) ?? "<binary>")")
                throw error
            }
        }
    }
}
