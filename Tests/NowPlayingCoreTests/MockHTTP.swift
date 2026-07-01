import Foundation
@testable import NowPlayingCore

final class MockHTTP: HTTPFetching {
    var status: Int
    var body: Data
    private(set) var lastRequest: URLRequest?

    init(status: Int, body: Data = Data()) {
        self.status = status
        self.body = body
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request
        let response = HTTPURLResponse(
            url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        return (body, response)
    }
}
