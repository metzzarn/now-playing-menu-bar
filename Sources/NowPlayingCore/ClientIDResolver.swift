import Foundation

public enum ClientIDResolver {
    public static func resolve(preferences: Preferences,
                               environment: [String: String]) -> String? {
        if let id = preferences.clientID, !id.isEmpty { return id }
        if let env = environment["SPOTIFY_CLIENT_ID"], !env.isEmpty { return env }
        return nil
    }
}
