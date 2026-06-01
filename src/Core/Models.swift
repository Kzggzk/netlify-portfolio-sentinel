import Foundation

public struct NetlifySite: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let url: String?
    public let sslUrl: String?
    public let adminUrl: String?
    public let screenshotUrl: String?
    public let customDomain: String?
    public let accountSlug: String?
    public let state: String?
    public let createdAt: String?
    public let updatedAt: String?
    public let publishedDeploy: NetlifyDeploy?

    public init(
        id: String,
        name: String,
        url: String? = nil,
        sslUrl: String? = nil,
        adminUrl: String? = nil,
        screenshotUrl: String? = nil,
        customDomain: String? = nil,
        accountSlug: String? = nil,
        state: String? = nil,
        createdAt: String? = nil,
        updatedAt: String? = nil,
        publishedDeploy: NetlifyDeploy? = nil
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.sslUrl = sslUrl
        self.adminUrl = adminUrl
        self.screenshotUrl = screenshotUrl
        self.customDomain = customDomain
        self.accountSlug = accountSlug
        self.state = state
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.publishedDeploy = publishedDeploy
    }
}

public struct NetlifyDeploy: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let siteId: String?
    public let buildId: String?
    public let name: String?
    public let state: String?
    public let url: String?
    public let sslUrl: String?
    public let deployUrl: String?
    public let deploySslUrl: String?
    public let branch: String?
    public let context: String?
    public let createdAt: String?
    public let updatedAt: String?
    public let publishedAt: String?
    public let errorMessage: String?
    public let deployTime: Int?

    public init(
        id: String,
        siteId: String? = nil,
        buildId: String? = nil,
        name: String? = nil,
        state: String? = nil,
        url: String? = nil,
        sslUrl: String? = nil,
        deployUrl: String? = nil,
        deploySslUrl: String? = nil,
        branch: String? = nil,
        context: String? = nil,
        createdAt: String? = nil,
        updatedAt: String? = nil,
        publishedAt: String? = nil,
        errorMessage: String? = nil,
        deployTime: Int? = nil
    ) {
        self.id = id
        self.siteId = siteId
        self.buildId = buildId
        self.name = name
        self.state = state
        self.url = url
        self.sslUrl = sslUrl
        self.deployUrl = deployUrl
        self.deploySslUrl = deploySslUrl
        self.branch = branch
        self.context = context
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.publishedAt = publishedAt
        self.errorMessage = errorMessage
        self.deployTime = deployTime
    }
}

public struct NetlifyFile: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let path: String?
    public let sha: String?
    public let mimeType: String?
    public let size: Int64?

    public init(id: String, path: String? = nil, sha: String? = nil, mimeType: String? = nil, size: Int64? = nil) {
        self.id = id
        self.path = path
        self.sha = sha
        self.mimeType = mimeType
        self.size = size
    }
}

public struct NetlifyAccount: Codable, Equatable, Sendable {
    public let id: String?
    public let name: String?
    public let slug: String?
    public let typeName: String?
    public let billingPeriod: String?
    public let capabilities: [String: JSONValue]?

    public init(
        id: String? = nil,
        name: String? = nil,
        slug: String? = nil,
        typeName: String? = nil,
        billingPeriod: String? = nil,
        capabilities: [String: JSONValue]? = nil
    ) {
        self.id = id
        self.name = name
        self.slug = slug
        self.typeName = typeName
        self.billingPeriod = billingPeriod
        self.capabilities = capabilities
    }
}

public struct UsageMetric: Codable, Equatable, Sendable {
    public let key: String
    public let label: String
    public let used: Double?
    public let included: Double?
    public let unit: String

    public init(key: String, label: String, used: Double?, included: Double?, unit: String = "") {
        self.key = key
        self.label = label
        self.used = used
        self.included = included
        self.unit = unit
    }

    public var ratio: Double? {
        guard let used, let included, included > 0 else { return nil }
        return used / included
    }
}

public enum RiskLevel: String, Codable, Comparable, Sendable {
    case low
    case watch
    case high
    case critical

    public static func < (lhs: RiskLevel, rhs: RiskLevel) -> Bool {
        lhs.rank < rhs.rank
    }

    public var rank: Int {
        switch self {
        case .low: return 0
        case .watch: return 1
        case .high: return 2
        case .critical: return 3
        }
    }
}

public struct SiteDigest: Codable, Identifiable, Equatable, Sendable {
    public var id: String { site.id }
    public let site: NetlifySite
    public let deploys: [NetlifyDeploy]
    public let deploysInLookback: Int
    public let failedDeploysInLookback: Int
    public let lastDeployAt: String?
    public let lastDeployState: String?
    public let currentDeployFootprintBytes: Int64?
    public let riskLevel: RiskLevel
    public let riskReasons: [String]

    public init(
        site: NetlifySite,
        deploys: [NetlifyDeploy],
        deploysInLookback: Int,
        failedDeploysInLookback: Int,
        lastDeployAt: String?,
        lastDeployState: String?,
        currentDeployFootprintBytes: Int64?,
        riskLevel: RiskLevel,
        riskReasons: [String]
    ) {
        self.site = site
        self.deploys = deploys
        self.deploysInLookback = deploysInLookback
        self.failedDeploysInLookback = failedDeploysInLookback
        self.lastDeployAt = lastDeployAt
        self.lastDeployState = lastDeployState
        self.currentDeployFootprintBytes = currentDeployFootprintBytes
        self.riskLevel = riskLevel
        self.riskReasons = riskReasons
    }
}

public struct MonitorSettings: Codable, Equatable, Sendable {
    public var accountSlug: String?
    public var deployLookbackDays: Int
    public var deployFetchSiteLimit: Int
    public var fetchFileFootprints: Bool
    public var fileFootprintSiteLimit: Int
    public var warningUsageRatio: Double
    public var criticalUsageRatio: Double
    public var refreshIntervalMinutes: Int
    /// Upper bound on simultaneous Netlify requests during a snapshot fan-out.
    /// Keeps the portfolio scan fast without tripping the API rate limit.
    public var maxConcurrentRequests: Int

    public init(
        accountSlug: String? = nil,
        deployLookbackDays: Int = 7,
        deployFetchSiteLimit: Int = 160,
        fetchFileFootprints: Bool = false,
        fileFootprintSiteLimit: Int = 12,
        warningUsageRatio: Double = 0.70,
        criticalUsageRatio: Double = 0.90,
        refreshIntervalMinutes: Int = 15,
        maxConcurrentRequests: Int = 6
    ) {
        self.accountSlug = accountSlug
        self.deployLookbackDays = deployLookbackDays
        self.deployFetchSiteLimit = deployFetchSiteLimit
        self.fetchFileFootprints = fetchFileFootprints
        self.fileFootprintSiteLimit = fileFootprintSiteLimit
        self.warningUsageRatio = warningUsageRatio
        self.criticalUsageRatio = criticalUsageRatio
        self.refreshIntervalMinutes = refreshIntervalMinutes
        self.maxConcurrentRequests = maxConcurrentRequests
    }
}

public struct NetlifySnapshot: Codable, Equatable, Sendable {
    public let generatedAt: String
    public let account: NetlifyAccount?
    public let usageMetrics: [UsageMetric]
    public let sites: [SiteDigest]
    public let totalSites: Int
    public let totalDeploysInLookback: Int
    public let failedDeploysInLookback: Int
    public let degradedReason: String?
    public let apiRateLimitRemaining: Int?
    /// Count of scanned sites whose deploy history could not be fetched this run.
    /// Optional so snapshots written before this field still decode cleanly.
    /// A non-nil, non-zero value means some risk readings are "unknown", not "safe".
    public let deployFetchFailures: Int?

    public init(
        generatedAt: String,
        account: NetlifyAccount?,
        usageMetrics: [UsageMetric],
        sites: [SiteDigest],
        totalSites: Int,
        totalDeploysInLookback: Int,
        failedDeploysInLookback: Int,
        degradedReason: String?,
        apiRateLimitRemaining: Int?,
        deployFetchFailures: Int? = nil
    ) {
        self.generatedAt = generatedAt
        self.account = account
        self.usageMetrics = usageMetrics
        self.sites = sites
        self.totalSites = totalSites
        self.totalDeploysInLookback = totalDeploysInLookback
        self.failedDeploysInLookback = failedDeploysInLookback
        self.degradedReason = degradedReason
        self.apiRateLimitRemaining = apiRateLimitRemaining
        self.deployFetchFailures = deployFetchFailures
    }

    public var highestRisk: RiskLevel {
        sites.map(\.riskLevel).max() ?? .low
    }

    /// Number of scanned sites with unavailable deploy data, defaulting to 0
    /// for snapshots persisted before the field existed.
    public var unavailableSiteCount: Int {
        deployFetchFailures ?? 0
    }
}
