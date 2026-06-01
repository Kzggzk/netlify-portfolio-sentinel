import Foundation

public enum RiskScorer {
    public static func accountRisk(metrics: [UsageMetric], settings: MonitorSettings) -> (RiskLevel, [String]) {
        var level: RiskLevel = .low
        var reasons: [String] = []

        for metric in metrics {
            guard let ratio = metric.ratio else { continue }
            if ratio >= settings.criticalUsageRatio {
                level = max(level, .critical)
                reasons.append("\(metric.label) is at \(Int(ratio * 100))% of included quota.")
            } else if ratio >= settings.warningUsageRatio {
                level = max(level, .high)
                reasons.append("\(metric.label) is at \(Int(ratio * 100))% of included quota.")
            }
        }

        return (level, reasons)
    }

    public static func digest(
        site: NetlifySite,
        deploys: [NetlifyDeploy],
        settings: MonitorSettings,
        currentDeployFootprintBytes: Int64?
    ) -> SiteDigest {
        let cutoff = Calendar.current.date(
            byAdding: .day,
            value: -settings.deployLookbackDays,
            to: Date()
        ) ?? Date.distantPast

        let recentDeploys = deploys.filter { deploy in
            guard let date = DateParser.parse(deploy.createdAt) else { return false }
            return date >= cutoff
        }

        let failedDeploys = recentDeploys.filter { deploy in
            guard let state = deploy.state?.lowercased() else { return false }
            return ["error", "failed", "rejected"].contains(state)
        }

        var level: RiskLevel = .low
        var reasons: [String] = []

        if failedDeploys.count > 0 {
            level = max(level, .high)
            reasons.append("\(failedDeploys.count) failed deploy(s) in the last \(settings.deployLookbackDays)d.")
        }

        if recentDeploys.count >= 25 {
            level = max(level, .high)
            reasons.append("\(recentDeploys.count) deploys in the last \(settings.deployLookbackDays)d.")
        } else if recentDeploys.count >= 10 {
            level = max(level, .watch)
            reasons.append("\(recentDeploys.count) deploys in the last \(settings.deployLookbackDays)d.")
        }

        if let state = deploys.first?.state?.lowercased(), !["ready", "current", "uploaded", "processed"].contains(state) {
            level = max(level, .watch)
            reasons.append("Latest deploy state is \(state).")
        }

        if let bytes = currentDeployFootprintBytes {
            if bytes >= 500_000_000 {
                level = max(level, .high)
                reasons.append("Current deploy footprint is \(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)).")
            } else if bytes >= 100_000_000 {
                level = max(level, .watch)
                reasons.append("Current deploy footprint is \(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)).")
            }
        }

        if reasons.isEmpty {
            reasons.append("No immediate deploy or footprint risk detected.")
        }

        return SiteDigest(
            site: site,
            deploys: deploys,
            deploysInLookback: recentDeploys.count,
            failedDeploysInLookback: failedDeploys.count,
            lastDeployAt: deploys.first?.createdAt ?? site.updatedAt,
            lastDeployState: deploys.first?.state,
            currentDeployFootprintBytes: currentDeployFootprintBytes,
            riskLevel: level,
            riskReasons: reasons
        )
    }
}
