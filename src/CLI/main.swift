import Foundation
import NetlifyPortfolioSentinelCore

@main
struct SentinelCLI {
    static func main() async {
        let arguments = Array(CommandLine.arguments.dropFirst())
        if arguments.contains("--help") || arguments.contains("-h") {
            printHelp()
            return
        }

        if arguments.first == "demo" {
            printDemo()
            return
        }

        guard let token = ProcessInfo.processInfo.environment["NETLIFY_AUTH_TOKEN"], !token.isEmpty else {
            fputs("Missing NETLIFY_AUTH_TOKEN. Run `sentinelctl demo` for an offline smoke test.\n", stderr)
            Foundation.exit(2)
        }

        let accountSlug = value(after: "--account", in: arguments) ?? ProcessInfo.processInfo.environment["NETLIFY_ACCOUNT_SLUG"]
        let limit = Int(value(after: "--limit", in: arguments) ?? "") ?? 160
        let lookback = Int(value(after: "--days", in: arguments) ?? "") ?? 7
        let files = arguments.contains("--files")

        do {
            let client = try NetlifyAPIClient(token: token)
            let service = NetlifySnapshotService(client: client)
            let snapshot = try await service.buildSnapshot(
                settings: MonitorSettings(
                    accountSlug: accountSlug,
                    deployLookbackDays: lookback,
                    deployFetchSiteLimit: limit,
                    fetchFileFootprints: files
                )
            )
            try SnapshotCache().save(snapshot)
            printSummary(snapshot)
        } catch {
            fputs("\(error.localizedDescription)\n", stderr)
            Foundation.exit(1)
        }
    }

    private static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }

    private static func printHelp() {
        print("""
        sentinelctl

        Commands:
          demo                         Print an offline sample summary.
          snapshot [--account slug]    Fetch Netlify account/site/deploy data.

        Options:
          --days N                     Deploy lookback window. Default: 7.
          --limit N                    Number of sites to scan for deploys. Default: 160.
          --files                      Fetch current deploy file footprints for top sites.

        Required env for live mode:
          NETLIFY_AUTH_TOKEN           Netlify personal access token.
          NETLIFY_ACCOUNT_SLUG         Optional account/team slug, e.g. baofang1990.
        """)
    }

    private static func printDemo() {
        let site = NetlifySite(id: "demo", name: "kzg-option-house", url: "https://kzg-option-house.netlify.app")
        let deploy = NetlifyDeploy(id: "deploy-demo", state: "ready", createdAt: DateParser.isoString())
        let digest = RiskScorer.digest(
            site: site,
            deploys: [deploy],
            settings: MonitorSettings(accountSlug: "baofang1990"),
            currentDeployFootprintBytes: 42_000_000
        )
        let snapshot = NetlifySnapshot(
            generatedAt: DateParser.isoString(),
            account: NetlifyAccount(id: "demo", name: "KZG", slug: "baofang1990", typeName: "Pro"),
            usageMetrics: [UsageMetric(key: "bandwidth", label: "Bandwidth", used: 56, included: 100, unit: "GB")],
            sites: [digest],
            totalSites: 1,
            totalDeploysInLookback: 1,
            failedDeploysInLookback: 0,
            degradedReason: nil,
            apiRateLimitRemaining: 499
        )
        printSummary(snapshot)
    }

    private static func printSummary(_ snapshot: NetlifySnapshot) {
        print("Netlify Portfolio Sentinel")
        print("Generated: \(snapshot.generatedAt)")
        print("Sites: \(snapshot.totalSites)")
        print("Deploys in window: \(snapshot.totalDeploysInLookback)")
        print("Failed deploys: \(snapshot.failedDeploysInLookback)")
        print("Highest risk: \(snapshot.highestRisk.rawValue)")
        if let remaining = snapshot.apiRateLimitRemaining {
            print("API rate remaining: \(remaining)")
        }
        if let degraded = snapshot.degradedReason {
            print("Notice: \(degraded)")
        }
        print("")
        print("Top sites:")
        for digest in snapshot.sites.prefix(12) {
            print("- \(digest.site.name): \(digest.riskLevel.rawValue), deploys=\(digest.deploysInLookback), last=\(Humanize.compactDate(digest.lastDeployAt))")
            if let reason = digest.riskReasons.first {
                print("  \(reason)")
            }
        }
    }
}
