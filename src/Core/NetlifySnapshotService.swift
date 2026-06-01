import Foundation

public actor NetlifySnapshotService {
    private let client: NetlifyAPIClient

    public init(client: NetlifyAPIClient) {
        self.client = client
    }

    public func buildSnapshot(settings: MonitorSettings) async throws -> NetlifySnapshot {
        async let sitesTask = client.fetchAllSites()
        async let accountTask: NetlifyAccount? = fetchOptionalAccount(settings.accountSlug)

        let sites = try await sitesTask.sorted { lhs, rhs in
            (DateParser.parse(lhs.updatedAt) ?? .distantPast) > (DateParser.parse(rhs.updatedAt) ?? .distantPast)
        }
        let account = try await accountTask
        let usageMetrics = UsageMetricExtractor.metrics(from: account)

        var digests: [SiteDigest] = []
        let deploySites = Array(sites.prefix(settings.deployFetchSiteLimit))
        let footprintIDs = Set(sites.prefix(settings.fileFootprintSiteLimit).map(\.id))

        for site in deploySites {
            let deploys = (try? await client.fetchDeploys(siteID: site.id)) ?? []
            let footprint: Int64?
            if settings.fetchFileFootprints && footprintIDs.contains(site.id) {
                let files = (try? await client.fetchFiles(siteID: site.id)) ?? []
                footprint = files.compactMap(\.size).reduce(0, +)
            } else {
                footprint = nil
            }

            digests.append(
                RiskScorer.digest(
                    site: site,
                    deploys: deploys,
                    settings: settings,
                    currentDeployFootprintBytes: footprint
                )
            )
        }

        let notScanned = sites.dropFirst(settings.deployFetchSiteLimit).map { site in
            RiskScorer.digest(
                site: site,
                deploys: [],
                settings: settings,
                currentDeployFootprintBytes: nil
            )
        }

        let allDigests = (digests + notScanned).sorted {
            if $0.riskLevel != $1.riskLevel {
                return $0.riskLevel > $1.riskLevel
            }
            return $0.deploysInLookback > $1.deploysInLookback
        }

        let totalDeploys = allDigests.map(\.deploysInLookback).reduce(0, +)
        let failedDeploys = allDigests.map(\.failedDeploysInLookback).reduce(0, +)
        let degradedReason: String?
        if usageMetrics.contains(where: { $0.key.lowercased().contains("bandwidth") }) {
            degradedReason = nil
        } else {
            degradedReason = "Netlify public API did not expose per-site bandwidth in this token response; showing deploy, site, account quota, and optional file-footprint risk instead."
        }

        return NetlifySnapshot(
            generatedAt: DateParser.isoString(),
            account: account,
            usageMetrics: usageMetrics,
            sites: allDigests,
            totalSites: sites.count,
            totalDeploysInLookback: totalDeploys,
            failedDeploysInLookback: failedDeploys,
            degradedReason: degradedReason,
            apiRateLimitRemaining: client.lastRateLimitRemaining
        )
    }

    private func fetchOptionalAccount(_ slug: String?) async throws -> NetlifyAccount? {
        guard let slug, !slug.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return try? await client.fetchAccount(idOrSlug: slug)
    }
}
