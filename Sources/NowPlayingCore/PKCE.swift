import Foundation
import CryptoKit

public struct PKCE {
    public let verifier: String
    public let challenge: String

    public init() {
        let verifier = Self.makeVerifier()
        self.verifier = verifier
        self.challenge = Self.challenge(for: verifier)
    }

    public static func makeVerifier(length: Int = 64) -> String {
        let chars = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        var rng = SystemRandomNumberGenerator()
        return String((0..<length).map { _ in chars.randomElement(using: &rng)! })
    }

    public static func challenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return base64URL(Data(digest))
    }

    static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
