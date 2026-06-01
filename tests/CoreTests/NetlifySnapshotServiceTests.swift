import Foundation
import XCTest
@testable import NetlifyPortfolioSentinelCore

private struct RoutingTransport: HTTPTransport {
    let handler: @Sendable (URLRequest) throws -> (Data, HTTPURLResponse)

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try handler(request)
    }
}

final class NetlifySnapshotServiceTests: XCTestCase {
    /// The core guarantee of the refactor: deploys fan out concurrently, and a
    /// site whose deploy fetch fails is reported as "unknown" (watch), never as a
    /// silent "0 deploys = safe".
    func testBuildSnapshotFlagsUnreadableSitesInsteadOfHidingThem() async throws {
        let nowISO = DateParser.isoString()
        let transport = RoutingTransport { request in
            let url = request.url!
            let path = url.path

            if path.hasSuffix("/sites") {
                let page = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?.first(where: { $0.name == "page" })?.value ?? "1"
                if page == "1" {
                    let body = #"""
                    [
                      {"id":"good","name":"good-site","updated_at":"2026-06-01T10:00:00Z"},
                      {"id":"bad","name":"bad-site","updated_at":"2026-06-01T09:00:00Z"}
                    ]
                    """#
                    return (Data(body.utf8), Self.ok(url))
                }
                return (Data("[]".utf8), Self.ok(url))
            }

            if path.contains("/sites/good/deploys") {
                let body = "[{\"id\":\"d1\",\"state\":\"ready\",\"created_at\":\"\(nowISO)\"}]"
                return (Data(body.utf8), Self.ok(url))
            }

            if path.contains("/sites/bad/deploys") {
                // Simulate a transient server error for one site only.
                return (Data(#"{"message":"boom"}"#.utf8), Self.status(url, 500))
            }

            if path.contains("/accounts/") {
                let body = #"{"id":"acct","name":"KZG","slug":"baofang1990","type_name":"Pro"}"#
                return (Data(body.utf8), Self.ok(url))
            }

            return (Data("[]".utf8), Self.ok(url))
        }

        let client = try NetlifyAPIClient(
            token: "token",
            baseURL: URL(string: "https://example.test/api/v1")!,
            transport: transport
        )
        let service = NetlifySnapshotService(client: client)
        let snapshot = try await service.buildSnapshot(
            settings: MonitorSettings(accountSlug: "baofang1990", deployLookbackDays: 30, maxConcurrentRequests: 4)
        )

        XCTAssertEqual(snapshot.totalSites, 2)
        XCTAssertEqual(snapshot.deployFetchFailures, 1)
        XCTAssertEqual(snapshot.unavailableSiteCount, 1)
        XCTAssertEqual(snapshot.account?.slug, "baofang1990")

        let bad = try XCTUnwrap(snapshot.sites.first { $0.site.id == "bad" })
        XCTAssertEqual(bad.riskLevel, .watch)
        XCTAssertEqual(bad.deploysInLookback, 0)
        XCTAssertTrue(bad.riskReasons.first?.lowercased().contains("unavailable") ?? false)

        let good = try XCTUnwrap(snapshot.sites.first { $0.site.id == "good" })
        XCTAssertEqual(good.deploysInLookback, 1)
        XCTAssertEqual(good.failedDeploysInLookback, 0)

        // Totals aggregate only readable sites; the unreadable one is not counted as 0-risk.
        XCTAssertEqual(snapshot.totalDeploysInLookback, 1)
    }

    func testBuildSnapshotAllReadableHasNoFailures() async throws {
        let nowISO = DateParser.isoString()
        let transport = RoutingTransport { request in
            let url = request.url!
            let path = url.path
            if path.hasSuffix("/sites") {
                let page = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?.first(where: { $0.name == "page" })?.value ?? "1"
                let body = page == "1"
                    ? #"[{"id":"a","name":"a","updated_at":"2026-06-01T10:00:00Z"}]"#
                    : "[]"
                return (Data(body.utf8), Self.ok(url))
            }
            if path.contains("/deploys") {
                let body = "[{\"id\":\"d\",\"state\":\"ready\",\"created_at\":\"\(nowISO)\"}]"
                return (Data(body.utf8), Self.ok(url))
            }
            return (Data("{}".utf8), Self.ok(url))
        }

        let client = try NetlifyAPIClient(
            token: "token",
            baseURL: URL(string: "https://example.test/api/v1")!,
            transport: transport
        )
        let snapshot = try await NetlifySnapshotService(client: client)
            .buildSnapshot(settings: MonitorSettings(deployLookbackDays: 30))

        XCTAssertEqual(snapshot.totalSites, 1)
        XCTAssertEqual(snapshot.deployFetchFailures, 0)
        XCTAssertEqual(snapshot.unavailableSiteCount, 0)
    }

    private static func ok(_ url: URL) -> HTTPURLResponse { status(url, 200) }

    private static func status(_ url: URL, _ status: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: url,
            statusCode: status,
            httpVersion: nil,
            headerFields: ["X-RateLimit-Remaining": "499"]
        )!
    }
}
