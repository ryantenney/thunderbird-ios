/// ``JMAPClient`` requests ``Session`` from `Server`.
public struct Server: CustomStringConvertible, Equatable, Sendable {
    public let authorization: Authorization?
    public let host: String
    public let port: Int
    public let usesTLS: Bool

    public var scheme: String { usesTLS ? "https" : "http" }

    public init(
        authorization: Authorization?,
        host: String,
        port: Int = 443,
        usesTLS: Bool = true
    ) {
        self.authorization = authorization
        self.host = host
        self.port = port
        self.usesTLS = usesTLS
    }

    // MARK: CustomStringConvertible
    public var description: String { "\(scheme)://\(host):\(port)" }
}
