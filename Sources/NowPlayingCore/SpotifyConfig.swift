import Foundation

public struct SpotifyConfig {
    public let clientID: String
    public let redirectURI: String
    public let scope: String
    public let port: UInt16

    public init(clientID: String,
                port: UInt16 = 8888,
                scope: String = "user-read-currently-playing user-read-playback-state user-modify-playback-state") {
        self.clientID = clientID
        self.port = port
        self.redirectURI = "http://127.0.0.1:\(port)/callback"
        self.scope = scope
    }
}
