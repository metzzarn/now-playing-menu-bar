import Foundation
import Network

public final class LoopbackServer {
    private let port: UInt16
    private var listener: NWListener?

    public init(port: UInt16) {
        self.port = port
    }

    /// Listens on 127.0.0.1:port and resolves with the `code` from the first
    /// callback request, then shuts down.
    public func waitForCode() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            do {
                let listener = try NWListener(
                    using: .tcp, on: NWEndpoint.Port(rawValue: port)!)
                self.listener = listener
                var finished = false

                listener.newConnectionHandler = { [weak self] connection in
                    connection.start(queue: .main)
                    connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) {
                        data, _, _, _ in
                        guard !finished else { return }
                        let request = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                        let html = "<html><body>Login complete. You can close this window.</body></html>"
                        let response = """
                        HTTP/1.1 200 OK\r
                        Content-Type: text/html\r
                        Content-Length: \(html.utf8.count)\r
                        Connection: close\r
                        \r
                        \(html)
                        """
                        connection.send(content: Data(response.utf8),
                                        completion: .contentProcessed { _ in
                            connection.cancel()
                        })
                        if let code = Self.extractCode(from: request) {
                            finished = true
                            self?.stop()
                            continuation.resume(returning: code)
                        }
                    }
                }
                listener.start(queue: .main)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    public func stop() {
        listener?.cancel()
        listener = nil
    }

    static func extractCode(from request: String) -> String? {
        guard let firstLine = request.split(separator: "\r\n").first,
              let pathPart = firstLine.split(separator: " ").dropFirst().first,
              let comps = URLComponents(string: "http://localhost\(pathPart)") else {
            return nil
        }
        return comps.queryItems?.first(where: { $0.name == "code" })?.value
    }
}
