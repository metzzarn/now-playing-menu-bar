import Foundation

public struct TokenResponse: Decodable, Equatable {
    public let accessToken: String
    public let refreshToken: String?
    public let expiresIn: Int

    public init(accessToken: String, refreshToken: String?, expiresIn: Int) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresIn = expiresIn
    }

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}

public enum AuthError: Error {
    case notLoggedIn
    case tokenRequestFailed
}

public actor SpotifyAuth {
    private let config: SpotifyConfig
    private let http: HTTPFetching
    private let keychain: Keychain
    private let refreshAccount = "spotify-refresh-token"
    private let grantedScopeAccount = "spotify-granted-scope"

    private var accessToken: String?
    private var expiry: Date?

    public init(config: SpotifyConfig,
                http: HTTPFetching = URLSession.shared,
                keychain: Keychain = Keychain()) {
        self.config = config
        self.http = http
        self.keychain = keychain
    }

    public var isLoggedIn: Bool {
        keychain.get(refreshAccount) != nil
    }

    /// The scope granted at the last successful login (stored in the Keychain,
    /// not in the preferences file). Used to detect when a re-login is needed.
    public var grantedScope: String? {
        keychain.get(grantedScopeAccount)
    }

    public func authorizeURL(pkce: PKCE, state: String) -> URL {
        var comps = URLComponents(string: "https://accounts.spotify.com/authorize")!
        comps.queryItems = [
            .init(name: "client_id", value: config.clientID),
            .init(name: "response_type", value: "code"),
            .init(name: "redirect_uri", value: config.redirectURI),
            .init(name: "scope", value: config.scope),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "code_challenge", value: pkce.challenge),
            .init(name: "state", value: state),
        ]
        return comps.url!
    }

    public func exchange(code: String, verifier: String) async throws {
        let token = try await postToken(form([
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": config.redirectURI,
            "client_id": config.clientID,
            "code_verifier": verifier,
        ]))
        store(token)
        keychain.set(config.scope, for: grantedScopeAccount)
    }

    public func validAccessToken() async throws -> String {
        if let token = accessToken, let expiry, expiry > Date().addingTimeInterval(30) {
            return token
        }
        return try await refresh()
    }

    @discardableResult
    public func refresh() async throws -> String {
        guard let refreshToken = keychain.get(refreshAccount) else {
            throw AuthError.notLoggedIn
        }
        let token = try await postToken(form([
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": config.clientID,
        ]))
        store(token)
        return token.accessToken
    }

    public func logout() {
        keychain.delete(refreshAccount)
        keychain.delete(grantedScopeAccount)
        accessToken = nil
        expiry = nil
    }

    private func store(_ token: TokenResponse) {
        accessToken = token.accessToken
        expiry = Date().addingTimeInterval(TimeInterval(token.expiresIn))
        if let refreshToken = token.refreshToken {
            keychain.set(refreshToken, for: refreshAccount)
        }
    }

    private func postToken(_ body: String) async throws -> TokenResponse {
        var request = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded",
                         forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(body.utf8)

        let (data, response) = try await http.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AuthError.tokenRequestFailed
        }
        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }

    private func form(_ params: [String: String]) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return params
            .map { key, value in
                let encoded = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
                return "\(key)=\(encoded)"
            }
            .joined(separator: "&")
    }
}
