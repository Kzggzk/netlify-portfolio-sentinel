import XCTest
@testable import NetlifyPortfolioSentinelCore

final class RiskScorerTests: XCTestCase {
    func testHighDeployVolumeRaisesRisk() {
        let site = NetlifySite(id: "site-1", name: "busy")
        let deploys = (0..<25).map { index in
            NetlifyDeploy(
                id: "deploy-\(index)",
                state: "ready",
                createdAt: DateParser.isoString(Date().addingTimeInterval(TimeInterval(-index * 60)))
            )
        }

        let digest = RiskScorer.digest(
            site: site,
            deploys: deploys,
            settings: MonitorSettings(deployLookbackDays: 7),
            currentDeployFootprintBytes: nil
        )

        XCTAssertEqual(digest.riskLevel, .high)
        XCTAssertEqual(digest.deploysInLookback, 25)
    }

    func testFailedDeployRaisesRisk() {
        let site = NetlifySite(id: "site-1", name: "broken")
        let deploys = [
            NetlifyDeploy(id: "deploy-1", state: "error", createdAt: DateParser.isoString())
        ]

        let digest = RiskScorer.digest(
            site: site,
            deploys: deploys,
            settings: MonitorSettings(deployLookbackDays: 7),
            currentDeployFootprintBytes: nil
        )

        XCTAssertEqual(digest.riskLevel, .high)
        XCTAssertEqual(digest.failedDeploysInLookback, 1)
    }

    func testAccountQuotaRaisesCriticalRisk() {
        let metrics = [
            UsageMetric(key: "bandwidth", label: "Bandwidth", used: 95, included: 100)
        ]

        let result = RiskScorer.accountRisk(metrics: metrics, settings: MonitorSettings())

        XCTAssertEqual(result.0, .critical)
        XCTAssertFalse(result.1.isEmpty)
    }
}
