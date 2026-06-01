import XCTest
@testable import NetlifyPortfolioSentinelCore

final class UsageMetricExtractorTests: XCTestCase {
    func testExtractsBandwidthCapability() throws {
        let json = """
        {
          "id": "acct",
          "name": "KZG",
          "slug": "baofang1990",
          "capabilities": {
            "bandwidth": { "used": 70, "included": 100 },
            "sites": { "used": 141, "included": 500 }
          }
        }
        """
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let account = try decoder.decode(NetlifyAccount.self, from: Data(json.utf8))

        let metrics = UsageMetricExtractor.metrics(from: account)

        XCTAssertTrue(metrics.contains(where: { $0.key == "bandwidth" && $0.ratio == 0.7 }))
        XCTAssertTrue(metrics.contains(where: { $0.key == "sites" && $0.used == 141 }))
    }
}
