import Foundation
import Network

public enum LoopbackError: Error, Equatable {
    case timedOut
    case listenerFailed
}

public struct OAuthCallback: Equatable {
    public let code: String
    public let state: String?

    public init(code: String, state: String?) {
        self.code = code
        self.state = state
    }
}

// All state is mutated only on the main queue (handlers and the timeout are
// scheduled there), so the class is safe to treat as Sendable.
public final class LoopbackServer: @unchecked Sendable {
    private let port: UInt16
    private var listener: NWListener?
    private var didFinish = false

    public init(port: UInt16) {
        self.port = port
    }

    /// Listens on 127.0.0.1:port and resolves with the OAuth callback (code +
    /// state) from the first matching request, then shuts down. Throws
    /// `LoopbackError.timedOut` if no callback arrives within `timeout`, and
    /// `LoopbackError.listenerFailed` if the port cannot be bound. All handling
    /// runs on the main queue, so `didFinish` guards against a double resume.
    public func waitForCode(timeout: TimeInterval = 120) async throws -> OAuthCallback {
        try await withCheckedThrowingContinuation { continuation in
            @Sendable func finish(_ result: Result<OAuthCallback, Error>) {
                guard !didFinish else { return }
                didFinish = true
                stop()
                continuation.resume(with: result)
            }

            let listener: NWListener
            do {
                listener = try NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: port)!)
            } catch {
                continuation.resume(throwing: error)
                return
            }
            self.listener = listener

            listener.stateUpdateHandler = { state in
                if case .failed = state {
                    finish(.failure(LoopbackError.listenerFailed))
                }
            }

            listener.newConnectionHandler = { connection in
                connection.start(queue: .main)
                connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) {
                    data, _, _, _ in
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
                    if let callback = Self.extractCallback(from: request) {
                        finish(.success(callback))
                    }
                }
            }

            listener.start(queue: .main)

            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
                finish(.failure(LoopbackError.timedOut))
            }
        }
    }

    public func stop() {
        listener?.cancel()
        listener = nil
    }

    static func extractCallback(from request: String) -> OAuthCallback? {
        guard let firstLine = request.split(separator: "\r\n").first,
              let pathPart = firstLine.split(separator: " ").dropFirst().first,
              let comps = URLComponents(string: "http://localhost\(pathPart)"),
              let code = comps.queryItems?.first(where: { $0.name == "code" })?.value else {
            return nil
        }
        let state = comps.queryItems?.first(where: { $0.name == "state" })?.value
        return OAuthCallback(code: code, state: state)
    }
}
