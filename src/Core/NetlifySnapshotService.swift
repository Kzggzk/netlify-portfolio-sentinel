import Foundation

public actor NetlifySnapshotService {
    private let client: NetlifyAPIClient

    public init(client: NetlifyAPIClient) {
        self.client = client
    }

    /// Result of fetching one site's deploy (and optional file) data. Carrying an
    /// explicit `fetchFailed` flag lets the snapshot distinguish "no risk" from
    /// "could not read", which matters for a cost-risk radar.
    private struct SiteScan: Sendable {
        let site: NetlifySite
        let deploys: [NetlifyDeploy]
        let footprintBytes: Int64?
        let fetchFailed: Bool
    }

    public func buildSnapshot(settings: MonitorSettings) async throws -> NetlifySnapshot {
        // Sites and account load in parallel; account is optional and best-effort.
        async let sitesTask = client.fetchAllSites()
        async let accountTask: NetlifyAccount? = fetchOptionalAccount(settings.accountSlug)

        let sites = try await sitesTask.sorted { lhs, rhs in
            (DateParser.parse(lhs.updatedAt) ?? .distantPast) > (DateParser.parse(rhs.updatedAt) ?? .distantPast)
        }
        let account = try await accountTask
        let usageMetrics = UsageMetricExtractor.metrics(from: account)

        let scannedSites = Array(sites.prefix(settings.deployFetchSiteLimit))
        let unscannedSites = sites.dropFirst(settings.deployFetchSiteLimit)
        let footprintIDs = Set(sites.prefix(settings.fileFootprintSiteLimit).map(\.id))

        // Bounded fan-out: fetch deploys (and optional footprints) for every
        // scanned site with at most `maxConcurrentRequests` in flight. Replaces a
        // fully sequential walk — far faster across 140+ sites, still rate-gentle.
        let client = self.client
        let scans = await scannedSites.concurrentMap(maxConcurrency: settings.maxConcurrentRequests) { site in
            let wantsFiles = settings.fetchFileFootprints && footprintIDs.contains(site.id)
            return await Self.scanSite(site, client: client, fetchFiles: wantsFiles)
        }

        let scannedDigests = scans.map { scan in
            RiskScorer.digest(
                site: scan.site,
                deploys: scan.deploys,
                settings: settings,
                currentDeployFootprintBytes: scan.footprintBytes,
                deployDataAvailable: !scan.fetchFailed
            )
        }
        // Sites beyond the scan limit are intentionally not fetched; they appear
        // with empty deploy history rather than a fetch failure.
        let unscannedDigests = unscannedSites.map { site in
            RiskScorer.digest(site: site, deploys: [], settings: settings, currentDeployFootprintBytes: nil)
        }

        let allDigests = (scannedDigests + unscannedDigests).sorted {
            if $0.riskLevel != $1.riskLevel {
                return $0.riskLevel > $1.riskLevel
            }
            return $0.deploysInLookback > $1.deploysInLookback
        }

        let totalDeploys = allDigests.map(\.deploysInLookback).reduce(0, +)
        let failedDeploys = allDigests.map(\.failedDeploysInLookback).reduce(0, +)
        let fetchFailures = scans.filter(\.fetchFailed).count

        return NetlifySnapshot(
            generatedAt: DateParser.isoString(),
            account: account,
            usageMetrics: usageMetrics,
            sites: allDigests,
            totalSites: sites.count,
            totalDeploysInLookback: totalDeploys,
            failedDeploysInLookback: failedDeploys,
            degradedReason: Self.bandwidthDegradedReason(usageMetrics: usageMetrics),
            apiRateLimitRemaining: client.lastRateLimitRemaining,
            deployFetchFailures: fetchFailures
        )
    }

    /// Fetches one site's deploy history and (optionally) its file footprint.
    /// A deploy-fetch error is reported via `fetchFailed`; a footprint error is
    /// non-fatal and simply leaves the footprint unknown.
    private static func scanSite(
        _ site: NetlifySite,
        client: NetlifyAPIClient,
        fetchFiles: Bool
    ) async -> SiteScan {
        do {
            let deploys = try await client.fetchDeploys(siteID: site.id)
            var footprint: Int64?
            if fetchFiles, let files = try? await client.fetchFiles(siteID: site.id), !files.isEmpty {
                footprint = files.compactMap(\.size).reduce(0, +)
            }
            return SiteScan(site: site, deploys: deploys, footprintBytes: footprint, fetchFailed: false)
        } catch {
            return SiteScan(site: site, deploys: [], footprintBytes: nil, fetchFailed: true)
        }
    }

    /// The structural degraded-mode note: Netlify's token-scoped public API may
    /// not expose per-site bandwidth, so the snapshot says so plainly rather than
    /// faking a bandwidth number. Transient fetch gaps are reported separately via
    /// `NetlifySnapshot.deployFetchFailures`.
    private static func bandwidthDegradedReason(usageMetrics: [UsageMetric]) -> String? {
        if usageMetrics.contains(where: { $0.key.lowercased().contains("bandwidth") }) {
            return nil
        }
        return "Netlify public API did not expose per-site bandwidth in this token response; showing deploy, site, account quota, and optional file-footprint risk instead."
    }

    private func fetchOptionalAccount(_ slug: String?) async throws -> NetlifyAccount? {
        guard let slug, !slug.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return try? await client.fetchAccount(idOrSlug: slug)
    }
}
