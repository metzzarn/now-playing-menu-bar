import AppKit

actor ArtworkLoader {
    private var cache: [URL: NSImage] = [:]

    func image(for url: URL) async -> NSImage? {
        if let cached = cache[url] { return cached }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let image = NSImage(data: data) else { return nil }
        cache[url] = image
        return image
    }
}
