import Foundation

public protocol HTTPFetching {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: HTTPFetching {}
