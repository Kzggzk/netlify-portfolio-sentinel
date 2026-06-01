import Foundation
import XCTest
@testable import NetlifyPortfolioSentinelCore

private struct MockTransport: HTTPTransport {
    let handler: @Sendable (URLRequest) throws -> (Data, HTTPURLResponse)

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try handler(request)
    }
}

final class NetlifyAPIClientTests: XCTestCase {
    func testFetchAllSitesPaginatesUntilShortPage() async throws {
        let transport = MockTransport { request in
            let page = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == "page" })?
                .value ?? "1"
            let body: String
            if page == "1" {
                body = "[" + (0..<100).map { #"{"id":"\#($0)","name":"site-\#($0)"}"# }.joined(separator: ",") + "]"
            } else {
                body = #"[{"id":"last","name":"last-site"}]"#
            }
            return (Data(body.utf8), Self.response(url: request.url!, status: 200))
        }

        let client = try NetlifyAPIClient(token: "token", baseURL: URL(string: "https://example.test/api/v1")!, transport: transport)
        let sites = try await client.fetchAllSites(maxPages: 3, perPage: 100)

        XCTAssertEqual(sites.count, 101)
        XCTAssertEqual(sites.last?.name, "last-site")
    }

    func testHTTPErrorIncludesStatus() async throws {
        let transport = MockTransport { request in
            (Data(#"{"message":"bad token"}"#.utf8), Self.response(url: request.url!, status: 401))
        }
        let client = try NetlifyAPIClient(token: "token", baseURL: URL(string: "https://example.test/api/v1")!, transport: transport)

        do {
            let _: [NetlifySite] = try await client.request(path: "sites")
            XCTFail("Expected HTTP error")
        } catch let error as NetlifyAPIError {
            XCTAssertEqual(error, .httpStatus(401, #"{"message":"bad token"}"#))
        }
    }

    private static func response(url: URL, status: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: url,
            statusCode: status,
            httpVersion: nil,
            headerFields: ["X-RateLimit-Remaining": "499"]
        )!
    }
}
